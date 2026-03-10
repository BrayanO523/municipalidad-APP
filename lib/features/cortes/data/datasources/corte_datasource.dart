import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/corte_model.dart';
import '../../../../core/errors/failures.dart';

class CorteDatasource {
  final FirebaseFirestore _firestore;

  CorteDatasource(this._firestore);

  Stream<List<CorteModel>> streamPorMunicipalidad(String municipalidadId) {
    return _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .orderBy('fechaCorte', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CorteModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<CorteModel>> streamPorCobrador(String cobradorId) {
    return _firestore
        .collection('cortes')
        .where('cobradorId', isEqualTo: cobradorId)
        .orderBy('fechaCorte', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CorteModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> crearCorte(CorteModel corte) async {
    try {
      final docRef = _firestore.collection('cortes').doc(); // Auto-ID
      final json = corte.toMap();
      await docRef.set(json);
    } catch (e) {
      throw ServerFailure('Error al crear corte: $e');
    }
  }
}
