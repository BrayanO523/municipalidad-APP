import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../models/mercado_model.dart';

class MercadoDatasource {
  final FirebaseFirestore _firestore;

  MercadoDatasource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.mercados);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
  }

  // READ
  Future<List<MercadoJson>> listarTodos() async {
    final snapshot = await _collection.orderBy('nombre').get();
    return snapshot.docs
        .map((doc) => MercadoJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<MercadoJson>> listarPorMunicipalidad(
    String municipalidadId,
  ) async {
    final snapshot = await _collection
        .where('municipalidadId', isEqualTo: municipalidadId)
        .orderBy('nombre')
        .get();
    return snapshot.docs
        .map((doc) => MercadoJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  /// Página de mercados con paginación por cursor y búsqueda por prefijo.
  Future<({List<MercadoJson> items, QueryDocumentSnapshot? lastDoc})>
  listarPagina({
    String? municipalidadId,
    String? searchQuery,
    QueryDocumentSnapshot? lastDoc,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> query = _collection.orderBy('nombre');

    if (municipalidadId != null) {
      query = _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .orderBy('nombre');
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lower = searchQuery.toLowerCase();
      if (municipalidadId != null) {
        query = _collection
            .where('municipalidadId', isEqualTo: municipalidadId)
            .where('nombreLower', isGreaterThanOrEqualTo: lower)
            .where('nombreLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('nombreLower');
      } else {
        query = _collection
            .where('nombreLower', isGreaterThanOrEqualTo: lower)
            .where('nombreLower', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('nombreLower');
      }
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.limit(limit).get();
    final items = snapshot.docs
        .map((doc) => MercadoJson.fromJson(doc.data(), docId: doc.id))
        .toList();
    final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    return (items: items, lastDoc: newLastDoc);
  }

  /// Búsqueda rápida por prefijo para el typeahead (requiere campo nombreLower).
  Future<List<MercadoJson>> buscarPorPrefijo({
    required String prefijo,
    String? municipalidadId,
    int limit = 10,
  }) async {
    final lower = prefijo.toLowerCase();
    Query<Map<String, dynamic>> query;

    if (municipalidadId != null) {
      query = _collection
          .where('municipalidadId', isEqualTo: municipalidadId)
          .where('nombreLower', isGreaterThanOrEqualTo: lower)
          .where('nombreLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .orderBy('nombreLower')
          .limit(limit);
    } else {
      query = _collection
          .where('nombreLower', isGreaterThanOrEqualTo: lower)
          .where('nombreLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .orderBy('nombreLower')
          .limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MercadoJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<MercadoJson?> obtenerPorId(String docId) async {
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return null;
    return MercadoJson.fromJson(doc.data()!, docId: doc.id);
  }

  // UPDATE
  Future<void> actualizar(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).update(data);
  }

  // DELETE
  Future<void> eliminar(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Migración: Agrega municipalidadId a mercados faltantes.
  Future<int> migrarMercadosFaltantes(String municipalidadId) async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int actuallyMigrated = 0;

    for (var doc in snapshot.docs) {
      if (doc.data()['municipalidadId'] == null) {
        batch.update(doc.reference, {'municipalidadId': municipalidadId});
        actuallyMigrated++;
      }
    }

    if (actuallyMigrated > 0) await batch.commit();
    return actuallyMigrated;
  }

  /// Migración: Añade campo 'nombreLower' para búsqueda eficiente por prefijo.
  Future<int> migrarNombreLower() async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) return 0;

    WriteBatch batch = _firestore.batch();
    int migrated = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['nombreLower'] == null && data['nombre'] != null) {
        batch.update(doc.reference, {
          'nombreLower': (data['nombre'] as String).toLowerCase(),
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
}
