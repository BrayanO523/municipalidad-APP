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

  void _logMissingIndexLink({required String context, required Object error}) {
    final firebaseError = error is FirebaseException ? error : null;
    final code = firebaseError?.code ?? 'unknown';
    final message = '${firebaseError?.message ?? ''}\n${error.toString()}';
    final match = RegExp(
      r'https://console\.firebase\.google\.com/\S+',
    ).firstMatch(message);
    final url = match?.group(0);

    if (url != null) {
      debugPrint('[INDEX_LINK][$context] $url');
      print('[INDEX_LINK][$context] $url');
      return;
    }

    debugPrint('[INDEX_LINK][$context] code=$code (sin URL automática)');
    debugPrint('[INDEX_LINK][$context] $message');
    print('[INDEX_LINK][$context] code=$code (sin URL automática)');
    print('[INDEX_LINK][$context] $message');
  }

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    final batch = _firestore.batch();
    batch.set(_collection.doc(docId), data);

    final municipalidadId = data['municipalidadId'] as String?;
    if (municipalidadId != null) {
      await _statsDs.actualizarConteo(
        municipalidadId: municipalidadId,
        mercadoId: data['mercadoId'] as String?,
        deltaLocales: 1,
        deltaDeuda: (data['deudaAcumulada'] as num?) ?? 0,
        deltaSaldo: (data['saldoAFavor'] as num?) ?? 0,
        deltaCuotaDiaria: (data['cuotaDiaria'] as num?) ?? 0,
        batch: batch,
      );
    }
    await batch.commit();
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
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  listarPaginaPorMercado({
    required String mercadoId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 20,
    String filtroDeuda = 'todos',
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final raw = searchQuery.trim().toLowerCase();
      final isNumeric = RegExp(r'^\d+$').hasMatch(raw);
      final lower = isNumeric ? raw.padLeft(3, '0') : raw;
      try {
        final queryNombre = _collection
            .where('mercadoId', isEqualTo: mercadoId)
            .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
            .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('nombreSocialLower')
            .limit(limit);

        final queryCodigo = _collection
            .where('mercadoId', isEqualTo: mercadoId)
            .where('codigoLower', isGreaterThanOrEqualTo: lower)
            .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('codigoLower')
            .limit(limit);

        final results = await Future.wait([
          queryNombre.get(),
          queryCodigo.get(),
        ]);

        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
            {};
        for (final doc in results[0].docs) {
          merged[doc.id] = doc;
        }
        for (final doc in results[1].docs) {
          merged[doc.id] = doc;
        }
        final list = merged.values.toList();
        list.sort((a, b) {
          final nameA = (a.data()['nombreSocialLower'] as String?) ?? '';
          final nameB = (b.data()['nombreSocialLower'] as String?) ?? '';
          return nameA.compareTo(nameB);
        });
        return list.take(limit).toList();
      } catch (e) {
        _logMissingIndexLink(context: 'locales/mercado-search', error: e);

        // Fallback compatible mientras se crea el indice.
        final queryNombre = _collection
            .where('mercadoId', isEqualTo: mercadoId)
            .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
            .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .limit(limit);

        final queryCodigo = _collection
            .where('codigoLower', isGreaterThanOrEqualTo: lower)
            .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .limit(limit * 3);

        final results = await Future.wait([
          queryNombre.get(),
          queryCodigo.get(),
        ]);

        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
            {};
        for (final doc in results[0].docs) {
          merged[doc.id] = doc;
        }
        for (final doc in results[1].docs) {
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
    }
    Query<Map<String, dynamic>> query = _collection.where(
      'mercadoId',
      isEqualTo: mercadoId,
    );

    if (filtroDeuda == 'deudores') {
      query = query
          .where('deudaAcumulada', isGreaterThan: 0)
          .orderBy('deudaAcumulada', descending: true);
    } else if (filtroDeuda == 'saldos') {
      query = query
          .where('saldoAFavor', isGreaterThan: 0)
          .orderBy('saldoAFavor', descending: true);
    } else {
      query = query.orderBy('nombreSocial');
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.limit(limit).get();
    return snap.docs;
  }

  /// Migración: Inicializa codigoLower si falta, usando el valor de codigo.
  /// Retorna cuántos documentos fueron actualizados.
  Future<int> migrarCodigoLower({String? municipalidadId}) async {
    Query<Map<String, dynamic>> query = _collection;
    if (municipalidadId != null) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int count = 0;
    int updated = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final codigo = (data['codigo'] as String?)?.trim();
      final codigoLower = (data['codigoLower'] as String?)?.trim();

      if (codigo != null &&
          codigo.isNotEmpty &&
          (codigoLower == null || codigoLower.isEmpty)) {
        batch.update(doc.reference, {'codigoLower': codigo.toLowerCase()});
        updated++;
        count++;

        if (count % 450 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
    }

    if (count % 450 != 0 && updated > 0) {
      await batch.commit();
    }

    return updated;
  }

  /// Página de locales por municipalidad con paginación.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  listarPaginaPorMunicipalidad({
    required String municipalidadId,
    String? mercadoId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 20,
    String filtroDeuda = 'todos',
    List<String>? filterLocalIds,
  }) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final raw = searchQuery.trim().toLowerCase();
      final isNumeric = RegExp(r'^\d+$').hasMatch(raw);
      final lower = isNumeric ? raw.padLeft(3, '0') : raw;
      Query<Map<String, dynamic>> baseQuery = _collection.where(
        'municipalidadId',
        isEqualTo: municipalidadId,
      );

      if (mercadoId != null) {
        baseQuery = baseQuery.where('mercadoId', isEqualTo: mercadoId);
      }

      try {
        final queryNombre = baseQuery
            .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
            .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('nombreSocialLower')
            .limit(limit);

        final queryCodigo = baseQuery
            .where('codigoLower', isGreaterThanOrEqualTo: lower)
            .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('codigoLower')
            .limit(limit);

        final results = await Future.wait([
          queryNombre.get(),
          queryCodigo.get(),
        ]);

        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
            {};
        for (final doc in results[0].docs) {
          merged[doc.id] = doc;
        }
        for (final doc in results[1].docs) {
          merged[doc.id] = doc;
        }
        final list = merged.values.toList();
        list.sort((a, b) {
          final nameA = (a.data()['nombreSocialLower'] as String?) ?? '';
          final nameB = (b.data()['nombreSocialLower'] as String?) ?? '';
          return nameA.compareTo(nameB);
        });
        return list.take(limit).toList();
      } catch (e) {
        _logMissingIndexLink(context: 'locales/municipalidad-search', error: e);

        // Fallback compatible mientras se crea el indice.
        final queryNombre = baseQuery
            .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
            .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .limit(limit);

        final queryCodigo = _collection
            .where('codigoLower', isGreaterThanOrEqualTo: lower)
            .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .limit(limit * 3);

        final results = await Future.wait([
          queryNombre.get(),
          queryCodigo.get(),
        ]);

        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
            {};
        for (final doc in results[0].docs) {
          merged[doc.id] = doc;
        }
        for (final doc in results[1].docs) {
          final data = doc.data();
          var match = data['municipalidadId'] == municipalidadId;
          if (mercadoId != null && data['mercadoId'] != mercadoId) {
            match = false;
          }
          if (match) {
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
    }
    Query<Map<String, dynamic>> query = _collection.where(
      'municipalidadId',
      isEqualTo: municipalidadId,
    );

    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }

    final isFilteringByUser = filterLocalIds != null;
    if (isFilteringByUser) {
      if (filterLocalIds.isEmpty) return [];
      // Limitamos a los primeros 30 para cumplir con la restricción de Firestore en 'whereIn'
      query = query.where(
        FieldPath.documentId,
        whereIn: filterLocalIds.take(30).toList(),
      );
    }

    final hasLocalFilter = isFilteringByUser && filterLocalIds.isNotEmpty;

    // Aplicar filtros de deuda/saldo en Firestore SOLO SI no estamos filtrando por ID (key).
    // Firestore no permite desigualdades en otros campos si se filtra por ID con igualdad/whereIn.
    if (!hasLocalFilter) {
      if (filtroDeuda == 'deudores') {
        query = query.where('deudaAcumulada', isGreaterThan: 0);
      } else if (filtroDeuda == 'saldos') {
        query = query.where('saldoAFavor', isGreaterThan: 0);
      }
    }

    // Firestore NO permite un orderBy en un campo distinto si se usa whereIn en el ID (o cualquier campo).
    // Si tenemos filtro de locales, el ordenamiento se hará en memoria abajo.
    if (!hasLocalFilter) {
      if (filtroDeuda == 'deudores') {
        query = query.orderBy('deudaAcumulada', descending: true);
      } else if (filtroDeuda == 'saldos') {
        query = query.orderBy('saldoAFavor', descending: true);
      } else {
        query = query.orderBy('nombreSocial');
      }
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.limit(limit).get();
    final docs = snap.docs;

    // Si hubiéramos aplicado filtro por local, filtramos y ordenamos en memoria
    if (hasLocalFilter) {
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = docs;

      // Aplicar el filtro de deuda/saldo que no pudimos aplicar en Firestore
      if (filtroDeuda == 'deudores') {
        filtered = filtered.where(
          (doc) => ((doc.data()['deudaAcumulada'] as num?) ?? 0) > 0,
        );
      } else if (filtroDeuda == 'saldos') {
        filtered = filtered.where(
          (doc) => ((doc.data()['saldoAFavor'] as num?) ?? 0) > 0,
        );
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> list = filtered
          .toList();
      list.sort((a, b) {
        if (filtroDeuda == 'deudores') {
          final dA = (a.data()['deudaAcumulada'] as num?) ?? 0;
          final dB = (b.data()['deudaAcumulada'] as num?) ?? 0;
          return dB.compareTo(dA);
        } else if (filtroDeuda == 'saldos') {
          final sA = (a.data()['saldoAFavor'] as num?) ?? 0;
          final sB = (b.data()['saldoAFavor'] as num?) ?? 0;
          return sB.compareTo(sA);
        } else {
          final nA = (a.data()['nombreSocial'] as String?) ?? '';
          final nB = (b.data()['nombreSocial'] as String?) ?? '';
          return nA.compareTo(nB);
        }
      });
      return list;
    }

    return docs;
  }

  Future<int> contarLocalesPorMunicipalidad({
    required String municipalidadId,
    String? mercadoId,
    String? searchQuery,
    String filtroDeuda = 'todos',
    List<String>? filterLocalIds,
  }) async {
    if (filterLocalIds != null) {
      if (filterLocalIds.isEmpty) return 0;

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
      for (final batch in _chunkIds(filterLocalIds, 30)) {
        Query<Map<String, dynamic>> q = _collection
            .where('municipalidadId', isEqualTo: municipalidadId)
            .where(FieldPath.documentId, whereIn: batch);
        if (mercadoId != null) {
          q = q.where('mercadoId', isEqualTo: mercadoId);
        }
        final snap = await q.get();
        docs.addAll(snap.docs);
      }
      return _filtrarYOrdenarEnMemoria(
        docs: docs,
        searchQuery: searchQuery,
        filtroDeuda: filtroDeuda,
      ).length;
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final raw = searchQuery.trim().toLowerCase();
      final isNumeric = RegExp(r'^\d+$').hasMatch(raw);
      final lower = isNumeric ? raw.padLeft(3, '0') : raw;
      Query<Map<String, dynamic>> baseQuery = _collection.where(
        'municipalidadId',
        isEqualTo: municipalidadId,
      );
      if (mercadoId != null) {
        baseQuery = baseQuery.where('mercadoId', isEqualTo: mercadoId);
      }

      try {
        final queryNombre = baseQuery
            .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
            .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('nombreSocialLower');

        final queryCodigo = baseQuery
            .where('codigoLower', isGreaterThanOrEqualTo: lower)
            .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('codigoLower');

        final results = await Future.wait([
          queryNombre.get(),
          queryCodigo.get(),
        ]);

        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
            {};
        for (final doc in results[0].docs) {
          merged[doc.id] = doc;
        }
        for (final doc in results[1].docs) {
          merged[doc.id] = doc;
        }

        return _filtrarYOrdenarEnMemoria(
          docs: merged.values,
          searchQuery: searchQuery,
          filtroDeuda: filtroDeuda,
        ).length;
      } catch (e) {
        _logMissingIndexLink(
          context: 'locales/municipalidad-search-count',
          error: e,
        );

        final queryNombre = baseQuery
            .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
            .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff');

        final queryCodigo = _collection
            .where('codigoLower', isGreaterThanOrEqualTo: lower)
            .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff');

        final results = await Future.wait([
          queryNombre.get(),
          queryCodigo.get(),
        ]);

        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> merged =
            {};
        for (final doc in results[0].docs) {
          merged[doc.id] = doc;
        }
        for (final doc in results[1].docs) {
          final data = doc.data();
          var match = data['municipalidadId'] == municipalidadId;
          if (mercadoId != null && data['mercadoId'] != mercadoId) {
            match = false;
          }
          if (match) {
            merged[doc.id] = doc;
          }
        }

        return _filtrarYOrdenarEnMemoria(
          docs: merged.values,
          searchQuery: searchQuery,
          filtroDeuda: filtroDeuda,
        ).length;
      }
    }

    Query<Map<String, dynamic>> query = _collection.where(
      'municipalidadId',
      isEqualTo: municipalidadId,
    );
    if (mercadoId != null) {
      query = query.where('mercadoId', isEqualTo: mercadoId);
    }
    if (filtroDeuda == 'deudores') {
      query = query.where('deudaAcumulada', isGreaterThan: 0);
    } else if (filtroDeuda == 'saldos') {
      query = query.where('saldoAFavor', isGreaterThan: 0);
    }

    try {
      final aggregate = await query.count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      final snap = await query.get();
      return snap.size;
    }
  }

  Iterable<List<String>> _chunkIds(List<String> ids, int size) sync* {
    for (var i = 0; i < ids.length; i += size) {
      final end = i + size > ids.length ? ids.length : i + size;
      yield ids.sublist(i, end);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarYOrdenarEnMemoria({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String? searchQuery,
    required String filtroDeuda,
  }) {
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = docs;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final raw = searchQuery.trim().toLowerCase();
      final isNumeric = RegExp(r'^\d+$').hasMatch(raw);
      final lower = isNumeric ? raw.padLeft(3, '0') : raw;
      filtered = filtered.where((doc) {
        final data = doc.data();
        final nombre = (data['nombreSocialLower'] as String?) ?? '';
        final codigo = (data['codigoLower'] as String?) ?? '';
        return nombre.startsWith(lower) || codigo.startsWith(lower);
      });
    }

    if (filtroDeuda == 'deudores') {
      filtered = filtered.where(
        (doc) => ((doc.data()['deudaAcumulada'] as num?) ?? 0) > 0,
      );
    } else if (filtroDeuda == 'saldos') {
      filtered = filtered.where(
        (doc) => ((doc.data()['saldoAFavor'] as num?) ?? 0) > 0,
      );
    }

    final list = filtered.toList();
    list.sort((a, b) {
      if (filtroDeuda == 'deudores') {
        final dA = (a.data()['deudaAcumulada'] as num?) ?? 0;
        final dB = (b.data()['deudaAcumulada'] as num?) ?? 0;
        return dB.compareTo(dA);
      }
      if (filtroDeuda == 'saldos') {
        final sA = (a.data()['saldoAFavor'] as num?) ?? 0;
        final sB = (b.data()['saldoAFavor'] as num?) ?? 0;
        return sB.compareTo(sA);
      }
      final nA = (a.data()['nombreSocial'] as String?) ?? '';
      final nB = (b.data()['nombreSocial'] as String?) ?? '';
      return nA.compareTo(nB);
    });
    return list;
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
    try {
      Query<Map<String, dynamic>> queryNombre = _collection
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff');

      Query<Map<String, dynamic>> queryCodigo = _collection
          .where('codigoLower', isGreaterThanOrEqualTo: lower)
          .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff');

      if (mercadoId != null) {
        queryNombre = queryNombre.where('mercadoId', isEqualTo: mercadoId);
        queryCodigo = queryCodigo.where('mercadoId', isEqualTo: mercadoId);
      }
      if (municipalidadId != null) {
        queryNombre = queryNombre.where(
          'municipalidadId',
          isEqualTo: municipalidadId,
        );
        queryCodigo = queryCodigo.where(
          'municipalidadId',
          isEqualTo: municipalidadId,
        );
      }

      queryNombre = queryNombre.orderBy('nombreSocialLower').limit(limit * 2);
      queryCodigo = queryCodigo.orderBy('codigoLower').limit(limit * 2);

      final results = await Future.wait([queryNombre.get(), queryCodigo.get()]);

      final Map<String, LocalJson> merged = {};
      for (final doc in results[0].docs) {
        merged[doc.id] = LocalJson.fromJson(doc.data(), docId: doc.id);
      }
      for (final doc in results[1].docs) {
        merged[doc.id] = LocalJson.fromJson(doc.data(), docId: doc.id);
      }

      final list = merged.values.toList();
      list.sort(
        (a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''),
      );
      return list.take(limit).toList();
    } catch (e) {
      _logMissingIndexLink(context: 'locales/typeahead-search', error: e);

      // Fallback compatible mientras se crea el indice.
      final queryNombre = _collection
          .where('nombreSocialLower', isGreaterThanOrEqualTo: lower)
          .where('nombreSocialLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(limit * 4);

      final queryCodigo = _collection
          .where('codigoLower', isGreaterThanOrEqualTo: lower)
          .where('codigoLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(limit * 4);

      final results = await Future.wait([queryNombre.get(), queryCodigo.get()]);

      final Map<String, LocalJson> merged = {};

      bool cumpleFiltros(Map<String, dynamic> data) {
        if (mercadoId != null && data['mercadoId'] != mercadoId) return false;
        if (municipalidadId != null &&
            data['municipalidadId'] != municipalidadId)
          return false;
        return true;
      }

      for (final doc in results[0].docs) {
        final data = doc.data();
        if (cumpleFiltros(data) && !merged.containsKey(doc.id)) {
          merged[doc.id] = LocalJson.fromJson(data, docId: doc.id);
        }
      }

      for (final doc in results[1].docs) {
        final data = doc.data();
        if (cumpleFiltros(data) && !merged.containsKey(doc.id)) {
          merged[doc.id] = LocalJson.fromJson(data, docId: doc.id);
        }
      }

      final list = merged.values.toList();
      list.sort(
        (a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''),
      );
      return list.take(limit).toList();
    }
  }

  /// Obtiene todos los locales de un mercado de forma atómica (sin stream).
  /// Útil para diálogos que necesitan contexto sin suscribirse.
  Future<List<LocalJson>> obtenerPorMercado(String mercadoId) async {
    final snapshot = await _collection
        .where('mercadoId', isEqualTo: mercadoId)
        .get();
    return snapshot.docs
        .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<LocalJson>> listarPorIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final List<List<String>> batches = [];
    for (var i = 0; i < ids.length; i += 30) {
      batches.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }

    // Ejecutar todas las peticiones en paralelo para mayor velocidad
    final snapshots = await Future.wait(
      batches.map(
        (batchIds) =>
            _collection.where(FieldPath.documentId, whereIn: batchIds).get(),
      ),
    );

    final List<LocalJson> allResults = [];
    for (final snapshot in snapshots) {
      allResults.addAll(
        snapshot.docs.map(
          (doc) => LocalJson.fromJson(doc.data(), docId: doc.id),
        ),
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

  /// Actualiza un local y sincroniza deltas de cuota y deuda con Stats.
  Future<void> actualizarConStats({
    required String localId,
    required Map<String, dynamic> data,
    num deltaCuota = 0,
    num deltaDeuda = 0,
    num deltaSaldo = 0,
  }) async {
    final batch = _firestore.batch();
    batch.update(_collection.doc(localId), data);

    final muniId = data['municipalidadId'] as String?;
    if (muniId != null &&
        (deltaCuota != 0 || deltaDeuda != 0 || deltaSaldo != 0)) {
      await _statsDs.actualizarConteo(
        municipalidadId: muniId,
        mercadoId: data['mercadoId'] as String?,
        deltaCuotaDiaria: deltaCuota,
        deltaDeuda: deltaDeuda,
        deltaSaldo: deltaSaldo,
        batch: batch,
      );
    }
    await batch.commit();
  }

  /// Incrementa (o decrementa) el saldoAFavor de un local de forma atómica.
  /// Usar valor negativo para decrementar.
  Future<void> actualizarSaldoAFavor(
    String docId,
    num delta, {
    WriteBatch? batch,
  }) async {
    final ref = _collection.doc(docId);
    final data = {'saldoAFavor': FieldValue.increment(delta)};
    if (batch != null) {
      batch.update(ref, data);
    } else {
      await ref.update(data);
    }
  }

  /// Incrementa (o decrementa) la deudaAcumulada de un local de forma atómica.
  /// Usar valor negativo para decrementar al registrar un pago de deuda.
  Future<void> actualizarDeudaAcumulada(
    String docId,
    num delta, {
    WriteBatch? batch,
  }) async {
    final ref = _collection.doc(docId);
    final data = {'deudaAcumulada': FieldValue.increment(delta)};
    if (batch != null) {
      batch.update(ref, data);
    } else {
      await ref.update(data);
    }
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

  /// Ajusta la deuda de un local manualmente y sincroniza con las estadísticas.
  /// Si [esPago] es true, la reducción de deuda se cuenta como recaudación de hoy.
  Future<void> ajustarDeudaManual({
    required String localId,
    required num nuevaDeuda,
    required num deudaAnterior,
    required String municipalidadId,
    bool esPago = true,
  }) async {
    final batch = _firestore.batch();
    final deltaDeuda = nuevaDeuda - deudaAnterior;

    // 1. Actualizar el local
    batch.update(_collection.doc(localId), {
      'deudaAcumulada': nuevaDeuda,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'ajustadoManualmente': true,
    });

    // 2. Actualizar Stats
    // Si la deuda bajó (delta negativo) y es un pago, deltaRecaudado es el valor absoluto del pago.
    final num deltaRecaudado = (esPago && deltaDeuda < 0) ? -deltaDeuda : 0;

    final localSnap = await _collection.doc(localId).get();
    final mercadoId = localSnap.data()?['mercadoId'] as String?;
    if (mercadoId != null) {
      await _statsDs.actualizarPorAjusteManual(
        municipalidadId: municipalidadId,
        mercadoId: mercadoId,
        deltaDeuda: deltaDeuda,
        deltaRecaudado: deltaRecaudado,
        batch: batch,
      );
    }

    await batch.commit();
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
        onTimeout:
            () {}, // Si tarda mucho, que siga de largo sin quebrar (background sync)
      );
    }
  }

  /// Revierte el impacto de un cobro eliminado (suma a deuda, resta de saldo).
  Future<void> revertirPago({
    required String localId,
    required num montoARecomponerDeuda,
    required num montoARestarSaldo,
    WriteBatch? batch,
  }) async {
    final ref = _collection.doc(localId);
    final data = {
      'deudaAcumulada': FieldValue.increment(montoARecomponerDeuda),
      'saldoAFavor': FieldValue.increment(-montoARestarSaldo),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    if (batch != null) {
      batch.update(ref, data);
    } else {
      await ref.update(data);
    }
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
      // 2. Restar 1 local, su deuda, su saldo y su cuota diaria
      final cuotaDiaria = docSnap.exists
          ? ((docSnap.data()!['cuotaDiaria'] as num?) ?? 0)
          : 0;
      final saldoActual = docSnap.exists
          ? ((docSnap.data()!['saldoAFavor'] as num?) ?? 0)
          : 0;

      _statsDs
          .actualizarConteo(
            municipalidadId: targetMuniId,
            mercadoId: docSnap.data()?['mercadoId'] as String?,
            deltaLocales: -1,
            deltaDeuda: -deudaActual,
            deltaSaldo: -saldoActual,
            deltaCuotaDiaria: -cuotaDiaria,
          )
          .catchError(
            (e) => debugPrint('Error al restar stats por local eliminado: $e'),
          );
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
        batch.update(doc.reference, {'codigoCatastral': '', 'codigoLower': ''});
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

  /// PELIGRO: Esta función descarga todos los locales y hace N queries
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
