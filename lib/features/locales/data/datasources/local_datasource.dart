import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../dashboard/data/datasources/stats_datasource.dart';
import '../models/local_model.dart';

class LocalDatasource {
  final FirebaseFirestore _firestore;
  final StatsDatasource _statsDs;

  LocalDatasource(this._firestore, this._statsDs);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.locales);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
    
    // Actualizar estadísticas (Suma atómica)
    final municipalidadId = data['municipalidadId'] as String?;
    if (municipalidadId != null) {
      final deudaInicial = (data['deudaAcumulada'] as num?) ?? 0;
      final cuotaDiaria = (data['cuotaDiaria'] as num?) ?? 0;
      _statsDs.actualizarConteo(
        municipalidadId: municipalidadId,
        deltaLocales: 1,
        deltaDeuda: deudaInicial,
        deltaCuotaDiaria: cuotaDiaria,
      ).catchError((e) => debugPrint('Error actualizando stats local: $e'));
    }
  }

  // READ
  Future<List<LocalJson>> listarTodos() async {
    final connectivityResult = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );

    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    final source = isOffline ? Source.cache : Source.serverAndCache;

    try {
      final snapshot = await _collection
          .orderBy('nombreSocial')
          .get(GetOptions(source: source));
      return snapshot.docs
          .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      if (e is FirebaseException && e.code == 'unavailable') {
        // Fallback extra extremo
        final snapshot = await _collection
            .orderBy('nombreSocial')
            .get(const GetOptions(source: Source.cache));
        return snapshot.docs
            .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<LocalJson>> listarParaCobrador({
    required String municipalidadId,
    String? mercadoId,
    List<String>? rutaAsignada,
  }) async {
    // Si no hay mercado ni ruta, no tiene nada asignado. Retornamos vacío.
    if ((mercadoId == null || mercadoId.isEmpty) &&
        (rutaAsignada == null || rutaAsignada.isEmpty)) {
      return [];
    }

    final connectivityResult = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );

    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    final source = isOffline ? Source.cache : Source.serverAndCache;

    // 1. Prioridad: Ruta Asignada (locales específicos)
    if (rutaAsignada != null && rutaAsignada.isNotEmpty) {
      final List<LocalJson> allResults = [];
      // Firestore tiene un límite de 30 elementos para 'whereIn'.
      // Procesamos en lotes de 30.
      for (var i = 0; i < rutaAsignada.length; i += 30) {
        final batchIds = rutaAsignada.sublist(
          i,
          i + 30 > rutaAsignada.length ? rutaAsignada.length : i + 30,
        );

        final batchQuery = _collection
            .where('municipalidadId', isEqualTo: municipalidadId)
            .where(FieldPath.documentId, whereIn: batchIds);

        final snapshot = await batchQuery.get(GetOptions(source: source));
        allResults.addAll(
          snapshot.docs.map(
            (doc) => LocalJson.fromJson(doc.data(), docId: doc.id),
          ),
        );
      }
      allResults.sort(
        (a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''),
      );
      return allResults;
    }

    // 2. Segunda Prioridad: Mercado completo
    if (mercadoId != null && mercadoId.isNotEmpty) {
      final query = _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .where('mercadoId', isEqualTo: mercadoId);

      final snapshot = await query.get(GetOptions(source: source));
      final list = snapshot.docs
          .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
          .toList();
      list.sort(
        (a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''),
      );
      return list;
    }

    // Si llegó aquí (aunque la guarda de arriba lo debería evitar), retornamos vacío.
    return [];
  }

  Stream<List<LocalJson>> streamTodos() {
    return _collection
        .orderBy('nombreSocial')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  Stream<List<LocalJson>> streamPorMunicipalidad(String municipalidadId) {
    return _collection
        .where('municipalidadId', isEqualTo: municipalidadId)
        .orderBy('nombreSocial')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  Stream<List<LocalJson>> streamPorMercado(String mercadoId) {
    return _collection
        .where('mercadoId', isEqualTo: mercadoId)
        .orderBy('nombreSocial')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  Stream<LocalJson?> streamPorId(String docId) {
    return _collection.doc(docId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LocalJson.fromJson(doc.data()!, docId: doc.id);
    });
  }

  Future<List<LocalJson>> listarPorMercado(String mercadoId) async {
    final snapshot = await _collection
        .where('mercadoId', isEqualTo: mercadoId)
        .orderBy('nombreSocial')
        .get();
    return snapshot.docs
        .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  /// Página de locales con paginación por cursor, filtro por mercado y búsqueda.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> listarPaginaPorMercado({
    required String mercadoId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 20,
    String filtroDeuda = 'todos',
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lower = searchQuery.toLowerCase();
      // Firestore no permite '<=' y '>=' en diferentes campos a la vez.
      // Hacemos 2 queries en paralelo y unimos resultados en memoria.
      final queryNombre = _collection
          .where('mercadoId', isEqualTo: mercadoId)
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(limit);

      // Eliminamos el filtro de mercadoId en Firebase para evitar requerir 
      // un nuevo índice compuesto en la nube. Filtraremos en memoria.
      final queryCodigo = _collection
          .where('codigoCatastralLower', isGreaterThanOrEqualTo: lower)
          .where('codigoCatastralLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(limit * 3); // Pedimos un poco más por si hay colisiones en otros mercados

      final results = await Future.wait([queryNombre.get(), queryCodigo.get()]);
      
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged = {};
      
      // Agregamos los resultados por nombre
      for (var doc in results[0].docs) {
        merged[doc.id] = doc;
      }
      
      // Agregamos los resultados por código (filtrando por mercadoId en memoria)
      for (var doc in results[1].docs) {
        if (doc.data()['mercadoId'] == mercadoId) {
          merged[doc.id] = doc;
        }
      }
      final list = merged.values.toList();
      list.sort((a, b) {
        final nameA = (a.data()['nombreSocialLower'] as String?) ?? '';
        final nameB = (b.data()['nombreSocialLower'] as String?) ?? '';
        return nameA.compareTo(nameB);
      });
      return list.take(limit).toList();
    }

    Query<Map<String, dynamic>> query = _collection.where('mercadoId', isEqualTo: mercadoId);
    
    if (filtroDeuda == 'deudores') {
      query = query.where('deudaAcumulada', isGreaterThan: 0).orderBy('deudaAcumulada', descending: true);
    } else if (filtroDeuda == 'saldos') {
      query = query.where('saldoAFavor', isGreaterThan: 0).orderBy('saldoAFavor', descending: true);
    } else {
      query = query.orderBy('nombreSocial');
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.limit(limit).get();
    return snap.docs;
  }

  /// Página de locales por municipalidad con paginación.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> listarPaginaPorMunicipalidad({
    required String municipalidadId,
    String? mercadoId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 20,
    String filtroDeuda = 'todos',
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lower = searchQuery.toLowerCase();
      Query<Map<String, dynamic>> baseQuery = _collection
          .where('municipalidadId', isEqualTo: municipalidadId);
      
      if (mercadoId != null) {
        baseQuery = baseQuery.where('mercadoId', isEqualTo: mercadoId);
      }

      final queryNombre = baseQuery
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(limit);

      // Eliminamos los filtros de igualdad para evitar nuevos índices compuestos
      final queryCodigo = _collection
          .where('codigoCatastralLower', isGreaterThanOrEqualTo: lower)
          .where('codigoCatastralLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(limit * 3);

      final results = await Future.wait([queryNombre.get(), queryCodigo.get()]);
      
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged = {};
      
      for (var doc in results[0].docs) {
        merged[doc.id] = doc;
      }
      
      for (var doc in results[1].docs) {
        final data = doc.data();
        bool match = data['municipalidadId'] == municipalidadId;
        if (mercadoId != null && data['mercadoId'] != mercadoId) {
          match = false;
        }
        if (match) merged[doc.id] = doc;
      }
      final list = merged.values.toList();
      list.sort((a, b) {
        final nameA = (a.data()['nombreSocialLower'] as String?) ?? '';
        final nameB = (b.data()['nombreSocialLower'] as String?) ?? '';
        return nameA.compareTo(nameB);
      });
      return list.take(limit).toList();
    }

    Query<Map<String, dynamic>> query = _collection
        .where('municipalidadId', isEqualTo: municipalidadId);

    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }
    
    
    if (filtroDeuda == 'deudores') {
      query = query.where('deudaAcumulada', isGreaterThan: 0).orderBy('deudaAcumulada', descending: true);
    } else if (filtroDeuda == 'saldos') {
      query = query.where('saldoAFavor', isGreaterThan: 0).orderBy('saldoAFavor', descending: true);
    } else {
      query = query.orderBy('nombreSocial');
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.limit(limit).get();
    return snap.docs;
  }

  /// Búsqueda rápida por prefijo de nombreSocial o codigoCatastral para el typeahead.
  Future<List<LocalJson>> buscarPorPrefijo({
    required String prefijo,
    String? mercadoId,
    String? municipalidadId,
    int limit = 10,
  }) async {
    final lower = prefijo.toLowerCase();

    // Consultamos por nombre sin filtros de igualdad para EVITAR requerir nuevos
    // índices compuestos en Firestore. Filtramos la municipalidad/mercado en memoria.
    final queryNombre = _collection
        .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
        .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(limit * 4); // Pedimos más para que luego del filter in-memory no nos quedemos escasos

    // Hacemos lo mismo con código
    final queryCodigo = _collection
        .where('codigoCatastralLower', isGreaterThanOrEqualTo: lower)
        .where('codigoCatastralLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(limit * 4);

    final results = await Future.wait([queryNombre.get(), queryCodigo.get()]);
    
    final Map<String, LocalJson> merged = {};
    
    // Función helper para validar si un doc cumple los filtros en memoria
    bool cumpleFiltros(Map<String, dynamic> data) {
      if (mercadoId != null && data['mercadoId'] != mercadoId) return false;
      if (municipalidadId != null && data['municipalidadId'] != municipalidadId) return false;
      return true;
    }

    // Agregar resultados de nombres que cumplan el filtro
    for (var doc in results[0].docs) {
      final data = doc.data();
      if (cumpleFiltros(data) && !merged.containsKey(doc.id)) {
        merged[doc.id] = LocalJson.fromJson(data, docId: doc.id);
      }
    }
    
    // Agregar resultados de códigos que cumplan el filtro
    for (var doc in results[1].docs) {
      final data = doc.data();
      if (cumpleFiltros(data) && !merged.containsKey(doc.id)) {
        merged[doc.id] = LocalJson.fromJson(data, docId: doc.id);
      }
    }
    
    final list = merged.values.toList();
    list.sort((a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''));
    return list.take(limit).toList();
  }

  /// Obtiene todos los locales de un mercado de forma atómica (sin stream).
  /// Útil para diálogos que necesitan contexto sin suscribirse.
  Future<List<LocalJson>> obtenerPorMercado(String mercadoId) async {
    final snapshot = await _collection.where('mercadoId', isEqualTo: mercadoId).get();
    return snapshot.docs
        .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<LocalJson>> listarPorIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<LocalJson> allResults = [];
    for (var i = 0; i < ids.length; i += 30) {
      final batchIds = ids.sublist(
        i,
        i + 30 > ids.length ? ids.length : i + 30,
      );
      final snapshot = await _collection
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();
      allResults.addAll(
        snapshot.docs.map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id)),
      );
    }
    return allResults;
  }

  Future<LocalJson?> obtenerPorId(String docId) async {
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return null;
    return LocalJson.fromJson(doc.data()!, docId: doc.id);
  }

  // UPDATE
  Future<void> actualizar(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).update(data);
  }

  /// Incrementa (o decrementa) el saldoAFavor de un local de forma atómica.
  /// Usar valor negativo para decrementar.
  Future<void> actualizarSaldoAFavor(String docId, num delta) async {
    await _collection.doc(docId).update({
      'saldoAFavor': FieldValue.increment(delta),
    });
  }

  /// Incrementa (o decrementa) la deudaAcumulada de un local de forma atómica.
  /// Usar valor negativo para decrementar al registrar un pago de deuda.
  Future<void> actualizarDeudaAcumulada(String docId, num delta) async {
    await _collection.doc(docId).update({
      'deudaAcumulada': FieldValue.increment(delta),
    });
  }

  /// Procesa un pago afectando deuda y saldo a favor de forma inteligente.
  /// 1. Primero paga la deuda acumulada.
  /// 2. Si sobra, lo suma al saldo a favor.
  Future<void> procesarPago(String docId, num monto) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _collection.doc(docId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      num deudaActual = data['deudaAcumulada'] ?? 0;
      num saldoActual = data['saldoAFavor'] ?? 0;

      num paraDeuda = monto > deudaActual ? deudaActual : monto;
      num excedente = monto - paraDeuda;

      transaction.update(docRef, {
        'deudaAcumulada': deudaActual - paraDeuda,
        'saldoAFavor': saldoActual + excedente,
        'ultimaTransaccion': Timestamp.now(),
      });
    });
  }

  /// Método Offline Safe: Usa FieldValue.increment que es soportado por la caché local de Firestore
  /// y no requiere una conexión activa a diferencia de runTransaction.
  Future<void> procesarPagoOfflineSafe(
    String docId,
    num abonoDeuda,
    num incrementoSaldo,
  ) async {
    // Timeout estricto para no colgar la UI en zonas sin señal de internet
    final connectivityResult = await Connectivity().checkConnectivity().timeout(
      const Duration(seconds: 1),
      onTimeout: () => [ConnectivityResult.none],
    );

    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    final future = _collection.doc(docId).update({
      'deudaAcumulada': FieldValue.increment(-abonoDeuda),
      'saldoAFavor': FieldValue.increment(incrementoSaldo),
      'ultimaTransaccion': FieldValue.serverTimestamp(),
    });

    if (!isOffline) {
      // Si hay internet, garantizamos que se envíe o falle en 1.5 segundos
      await future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {}, // Si tarda mucho, que siga de largo sin quebrar (background sync)
      );
    }
  }

  /// Revierte el impacto de un cobro eliminado (suma a deuda, resta de saldo).
  Future<void> revertirPago({
    required String localId,
    required num montoARecomponerDeuda,
    required num montoARestarSaldo,
  }) async {
    await _collection.doc(localId).update({
      'deudaAcumulada': FieldValue.increment(montoARecomponerDeuda),
      'saldoAFavor': FieldValue.increment(-montoARestarSaldo),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // DELETE

  // DELETE
  Future<void> eliminar(String docId, {String? municipalidadId}) async {
    // 1. Obtener los datos del local a eliminar para restarlo de las stats
    final docSnap = await _collection.doc(docId).get();
    
    String? targetMuniId = municipalidadId;
    num deudaActual = 0;

    if (docSnap.exists) {
      final data = docSnap.data()!;
      targetMuniId ??= data['municipalidadId'] as String?;
      deudaActual = (data['deudaAcumulada'] as num?) ?? 0;
    }

    if (targetMuniId != null) {
      // 2. Restar 1 local, su deuda y su cuota diaria
      final cuotaDiaria = docSnap.exists ? ((docSnap.data()!['cuotaDiaria'] as num?) ?? 0) : 0;
      _statsDs.actualizarConteo(
        municipalidadId: targetMuniId,
        deltaLocales: -1,
        deltaDeuda: -deudaActual,
        deltaCuotaDiaria: -cuotaDiaria,
      ).catchError((e) => debugPrint('Error al restar stats por local eliminado: $e'));
    }

    // 3. Finalmente eliminar el documento del local
    await _collection.doc(docId).delete();
  }

  /// Migración: Agrega municipalidadId a locales faltantes.
  Future<int> migrarLocalesFaltantes(String municipalidadId) async {
    final snapshot = await _collection.get();

    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;
    int actuallyMigrated = 0;

    for (var doc in snapshot.docs) {
      if (doc.data()['municipalidadId'] == null) {
        batch.update(doc.reference, {'municipalidadId': municipalidadId});
        actuallyMigrated++;
        count++;
      }
    }

    if (count % 500 != 0 && actuallyMigrated > 0) {
      await batch.commit();
    }

    return actuallyMigrated;
  }

  /// Migración: Inicializa codigoCatastral para locales viejos si no existe.
  /// Evitará resultados nulos en las nuevas búsquedas con OR.
  Future<int> migrarCodigoCatastralLocal() async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int migrated = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['codigoCatastral'] == null) {
        // En lugar de nulo, usamos un string vacío como default
        batch.update(doc.reference, {
          'codigoCatastral': '',
          'codigoCatastralLower': '',
        });
        migrated++;
        
        if (migrated % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (migrated > 0 && migrated % 500 != 0) await batch.commit();
    return migrated;
  }

  /// Migración: Añade campo 'nombreSocialLower' para búsqueda eficiente por prefijo.
  Future<int> migrarNombreSocialLower() async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int migrated = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['nombreSocialLower'] == null && data['nombreSocial'] != null) {
        batch.update(doc.reference, {
          'nombreSocialLower': (data['nombreSocial'] as String).toLowerCase(),
        });
        migrated++;
        if (migrated % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (migrated > 0 && migrated % 500 != 0) await batch.commit();
    return migrated;
  }

  /// ⚠️ PELIGRO: Esta función descarga todos los locales y hace N queries
  /// individuales a Firestore (una por local). Con 600 locales = ~6,000 lecturas.
  /// El botón que la llamaba fue eliminado. No volver a llamar esta función.
  @Deprecated(
    'Causa fuga masiva de lecturas en Firestore (N queries por local). '
    'Usar actualizaciones incrementales via StatsDatasource.actualizarConteo() en su lugar.',
  )
  Future<int> recalcularDeudasBasadoEnHistorial() async {
    final localesDoc = await _collection.get();
    int corregidos = 0;
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    for (var doc in localesDoc.docs) {
      final data = doc.data();
      final localId = doc.id;
      final num cuotaDiaria = data['cuotaDiaria'] ?? 0;
      final num deudaActual = data['deudaAcumulada'] ?? 0;

      // Obtener los cobros pendientes reales en la base de datos
      final cobrosPendientes = await _firestore
          .collection(FirestoreCollections.cobros)
          .where('localId', isEqualTo: localId)
          .where('estado', isEqualTo: 'pendiente')
          .get();

      final num deudaReal = cobrosPendientes.docs.length * cuotaDiaria;

      // Si la deuda acumulada almacenada no coincide con el historial real, parcharla.
      if (deudaActual != deudaReal) {
        batch.update(doc.reference, {
          'deudaAcumulada': deudaReal,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
        corregidos++;
        batchCount++;

        if (batchCount == 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    return corregidos;
  }
}
