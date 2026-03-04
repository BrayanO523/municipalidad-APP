import 'package:cloud_firestore/cloud_firestore.dart';

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
    final snapshot = await _collection.orderBy('nombreSocial').get();
    return snapshot.docs
        .map((doc) => LocalJson.fromJson(doc.data(), docId: doc.id))
        .toList();
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

  Future<LocalJson?> obtenerPorId(String docId) async {
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return null;
    return LocalJson.fromJson(doc.data()!, docId: doc.id);
  }

  // UPDATE
  Future<void> actualizar(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).update(data);
  }

  // DELETE
  Future<void> eliminar(String docId) async {
    await _collection.doc(docId).delete();
  }
}
