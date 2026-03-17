import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../dashboard/data/datasources/stats_datasource.dart';
import '../../../locales/data/datasources/local_datasource.dart';
import '../models/cobro_model.dart';

class CobroDatasource {
  final FirebaseFirestore _firestore;
  final StatsDatasource _statsDs;
  final LocalDatasource _localDs;

  CobroDatasource(this._firestore, this._statsDs, this._localDs);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.cobros);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
  }

  /// Registra un cobro y genera un correlativo único por LOCAL y año.
  /// En modo offline (sin conexión), genera un correlativo leyendo y actualizando Hive.
  Future<String> crearCobroConCorrelativo({
    required String cobroId,
    required Map<String, dynamic> cobroData,
    required String localId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = cobroData['creadoPor'] as String?;
    if (userId == null) throw Exception('Falta ID de usuario para correlativo');

    // 1. Obtener datos del usuario (prefijo y contador local)
    // Estos deben haberse sincronizado al iniciar sesión o antes de salir.
    final String codigoCobrador = prefs.getString('prefijo_$userId') ?? 'C';
    final int anioActual = DateTime.now().year;
    
    // Llave de SharedPreferences para este usuario y año
    final String keyContador = 'correlativo_${userId}_$anioActual';
    int ultimoCorrelativo = prefs.getInt(keyContador) ?? 0;
    int nuevoCorrelativo = ultimoCorrelativo + 1;

    // 2. Generar Número de Boleta: ANIO-CODIGO-0001
    final numeroBoleta = '$anioActual-$codigoCobrador-${nuevoCorrelativo.toString().padLeft(4, "0")}';

    // 3. Guardar nuevo correlativo localmente de inmediato
    await prefs.setInt(keyContador, nuevoCorrelativo);

    // 4. Preparar datos del cobro
    final finalCobroData = Map<String, dynamic>.from(cobroData);
    finalCobroData['correlativo'] = nuevoCorrelativo;
    finalCobroData['anioCorrelativo'] = anioActual;
    finalCobroData['numeroBoleta'] = numeroBoleta;
    
    // Intentar determinar si estamos online para marcar esOffline
    final connectivityResult = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );
    // En las versiones más recientes checkConnectivity devuelve una lista
    final isOnline = connectivityResult.any((res) => res != ConnectivityResult.none);
    finalCobroData['esOffline'] = !isOnline;

    // 5. Preparar Lote de Escritura (Atomicidad)
    final batch = _firestore.batch();
    final docRef = _collection.doc(cobroId);
    
    // a. Registrar en Firestore el cobro
    batch.set(docRef, finalCobroData);

    // b. Actualizar estadísticas globales (En el mismo Batch)
    final municipalidadId = cobroData['municipalidadId'] as String?;
    if (municipalidadId != null) {
      final montoCobrado = (finalCobroData['monto'] as num?) ?? 0;
      final abonoDeuda = (finalCobroData['montoAbonadoDeuda'] as num?) ?? 0;
      final incrementoSaldo = (finalCobroData['nuevoSaldoFavor'] as num?) ?? 0;

      final mercadoId = cobroData['mercadoId'] as String?;
      if (mercadoId != null) {
        await _statsDs.actualizarAlCobrar(
          municipalidadId: municipalidadId,
          mercadoId: mercadoId,
          montoCobrado: montoCobrado,
          abonoDeuda: abonoDeuda,
          incrementoSaldo: incrementoSaldo,
          batch: batch,
        );
      }
    }

    // c. Actualizar el Local (Deuda y Saldo) en el mismo Batch
    final abonoDeuda = (finalCobroData['montoAbonadoDeuda'] as num?) ?? 0;
    final incrementoSaldo = (finalCobroData['nuevoSaldoFavor'] as num?) ?? 0;
    
    await _localDs.actualizarDeudaAcumulada(localId, -abonoDeuda, batch: batch);
    await _localDs.actualizarSaldoAFavor(localId, incrementoSaldo, batch: batch);

    // d. Actualizar el último correlativo del usuario (Cobrador) en el mismo Batch
    // Esto asegura que el correlativo se sincronice en background junto con el cobro en modo offline.
    final userRef = _firestore.collection(FirestoreCollections.usuarios).doc(userId);
    batch.set(userRef, {
      'ultimoCorrelativo': nuevoCorrelativo,
      'anioCorrelativo': anioActual,
    }, SetOptions(merge: true));

    // 6. Ejecutar el Lote Completo (TODO O NADA)
    await batch.commit();

    return numeroBoleta;
  }

  // REVERTIR CORRELATIVO (Inteligente)
  Future<void> retrocederCorrelativo({
    required String usuarioId,
    required int anio,
    required int correlativoABorrar,
  }) async {
    // Solo retrocedemos si la boleta borrada es *exactamente* la última generada por este cobrador.
    // Si borró una boleta vieja (ej: la #2 y ya va por la #5), no hacemos nada para evitar duplicar
    // las del medio.

    try {
      final connectivityResult = await Connectivity()
          .checkConnectivity()
          .timeout(
            const Duration(seconds: 1),
            onTimeout: () => [ConnectivityResult.none],
          );

      if (connectivityResult.any((res) => res == ConnectivityResult.none)) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.usuarios)
            .doc(usuarioId);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final actualAnio = (data['anioCorrelativo'] as num?)?.toInt() ?? anio;
          final actualCorrelativo =
              (data['ultimoCorrelativo'] as num?)?.toInt() ?? 0;

          if (actualAnio == anio && actualCorrelativo == correlativoABorrar) {
            transaction.update(userRef, {
              'ultimoCorrelativo': actualCorrelativo - 1,
            });
            // Offline sync inside online success
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(
              'correlativo_${usuarioId}_$anio',
              actualCorrelativo - 1,
            );
          }
        }
      });
    } catch (_) {
      // OFFLINE FALLBACK
      final prefs = await SharedPreferences.getInstance();
      final actualCorrelativo =
          prefs.getInt('correlativo_${usuarioId}_$anio') ?? 0;

      if (actualCorrelativo == correlativoABorrar) {
        await prefs.setInt(
          'correlativo_${usuarioId}_$anio',
          actualCorrelativo - 1,
        );

        // Dejar el documento listo para sync
        _firestore
            .collection(FirestoreCollections.usuarios)
            .doc(usuarioId)
            .update({
              'ultimoCorrelativo': actualCorrelativo - 1,
              'actualizadoEn': FieldValue.serverTimestamp(),
            })
            .catchError((_) {});
      }
    }
  }

  Future<List<CobroJson>> listarPorIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Firestore whereIn supports up to 30 elements.
    final List<List<String>> batches = [];
    for (var i = 0; i < ids.length; i += 30) {
      batches.add(ids.sublist(
        i,
        i + 30 > ids.length ? ids.length : i + 30,
      ));
    }

    // Ejecutar todas las peticiones en paralelo
    final snapshots = await Future.wait(
      batches.map((batchIds) => _collection
          .where(FieldPath.documentId, whereIn: batchIds)
          .get())
    );

    final List<CobroJson> results = [];
    for (final snapshot in snapshots) {
      results.addAll(
        snapshot.docs.map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id)),
      );
    }
    return results;
  }

  // READ
  Future<List<CobroJson>> listarPorLocal(String localId) async {
    final snapshot = await _collection
        .where('localId', isEqualTo: localId)
        .orderBy('fecha', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<CobroJson>> listarPorFecha(
    DateTime fecha, {
    String? municipalidadId,
    String? mercadoId,
    List<String>? rutaAsignada,
  }) async {
    final conectividad = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );

    final isOffline = conectividad.any((res) => res == ConnectivityResult.none);
    final source = isOffline ? Source.cache : Source.serverAndCache;

    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin));

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    // Si hay ruta asignada, priorizamos filtrar esos IDs específicos
    if (rutaAsignada != null && rutaAsignada.isNotEmpty) {
      final List<CobroJson> allResults = [];
      for (var i = 0; i < rutaAsignada.length; i += 30) {
        final batchIds = rutaAsignada.sublist(
          i,
          i + 30 > rutaAsignada.length ? rutaAsignada.length : i + 30,
        );
        var batchQuery = query.where('localId', whereIn: batchIds);
        final snapshot = await batchQuery.get(GetOptions(source: source));
        allResults.addAll(
          snapshot.docs.map(
            (doc) => CobroJson.fromJson(doc.data(), docId: doc.id),
          ),
        );
      }
      return allResults;
    }

    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }

    try {
      final snapshot = await query.get(GetOptions(source: source));
      return snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      if (e is FirebaseException && e.code == 'unavailable') {
        final snapshot = await query.get(
          const GetOptions(source: Source.cache),
        );
        return snapshot.docs
            .map((d) => CobroJson.fromJson(d.data(), docId: d.id))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<CobroJson>> listarRecientes({
    int limite = 20,
    String? municipalidadId,
  }) async {
    var query = _collection.orderBy('fecha', descending: true).limit(limite);

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<CobroJson>> listarPorCobrador(String cobradorId, {int limite = 50}) async {
    // Nota: Puede requerir un índice compuesto (creadoPor ASC, fecha DESC) en Firestore.
    try {
      final snapshot = await _collection
          .where('creadoPor', isEqualTo: cobradorId)
          .orderBy('fecha', descending: true)
          .limit(limite)
          .get();

      return snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      // Fallback a buscar todos los del cobrador si el índice no existe aún,
      // ordenándolos en memoria (menos eficiente para grandes vols, pero funcional)
      final snapshot = await _collection
          .where('creadoPor', isEqualTo: cobradorId)
          .get();
      
      final lista = snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList();
      lista.sort((a, b) {
        final dateA = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      return lista.take(limite).toList();
    }
  }

  Stream<List<CobroJson>> streamPorCobrador(
    String cobradorId, {
    int limite = 200,
    DateTime? inicio,
    DateTime? fin,
  }) {
    var query = _collection.where('creadoPor', isEqualTo: cobradorId);

    if (inicio != null) {
      query = query.where(
        'fecha',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(inicio.year, inicio.month, inicio.day),
        ),
      );
    }
    if (fin != null) {
      query = query.where(
        'fecha',
        isLessThanOrEqualTo: Timestamp.fromDate(
          DateTime(fin.year, fin.month, fin.day, 23, 59, 59),
        ),
      );
    }

    return query
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  Stream<List<CobroJson>> streamPorLocal(String localId, {int limite = 20}) {
    return _collection
        .where('localId', isEqualTo: localId)
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  Stream<List<CobroJson>> streamPorFecha(
    DateTime fecha, {
    String? municipalidadId,
    String? mercadoId,
    String? cobradorId, // NUEVO parámetro para aislar datos
    int limite = 150, // Límite de seguridad para evitar miles de lecturas si hay picos
  }) {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .orderBy('fecha', descending: true);

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }
    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }
    if (cobradorId != null) {
      query = query.where('creadoPor', isEqualTo: cobradorId);
    }

    // CORRECCIÓN CRÍICA: Limitar el stream para no devorar la facturación
    query = query.limit(limite);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList(),
    );
  }

  /// Obtiene cobros en un rango de fechas de forma atómica (Sin stream) para ahorrar lecturas.
  Future<List<CobroJson>> listarPorRangoFechas(
    DateTime inicio,
    DateTime fin, {
    String? municipalidadId,
    String? mercadoId,
    String? cobradorId, // NUEVO parámetro para aislar "Resumen Operativo"
    int? limite = 100, // Limitar a 100 por seguridad en dashboard
  }) async {
    final fechaInicio = DateTime(inicio.year, inicio.month, inicio.day);
    final fechaFin = DateTime(fin.year, fin.month, fin.day).add(const Duration(days: 1));

    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fechaFin))
        .orderBy('fecha', descending: true);

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }
    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }
    if (cobradorId != null) {
      query = query.where('creadoPor', isEqualTo: cobradorId);
    }
    if (limite != null) {
      query = query.limit(limite);
    }

    final result = await query.get();
    return result.docs
        .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  @Deprecated('Usar listarPorRangoFechas para ahorrar costos en datos históricos')
  Stream<List<CobroJson>> streamPorRangoFechas(
    DateTime inicio,
    DateTime fin, {
    String? municipalidadId,
    String? mercadoId,
    String? cobradorId,
  }) {
    // ... (Se mantiene por compatibilidad si es necesario, pero se marcará como depre)
    final fechaInicio = DateTime(inicio.year, inicio.month, inicio.day);
    final fechaFin = DateTime(fin.year, fin.month, fin.day).add(const Duration(days: 1));

    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fechaFin))
        .orderBy('fecha', descending: true);

    if (municipalidadId != null) query = query.where('municipalidadId', isEqualTo: municipalidadId);
    if (mercadoId != null) query = query.where('mercadoId', isEqualTo: mercadoId);
    if (cobradorId != null) query = query.where('creadoPor', isEqualTo: cobradorId);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList(),
    );
  }


  Stream<List<CobroJson>> streamRecientes({
    int limite = 20,
    String? municipalidadId,
    String? mercadoId,
  }) {
    Query<Map<String, dynamic>> query = _collection.orderBy(
      'fecha',
      descending: true,
    );

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }
    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }
    
    // CORRECCIÓN CRÍTICA: Aplicar el límite a Firestore ANTES de descargar.
    query = query.limit(limite);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList(),
    );
  }

  /// Obtiene cobros de múltiples locales en un rango de fechas.
  /// Útil para optimizar lecturas masivas.
  Future<List<CobroJson>> listarPorLocalesYRango({
    required List<String> localIds,
    required DateTime inicio,
    required DateTime fin,
  }) async {
    if (localIds.isEmpty) return [];

    final List<CobroJson> results = [];
    final fechaInicio = DateTime(inicio.year, inicio.month, inicio.day);
    final fechaFin = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);

    // Lotes de 30 (límite de Firestore para whereIn)
    for (var i = 0; i < localIds.length; i += 30) {
      final batchIds = localIds.sublist(
        i,
        i + 30 > localIds.length ? localIds.length : i + 30,
      );

      final query = _collection
          .where('localId', whereIn: batchIds)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(fechaFin));

      final snapshot = await query.get();
      results.addAll(
        snapshot.docs.map(
          (doc) => CobroJson.fromJson(doc.data(), docId: doc.id),
        ),
      );
    }

    return results;
  }

  /// Obtiene el monto total pagado por un local en una fecha específica.
  Future<num> obtenerMontoPagadoEnFecha(String localId, DateTime fecha) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    final snapshot = await _collection
        .where('localId', isEqualTo: localId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snapshot.docs.fold<num>(
      0,
      (acc, doc) => acc + (doc.data()['monto'] ?? 0),
    );
  }

  /// Verifica si ya existe un cobro para un local en una fecha específica.
  Future<bool> existeCobroPorLocalYFecha(String localId, DateTime fecha) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    final snapshot = await _collection
        .where('localId', isEqualTo: localId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // UPDATE
  Future<void> actualizar(String docId, Map<String, dynamic> data) async {
    final connectivityResult = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );

    final isOffline = connectivityResult.any((res) => res == ConnectivityResult.none);
    final future = _collection.doc(docId).update(data);

    if (!isOffline) {
      await future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );
    }
  }

  // DELETE
  Future<void> eliminar(String docId, {String? municipalidadId}) async {
    final docSnap = await _collection.doc(docId).get();
    
    if (docSnap.exists) {
      final data = docSnap.data()!;
      final targetMuniId = municipalidadId ?? data['municipalidadId'] as String?;
      final montoCobrado = (data['monto'] as num?) ?? 0;
      final abonoDeuda = (data['montoAbonadoDeuda'] as num?) ?? 0;
      final incrementoSaldo = (data['nuevoSaldoFavor'] as num?) ?? 0;
      
      final fechaRaw = data['fecha'];
      DateTime fechaCobro = DateTime.now();
      if (fechaRaw is Timestamp) fechaCobro = fechaRaw.toDate();

      final estado = data['estado'] as String?;
      final saldoPendiente = (data['saldoPendiente'] as num?) ?? 0;

      final batch = _firestore.batch();

      if (targetMuniId != null) {
        if (estado == 'pendiente') {
          final targetMercadoId = data['mercadoId'] as String?;
          if (targetMercadoId != null) {
            await _statsDs.revertirPendiente(
              municipalidadId: targetMuniId,
              mercadoId: targetMercadoId,
              saldoPendiente: saldoPendiente,
              fechaCobroOriginal: fechaCobro,
              batch: batch,
            );
          }
        } else if (estado == 'cobrado_saldo') {
          final targetMercadoId = data['mercadoId'] as String?;
          if (targetMercadoId != null) {
            await _statsDs.revertirCobroSaldo(
              municipalidadId: targetMuniId,
              mercadoId: targetMercadoId,
              montoConsumido: montoCobrado,
              fechaCobroOriginal: fechaCobro,
              batch: batch,
            );
          }
        } else {
          final targetMercadoId = data['mercadoId'] as String?;
          if (targetMercadoId != null) {
            await _statsDs.revertirCobro(
              municipalidadId: targetMuniId,
              mercadoId: targetMercadoId,
              montoCobrado: montoCobrado,
              abonoDeuda: abonoDeuda,
              incrementoSaldo: incrementoSaldo,
              fechaCobroOriginal: fechaCobro,
              batch: batch,
            );
          }
        }
      }

      // 2. Revertir impacto en el Local (Deuda y Saldo) en el mismo Batch
      final localId = data['localId'] as String?;
      if (localId != null) {
        await _localDs.revertirPago(
          localId: localId,
          montoARecomponerDeuda: abonoDeuda,
          montoARestarSaldo: incrementoSaldo,
          batch: batch,
        );
      }

      // Eliminar el documento en el mismo Batch
      batch.delete(_collection.doc(docId));
      await batch.commit();
    }
  }

  /// Busca los cobros pendientes más antiguos (FIFO) y los marca como cobrados.
  /// Retorna los IDs de los cobros saldados, sus fechas, y el monto que corresponde a Mora.
  /// - [fechaReferenciaMora]: Deudas del mes anterior a esta fecha se clasifican como "Mora".
  ///   Si es null, se usa el primer día del mes actual como referencia.
  Future<({List<String> ids, List<DateTime> fechas, num montoMora})> saldarDeudaHistoria(
    String localId,
    num montoASaldar, {
    DateTime? fechaReferenciaMora,
  }) async {
    if (montoASaldar <= 0) return (ids: <String>[], fechas: <DateTime>[], montoMora: 0);

    // Inicio del mes de referencia (por defecto: mes actual)
    final ref = fechaReferenciaMora ?? DateTime.now();
    final inicioMesReferencia = DateTime(ref.year, ref.month, 1);

    // Timeout estricto para no colgar la UI
    final connectivityResult = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );

    final isOffline = connectivityResult.any((res) => res == ConnectivityResult.none);
    
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _collection
          .where('localId', isEqualTo: localId)
          .where('estado', whereIn: ['pendiente', 'abono_parcial'])
          .orderBy('fecha', descending: false)
          .get(GetOptions(source: isOffline ? Source.cache : Source.serverAndCache))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Fallback a caché si expira o falla la red
      snapshot = await _collection
          .where('localId', isEqualTo: localId)
          .where('estado', whereIn: ['pendiente', 'abono_parcial'])
          .orderBy('fecha', descending: false)
          .get(const GetOptions(source: Source.cache));
    }

    WriteBatch batch = _firestore.batch();
    num restante = montoASaldar;
    num montoMoraAcumulado = 0;
    final List<String> idsSaldados = [];
    final List<DateTime> fechasSaldadas = [];

    for (var doc in snapshot.docs) {
      if (restante <= 0) break;

      final data = doc.data();
      final saldoPendiente = (data['saldoPendiente'] ?? data['cuotaDiaria'] ?? 0) as num;

      // Capturar la fecha del cobro histórico para el recibo
      final fechaRaw = data['fecha'];
      DateTime? fechaDoc;
      if (fechaRaw is Timestamp) {
        fechaDoc = fechaRaw.toDate();
      }

      // Determinar si esta deuda es "Mora" (su fecha es anterior al mes de referencia)
      final esMora = fechaDoc != null && fechaDoc.isBefore(inicioMesReferencia);

      if (restante >= saldoPendiente) {
        // Se salda completamente este día
        batch.update(doc.reference, {
          'estado': 'cobrado',
          'saldoPendiente': 0,
          'observaciones':
              '${data['observaciones'] ?? ''}\nSaldado por abono general.'
                  .trim(),
        });
        if (esMora) montoMoraAcumulado += saldoPendiente;
        restante -= saldoPendiente;
        // Solo agregar a fechasSaldadas si el día fue cubierto al 100%
        if (fechaDoc != null) fechasSaldadas.add(fechaDoc);
      } else {
        // Se abona parcialmente — el día NO está cubierto, no agregar fecha
        batch.update(doc.reference, {
          'estado': 'abono_parcial',
          'saldoPendiente': saldoPendiente - restante,
        });
        if (esMora) montoMoraAcumulado += restante;
        restante = 0;
      }

      idsSaldados.add(doc.id);
    }

    final future = batch.commit();

    if (!isOffline) {
      await future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );
    }

    return (ids: idsSaldados, fechas: fechasSaldadas, montoMora: montoMoraAcumulado);
  }

  /// Revierte los cobros históricos que fueron saldados por un cobro que se está eliminando.
  /// Restaura cada registro a su estado original ('pendiente') y su saldo a la cuota diaria.
  Future<void> revertirDeudasSaldadas(List<String> idsDeudas) async {
    if (idsDeudas.isEmpty) return;

    WriteBatch batch = _firestore.batch();

    for (final id in idsDeudas) {
      final docRef = _collection.doc(id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) continue;

      final data = docSnap.data()!;
      final cuotaDiaria = data['cuotaDiaria'] ?? 0;

      // Revertir al estado pendiente con el saldo original (cuota diaria)
      batch.update(docRef, {
        'estado': 'pendiente',
        'saldoPendiente': cuotaDiaria,
        'observaciones': (data['observaciones'] as String? ?? '')
            .replaceAll('\nSaldado por abono general.', '')
            .trim(),
      });
    }

    await batch.commit().catchError((_) {});
  }

  /// Migración temporal: Agrega municipalidadId a todos los cobros que no lo tienen.
  Future<int> migrarCobrosFaltantes(String municipalidadId) async {
    // Traemos todos para evitar fallos por falta de índices en queries con nulos
    final snapshot = await _collection.get();

    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;
    int actuallyMigrated = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Si el campo no existe o es nulo
      if (data['municipalidadId'] == null) {
        batch.update(doc.reference, {'municipalidadId': municipalidadId});
        actuallyMigrated++;
        count++;

        // Limite de batch de Firestore es 500
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count % 500 != 0 && actuallyMigrated > 0) {
      await batch.commit();
    }

    return actuallyMigrated;
  }

  /// Migración: Busca cobros sin municipalidadId, cruza con la de su Local y se las inyecta.
  Future<int> parcharCobrosHuerfanos() async {
    final cobrosSnapshot = await _collection.get();
    if (cobrosSnapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;
    int patched = 0;

    for (var doc in cobrosSnapshot.docs) {
      final data = doc.data();
      if (data['municipalidadId'] == null && data['localId'] != null) {
        // Obtenemos el local vinculado a este cobro defectuoso
        final localDoc = await _firestore
            .collection('locales')
            .doc(data['localId'])
            .get();
        if (localDoc.exists) {
          final localData = localDoc.data();
          if (localData != null && localData['municipalidadId'] != null) {
            batch.update(doc.reference, {
              'municipalidadId': localData['municipalidadId'],
            });
            patched++;
            count++;

            // Commit in batches of 500
            if (count % 500 == 0) {
              await batch.commit();
              batch = _firestore.batch();
            }
          }
        }
      }
    }

    if (count % 500 != 0 && patched > 0) {
      await batch.commit();
    }

    return patched;
  }

  /// Migración: Deduzca pagoACuota de registros antiguos que no lo tienen.
  Future<int> parcharPagoACuota() async {
    final cobrosSnapshot = await _collection.get();
    if (cobrosSnapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;
    int patched = 0;

    for (var doc in cobrosSnapshot.docs) {
      final data = doc.data();
      // Solo si no tiene el campo o es nulo
      if (data['pagoACuota'] == null) {
        final estado = data['estado'] as String?;
        final monto = (data['monto'] as num?) ?? 0;
        final cuotaDiaria = (data['cuotaDiaria'] as num?) ?? 0;

        num deducido = 0;

        if (estado == 'cobrado' ||
            estado == 'cobrado_saldo' ||
            estado == 'adelantado') {
          // Cubrió la cuota (o parte de ella si el monto es menor por error de carga previa)
          deducido = (monto >= cuotaDiaria && cuotaDiaria > 0)
              ? cuotaDiaria
              : monto;
        } else if (estado == 'abono_parcial') {
          // El monto es lo que se abonó a la cuota o deuda
          deducido = monto;
        } else if (estado == 'pendiente') {
          deducido = 0;
        }

        batch.update(doc.reference, {'pagoACuota': deducido});
        patched++;
        count++;

        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count % 500 != 0 && patched > 0) {
      await batch.commit();
    }

    return patched;
  }

  /// Inicializa todas las claves y correlativos del sistema (Mercados, Usuarios, Locales, Cobros)
  Future<int> inicializarCorrelativosSistema() async {
    int count = 0;

    // 1. Limpiar Mercados (Eliminar campos obsoletos)
    count += await eliminarCamposObsoletosMercados();

    // 2. Limpiar Usuarios (Eliminar campos obsoletos)
    count += await limpiarCorrelativosUsuario();

    // 3. Parchar Cobros (esOffline)
    count += await parcharEsOfflineEnCobros();

    // 4. Limpiar Locales (Eliminar campos obsoletos de locales)
    count += await _limpiarLocalesObsoletos();

    return count;
  }

  Future<int> _limpiarLocalesObsoletos() async {
    final localesDocs = await _firestore
        .collection(FirestoreCollections.locales)
        .get();

    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var l in localesDocs.docs) {
      final data = l.data();
      if (data.containsKey('ultimoCorrelativo') ||
          data.containsKey('anioCorrelativo')) {
        batch.update(l.reference, {
          'ultimoCorrelativo': FieldValue.delete(),
          'anioCorrelativo': FieldValue.delete(),
        });
        count++;

        if (count % 450 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count % 450 != 0 && count > 0) {
      await batch.commit();
    }
    return count;
  }

  /// Limpieza: Elimina campos de correlativos obsoletos de la colección de Mercados
  Future<int> eliminarCamposObsoletosMercados() async {
    final mercados = await _firestore
        .collection(FirestoreCollections.mercados)
        .get();

    if (mercados.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var m in mercados.docs) {
      batch.update(m.reference, {
        'ultimoCorrelativo': FieldValue.delete(),
        'anioCorrelativo': FieldValue.delete(),
        'claveOnline': FieldValue.delete(),
        'claveOffline': FieldValue.delete(),
        'ultimoCorrelativoOnline': FieldValue.delete(),
        'ultimoCorrelativoOffline': FieldValue.delete(),
      });
      count++;

      if (count % 450 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }

    if (count % 450 != 0 && count > 0) {
      await batch.commit();
    }
    return count;
  }

  /// Limpieza: Elimina campos de correlativos obsoletos de la colección de Usuarios
  Future<int> limpiarCorrelativosUsuario() async {
    final usuarios = await _firestore
        .collection(FirestoreCollections.usuarios)
        .where('rol', isEqualTo: 'cobrador')
        .get();

    if (usuarios.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var u in usuarios.docs) {
      batch.update(u.reference, {
        'ultimoCorrelativo': FieldValue.delete(),
        'anioCorrelativo': FieldValue.delete(),
        'clave': FieldValue.delete(),
      });
      count++;

      if (count % 450 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }

    if (count % 450 != 0 && count > 0) {
      await batch.commit();
    }
    return count;
  }

  /// Parchado: Asegura que todos los cobros tengan el flag 'esOffline'
  Future<int> parcharEsOfflineEnCobros() async {
    final cobros = await _collection.get();
    if (cobros.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;
    int patched = 0;

    for (var doc in cobros.docs) {
      if (doc.data()['esOffline'] == null) {
        batch.update(doc.reference, {'esOffline': false});
        patched++;
        count++;

        if (count % 450 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count % 450 != 0 && patched > 0) {
      await batch.commit();
    }
    return patched;
  }

  /// Soft-Reset del sistema:
  /// 1. Limpia deuda/saldo en locales y recalcula contadores (~590 reads + writes)
  /// 2. Escribe stats con contadores reales + fechaInicioOperaciones = HOY (1 escritura)
  /// 3. NO toca cobros (ahorro principal: evita leer/borrar 15k+ documentos)
  Future<void> softResetSistema(String municipalidadId) async {
    // 1. Leer locales de esta municipalidad (los necesitamos para limpiar Y para contadores)
    final locales = await _firestore
        .collection(FirestoreCollections.locales)
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    // 2. Calcular contadores REALES desde los locales leídos (0 lecturas extra)
    num totalCuotaDiaria = 0;
    final Set<String> mercadosUnicos = {};
    for (var doc in locales.docs) {
      final data = doc.data();
      final cuota = (data['cuotaDiaria'] as num?) ?? 0;
      final activo = data['activo'] as bool? ?? true;
      if (activo) {
        totalCuotaDiaria += cuota;
      }
      final mercadoId = data['mercadoId'] as String?;
      if (mercadoId != null) mercadosUnicos.add(mercadoId);
    }

    // 3. Escribir stats con contadores reales + fecha de inicio
    await _firestore.collection('stats').doc(municipalidadId).set({
      'totalCobrado': 0,
      'totalDeuda': 0,
      'totalSaldoAFavor': 0,
      'totalCuotaDiaria': totalCuotaDiaria,
      'cantidadLocales': locales.docs.length,
      'cantidadMercados': mercadosUnicos.length,
      'diario': {},
      'fechaInicioOperaciones': Timestamp.now(),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. Limpiar deuda/saldo en locales
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var doc in locales.docs) {
      batch.update(doc.reference, {
        'deudaAcumulada': 0,
        'saldoAFavor': 0,
        'creadoEn': Timestamp.now(),
      });
      count++;
      if (count % 450 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }
    if (count % 450 != 0 && count > 0) {
      await batch.commit();
    }

    // 5. Eliminar TODOS los cobros de esta municipalidad físicamente
    // Se usa un bucle para manejar grandes volúmenes sin exceder límites de memoria o batch
    bool tieneCobros = true;
    while (tieneCobros) {
      final snapshot = await _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .limit(500)
          .get();
      
      if (snapshot.docs.isEmpty) {
        tieneCobros = false;
        break;
      }

      final deleteBatch = _firestore.batch();
      for (var doc in snapshot.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      
      // Si el snapshot trajo menos del límite, es el último lote
      if (snapshot.docs.length < 500) {
        tieneCobros = false;
      }
    }

    // 5.1. Eliminar TODOS los cortes de esta municipalidad
    bool tieneCortes = true;
    while (tieneCortes) {
      final snapshot = await _firestore.collection('cortes')
          .where('municipalidadId', isEqualTo: municipalidadId)
          .limit(500)
          .get();
      
      if (snapshot.docs.isEmpty) {
        tieneCortes = false;
        break;
      }

      final deleteBatch = _firestore.batch();
      for (var doc in snapshot.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      
      if (snapshot.docs.length < 500) {
        tieneCortes = false;
      }
    }

    // 5.2. Eliminar TODAS las gestiones de esta municipalidad
    bool tieneGestiones = true;
    while (tieneGestiones) {
      final snapshot = await _firestore.collection('gestiones')
          .where('municipalidadId', isEqualTo: municipalidadId)
          .limit(500)
          .get();
      
      if (snapshot.docs.isEmpty) {
        tieneGestiones = false;
        break;
      }

      final deleteBatch = _firestore.batch();
      for (var doc in snapshot.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      
      if (snapshot.docs.length < 500) {
        tieneGestiones = false;
      }
    }

    // 6. Limpiar caché local — costo: 0 lecturas Firestore
    await limpiarCacheLocal();
  }

  /// Limpia la caché local de cobros (Hive + SharedPreferences).
  /// Llamar después de un reset del sistema o para depuración.
  Future<void> limpiarCacheLocal() async {
    try {
      // 1. Limpiar Hive cobrosBox
      final box = Hive.isBoxOpen('cobrosBox')
          ? Hive.box<dynamic>('cobrosBox')
          : await Hive.openBox<dynamic>('cobrosBox');
      await box.clear();
    } catch (_) {}

    try {
      // 2. Limpiar claves de correlativos offline en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs.getKeys().where(
        (k) =>
            k.startsWith('offlineC_') ||
            k.startsWith('onlineC_') ||
            k.startsWith('anioC_') ||
            k.startsWith('claveON_') ||
            k.startsWith('claveOFF_') ||
            k.startsWith('prefijo_') ||
            k.startsWith('correlativo_') ||
            k.startsWith('last_debt_scan_'),
      );
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
