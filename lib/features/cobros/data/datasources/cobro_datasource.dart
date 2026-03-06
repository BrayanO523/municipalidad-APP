import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../models/cobro_model.dart';

class CobroDatasource {
  final FirebaseFirestore _firestore;

  CobroDatasource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.cobros);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
  }

  /// Registra un cobro y genera un correlativo único por mercado y año.
  Future<int> crearCobroConCorrelativo({
    required String cobroId,
    required Map<String, dynamic> cobroData,
    required String mercadoId,
  }) async {
    return await _firestore.runTransaction<int>((transaction) async {
      final mercadoRef = _firestore
          .collection(FirestoreCollections.mercados)
          .doc(mercadoId);
      final mercadoDoc = await transaction.get(mercadoRef);

      if (!mercadoDoc.exists) {
        throw Exception('El mercado no existe');
      }

      final data = mercadoDoc.data()!;
      final anioActual = DateTime.now().year;
      final anioGuardado = data['anioCorrelativo'] as int?;
      final ultimoCorrelativo = data['ultimoCorrelativo'] as int? ?? 0;

      int nuevoCorrelativo;
      if (anioGuardado != anioActual) {
        // Reinicio anual
        nuevoCorrelativo = 1;
      } else {
        nuevoCorrelativo = ultimoCorrelativo + 1;
      }

      // Actualizar mercado
      transaction.update(mercadoRef, {
        'ultimoCorrelativo': nuevoCorrelativo,
        'anioCorrelativo': anioActual,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      // Crear cobro con el correlativo asignado
      final finalCobroData = Map<String, dynamic>.from(cobroData);
      finalCobroData['correlativo'] = nuevoCorrelativo;
      finalCobroData['anioCorrelativo'] = anioActual;

      transaction.set(_collection.doc(cobroId), finalCobroData);

      return nuevoCorrelativo;
    });
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
  }) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin));

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
        .toList();
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

  Stream<List<CobroJson>> streamPorLocal(String localId) {
    return _collection
        .where('localId', isEqualTo: localId)
        .orderBy('fecha', descending: true)
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
  }) {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin));

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList(),
    );
  }

  Stream<List<CobroJson>> streamPorRangoFechas(
    DateTime inicio,
    DateTime fin, {
    String? municipalidadId,
  }) {
    // Normalizar inicio a 00:00:00
    final fechaInicio = DateTime(inicio.year, inicio.month, inicio.day);
    // Normalizar fin a 23:59:59 del día de fin
    final fechaFin = DateTime(
      fin.year,
      fin.month,
      fin.day,
    ).add(const Duration(days: 1));

    var query = _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fechaFin))
        .orderBy('fecha', descending: true);

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList(),
    );
  }

  Stream<List<CobroJson>> streamRecientes({
    int limite = 20,
    String? municipalidadId,
  }) {
    var query = _collection.orderBy('fecha', descending: true).limit(limite);

    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
          .toList(),
    );
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
    await _collection.doc(docId).update(data);
  }

  // DELETE
  Future<void> eliminar(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Busca los cobros pendientes más antiguos y los marca como cobrados
  /// basándose en un monto pagado a la deuda.
  Future<void> saldarDeudaHistoria(String localId, num montoASaldar) async {
    if (montoASaldar <= 0) return;

    final snapshot = await _collection
        .where('localId', isEqualTo: localId)
        .where('estado', whereIn: ['pendiente', 'abono_parcial'])
        .orderBy('fecha', descending: false) // Los más antiguos primero
        .get();

    WriteBatch batch = _firestore.batch();
    num restante = montoASaldar;

    for (var doc in snapshot.docs) {
      if (restante <= 0) break;

      final data = doc.data();
      final saldoPendiente = data['saldoPendiente'] ?? data['cuotaDiaria'] ?? 0;

      if (restante >= saldoPendiente) {
        // Se salda completamente este día
        batch.update(doc.reference, {
          'estado': 'cobrado',
          'monto': (data['monto'] ?? 0) + saldoPendiente,
          'saldoPendiente': 0,
          'observaciones':
              '${data['observaciones'] ?? ''}\nSaldado por abono general.'
                  .trim(),
        });
        restante -= saldoPendiente;
      } else {
        // Se abona parcialmente
        batch.update(doc.reference, {
          'estado': 'abono_parcial',
          'monto': (data['monto'] ?? 0) + restante,
          'saldoPendiente': saldoPendiente - restante,
        });
        restante = 0;
      }
    }

    await batch.commit();
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
}
