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

    if (actuallyMigrated > 0) {
      await batch.commit();
    }
    return actuallyMigrated;
  }
}
