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
}
