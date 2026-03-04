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

  Future<MunicipalidadJson?> obtenerPorId(String docId) async {
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return null;
    return MunicipalidadJson.fromJson(doc.data()!, docId: doc.id);
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
