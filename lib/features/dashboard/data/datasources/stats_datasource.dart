import 'package:cloud_firestore/cloud_firestore.dart';

class StatsModel {
  final num totalCobrado;
  final num totalDeuda;
  final num totalSaldoAFavor;
  final int cantidadLocales;
  final int cantidadMercados;
  final DateTime? ultimaActualizacion;

  StatsModel({
    this.totalCobrado = 0,
    this.totalDeuda = 0,
    this.totalSaldoAFavor = 0,
    this.cantidadLocales = 0,
    this.cantidadMercados = 0,
    this.ultimaActualizacion,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      totalCobrado: (json['totalCobrado'] as num?) ?? 0,
      totalDeuda: (json['totalDeuda'] as num?) ?? 0,
      totalSaldoAFavor: (json['totalSaldoAFavor'] as num?) ?? 0,
      cantidadLocales: (json['cantidadLocales'] as num?)?.toInt() ?? 0,
      cantidadMercados: (json['cantidadMercados'] as num?)?.toInt() ?? 0,
      ultimaActualizacion: (json['ultimaActualizacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'totalCobrado': totalCobrado,
    'totalDeuda': totalDeuda,
    'totalSaldoAFavor': totalSaldoAFavor,
    'cantidadLocales': cantidadLocales,
    'cantidadMercados': cantidadMercados,
    'ultimaActualizacion': FieldValue.serverTimestamp(),
  };
}

class StatsDatasource {
  final FirebaseFirestore _firestore;

  StatsDatasource(this._firestore);

  DocumentReference<Map<String, dynamic>> _doc(String municipalidadId) =>
      _firestore.collection('stats').doc(municipalidadId);

  Stream<StatsModel> streamStats(String municipalidadId) {
    return _doc(municipalidadId).snapshots().map((doc) {
      if (!doc.exists) return StatsModel();
      return StatsModel.fromJson(doc.data()!);
    });
  }

  /// Actualización atómica de estadísticas al registrar un cobro.
  Future<void> actualizarAlCobrar({
    required String municipalidadId,
    required num montoCobrado,
    required num abonoDeuda,
    required num incrementoSaldo,
  }) async {
    await _doc(municipalidadId).set({
      'totalCobrado': FieldValue.increment(montoCobrado),
      'totalDeuda': FieldValue.increment(-abonoDeuda),
      'totalSaldoAFavor': FieldValue.increment(incrementoSaldo),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Actualización al registrar o eliminar un local/mercado.
  Future<void> actualizarConteo({
    required String municipalidadId,
    int deltaLocales = 0,
    int deltaMercados = 0,
    num deltaDeuda = 0,
  }) async {
    await _doc(municipalidadId).set({
      'cantidadLocales': FieldValue.increment(deltaLocales),
      'cantidadMercados': FieldValue.increment(deltaMercados),
    }, SetOptions(merge: true));
  }

}
