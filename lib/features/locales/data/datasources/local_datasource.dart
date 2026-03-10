import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../models/local_model.dart';

class LocalDatasource {
  final FirebaseFirestore _firestore;

  LocalDatasource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.locales);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
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
  Future<QuerySnapshot<Map<String, dynamic>>> listarPaginaPorMercado({
    required String mercadoId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _collection
        .where('mercadoId', isEqualTo: mercadoId)
        .orderBy('nombreSocial');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lower = searchQuery.toLowerCase();
      query = _collection
          .where('mercadoId', isEqualTo: mercadoId)
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .orderBy('nombreSocialLower');
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return await query.limit(limit).get();
  }

  /// Página de locales por municipalidad con paginación.
  Future<QuerySnapshot<Map<String, dynamic>>> listarPaginaPorMunicipalidad({
    required String municipalidadId,
    String? mercadoId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _collection
        .where('municipalidadId', isEqualTo: municipalidadId)
        .orderBy('nombreSocial');

    if (mercadoId != null) {
      query = _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .where('mercadoId', isEqualTo: mercadoId)
          .orderBy('nombreSocial');
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lower = searchQuery.toLowerCase();
      query = _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .orderBy('nombreSocialLower');
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return await query.limit(limit).get();
  }

  /// Búsqueda rápida por prefijo de nombreSocial para el typeahead.
  Future<List<LocalJson>> buscarPorPrefijo({
    required String prefijo,
    String? mercadoId,
    String? municipalidadId,
    int limit = 10,
  }) async {
    final lower = prefijo.toLowerCase();
    Query<Map<String, dynamic>> query = _collection
        .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
        .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .orderBy('nombreSocialLower')
        .limit(limit);

    if (mercadoId != null) {
      query = _collection
          .where('mercadoId', isEqualTo: mercadoId)
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .orderBy('nombreSocialLower')
          .limit(limit);
    } else if (municipalidadId != null) {
      query = _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .orderBy('nombreSocialLower')
          .limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
        .toList();
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
        onTimeout: () =>
            {}, // Si tarda mucho, que siga de largo sin quebrar (background sync)
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
  Future<void> eliminar(String docId) async {
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

  /// Reparación de Datos: Recalcula la deuda acumulada de todos los locales
  /// basándose en la cantidad real de registros "pendientes" en su historial.
  /// Útil si se eliminaron cobros manualmente o hubo desincronización.
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
