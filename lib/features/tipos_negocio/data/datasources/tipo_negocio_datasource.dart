import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../models/tipo_negocio_model.dart';

class TipoNegocioDatasource {
  final FirebaseFirestore _firestore;

  TipoNegocioDatasource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.tiposNegocio);

  // CREATE
  Future<void> crear(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).set(data);
  }

  // READ
  Future<List<TipoNegocioJson>> listarTodos() async {
    final snapshot = await _collection.orderBy('nombre').get();
    return snapshot.docs
        .map((doc) => TipoNegocioJson.fromJson(doc.data(), docId: doc.id))
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
