import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class StatsModel {
  final num totalCobrado;
  final num totalDeuda;
  final num totalSaldoAFavor;
  final int cantidadLocales;
  final int cantidadMercados;
  final DateTime? ultimaActualizacion;
  
  // Mapa agrupado por "yyyy-MM-dd"
  final Map<String, dynamic> diario;

  StatsModel({
    this.totalCobrado = 0,
    this.totalDeuda = 0,
    this.totalSaldoAFavor = 0,
    this.cantidadLocales = 0,
    this.cantidadMercados = 0,
    this.ultimaActualizacion,
    this.diario = const {},
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      totalCobrado: (json['totalCobrado'] as num?) ?? 0,
      totalDeuda: (json['totalDeuda'] as num?) ?? 0,
      totalSaldoAFavor: (json['totalSaldoAFavor'] as num?) ?? 0,
      cantidadLocales: (json['cantidadLocales'] as num?)?.toInt() ?? 0,
      cantidadMercados: (json['cantidadMercados'] as num?)?.toInt() ?? 0,
      ultimaActualizacion: (json['ultimaActualizacion'] as Timestamp?)?.toDate(),
      diario: json['diario'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'totalCobrado': totalCobrado,
    'totalDeuda': totalDeuda,
    'totalSaldoAFavor': totalSaldoAFavor,
    'cantidadLocales': cantidadLocales,
    'cantidadMercados': cantidadMercados,
    'ultimaActualizacion': FieldValue.serverTimestamp(),
    'diario': diario,
  };

  /// Obtiene la recaudación específica del día actual local.
  num get recaudacionHoy {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final obj = diario[key];
    if (obj == null || obj is! Map) return 0;
    return (obj['recaudado'] as num?) ?? 0;
  }

  /// Obtiene la cantidad de recibos emitidos el día actual local.
  int get cobrosHoy {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final obj = diario[key];
    if (obj == null || obj is! Map) return 0;
    return ((obj['cobros'] as num?) ?? 0).toInt();
  }
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
  /// Usa `update()` para que los puntos en 'diario.$key.recaudado' creen campos ANIDADOS.
  Future<void> actualizarAlCobrar({
    required String municipalidadId,
    required num montoCobrado,
    required num abonoDeuda,
    required num incrementoSaldo,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // update() interpreta puntos como rutas anidadas (diario -> key -> recaudado)
    await _doc(municipalidadId).update({
      'totalCobrado': FieldValue.increment(montoCobrado),
      'totalDeuda': FieldValue.increment(-abonoDeuda),
      'totalSaldoAFavor': FieldValue.increment(incrementoSaldo),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'diario.$key.recaudado': FieldValue.increment(montoCobrado),
      'diario.$key.cobros': FieldValue.increment(1),
    });
  }

  /// Revierte las estadísticas al eliminar/anular un cobro.
  Future<void> revertirCobro({
    required String municipalidadId,
    required num montoCobrado,
    required num abonoDeuda,
    required num incrementoSaldo,
    required DateTime fechaCobroOriginal,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(fechaCobroOriginal);

    await _doc(municipalidadId).update({
      'totalCobrado': FieldValue.increment(-montoCobrado),
      'totalDeuda': FieldValue.increment(abonoDeuda),
      'totalSaldoAFavor': FieldValue.increment(-incrementoSaldo),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'diario.$key.recaudado': FieldValue.increment(-montoCobrado),
      'diario.$key.cobros': FieldValue.increment(-1),
    });
  }

  /// Actualización al registrar o eliminar un local/mercado.
  /// Usa set(merge:true) porque el documento puede no existir aún.
  Future<void> actualizarConteo({
    required String municipalidadId,
    int deltaLocales = 0,
    int deltaMercados = 0,
    num deltaDeuda = 0,
  }) async {
    await _doc(municipalidadId).set({
      'cantidadLocales': FieldValue.increment(deltaLocales),
      'cantidadMercados': FieldValue.increment(deltaMercados),
      'totalDeuda': FieldValue.increment(deltaDeuda),
    }, SetOptions(merge: true));
  }

  /// Recalcula el mapa `diario` de hoy desde los cobros reales.
  Future<void> recalcularDiarioHoy(String municipalidadId) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));
    final key = DateFormat('yyyy-MM-dd').format(hoy);

    final snapshot = await _firestore
        .collection('cobros')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .get();

    num totalRecaudado = 0;
    int totalCobros = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final monto = (data['monto'] as num?) ?? 0;
      totalRecaudado += monto;
      totalCobros++;
    }

    // Escribir la estructura anidada correcta: diario -> key -> {recaudado, cobros}
    await _doc(municipalidadId).update({
      'diario.$key.recaudado': totalRecaudado,
      'diario.$key.cobros': totalCobros,
    });

    debugPrint('📊 Stats recalculados: $totalCobros cobros, L$totalRecaudado recaudado hoy');
  }

}
