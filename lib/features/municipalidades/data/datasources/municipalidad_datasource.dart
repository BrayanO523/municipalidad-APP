import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../models/municipalidad_model.dart';

class MunicipalidadDatasource {
  final FirebaseFirestore _firestore;

  MunicipalidadDatasource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.municipalidades);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
  }

  // READ
  Future<List<MunicipalidadJson>> listarTodas() async {
    final snapshot = await _collection.orderBy('nombre').get();
    return snapshot.docs
        .map((doc) => MunicipalidadJson.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  Stream<List<MunicipalidadJson>> streamTodas() {
    return _collection
        .orderBy('nombre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MunicipalidadJson.fromJson(doc.data(), docId: doc.id),
              )
              .toList(),
        );
  }

  Future<MunicipalidadJson?> obtenerPorId(String docId) async {
    try {
      final doc = await _collection.doc(docId).get().timeout(const Duration(seconds: 3));
      if (!doc.exists) return null;
      return MunicipalidadJson.fromJson(doc.data()!, docId: doc.id);
    } catch (_) {
      final docCache = await _collection.doc(docId).get(const GetOptions(source: Source.cache));
      if (!docCache.exists) return null;
      return MunicipalidadJson.fromJson(docCache.data()!, docId: docCache.id);
    }
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
