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

  Future<List<CobroJson>> listarPorFecha(DateTime fecha) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));
    final snapshot = await _collection
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .get();
    return snapshot.docs
        .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<CobroJson>> listarRecientes({int limite = 20}) async {
    final snapshot = await _collection
        .orderBy('fecha', descending: true)
        .limit(limite)
        .get();
    return snapshot.docs
        .map((doc) => CobroJson.fromJson(doc.data(), docId: doc.id))
        .toList();
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
