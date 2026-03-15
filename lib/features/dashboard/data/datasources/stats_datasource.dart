import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class StatsModel {
  final num totalCobrado;
  final num totalDeuda;
  final num totalSaldoAFavor;
  final num totalCuotaDiaria;
  final int cantidadLocales;
  final int cantidadMercados;
  final DateTime? ultimaActualizacion;
  
  /// Fecha a partir de la cual la app considera operaciones válidas.
  /// Cualquier cobro o deuda anterior a esta fecha es ignorado (Soft-Reset).
  final DateTime? fechaInicioOperaciones;
  
  // Mapa agrupado por "yyyy-MM-dd"
  final Map<String, dynamic> diario;

  StatsModel({
    this.totalCobrado = 0,
    this.totalDeuda = 0,
    this.totalSaldoAFavor = 0,
    this.totalCuotaDiaria = 0,
    this.cantidadLocales = 0,
    this.cantidadMercados = 0,
    this.ultimaActualizacion,
    this.fechaInicioOperaciones,
    this.diario = const {},
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      totalCobrado: (json['totalCobrado'] as num?) ?? 0,
      totalDeuda: (json['totalDeuda'] as num?) ?? 0,
      totalSaldoAFavor: (json['totalSaldoAFavor'] as num?) ?? 0,
      totalCuotaDiaria: (json['totalCuotaDiaria'] as num?) ?? 0,
      cantidadLocales: (json['cantidadLocales'] as num?)?.toInt() ?? 0,
      cantidadMercados: (json['cantidadMercados'] as num?)?.toInt() ?? 0,
      ultimaActualizacion: (json['ultimaActualizacion'] as Timestamp?)?.toDate(),
      fechaInicioOperaciones: (json['fechaInicioOperaciones'] as Timestamp?)?.toDate(),
      diario: json['diario'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'totalCobrado': totalCobrado,
    'totalDeuda': totalDeuda,
    'totalSaldoAFavor': totalSaldoAFavor,
    'totalCuotaDiaria': totalCuotaDiaria,
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

  /// Cuánto falta por cobrar hoy (cuota diaria esperada – recaudado hoy).
  /// Nunca negativo: si se cobró más de lo esperado, retorna 0.
  num get pendienteCobroHoy {
    final pendiente = totalCuotaDiaria - recaudacionHoy;
    return pendiente > 0 ? pendiente : 0;
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
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = {
      'totalCobrado': FieldValue.increment(montoCobrado),
      'totalDeuda': FieldValue.increment(-abonoDeuda),
      'totalSaldoAFavor': FieldValue.increment(incrementoSaldo),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'diario.$key.recaudado': FieldValue.increment(montoCobrado),
      'diario.$key.cobros': FieldValue.increment(1),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
    } else {
      await _doc(municipalidadId).update(data);
    }
  }

  /// Revierte las estadísticas al eliminar/anular un cobro normal (Efectivo).
  Future<void> revertirCobro({
    required String municipalidadId,
    required num montoCobrado,
    required num abonoDeuda,
    required num incrementoSaldo,
    required DateTime fechaCobroOriginal,
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(fechaCobroOriginal);
    final data = {
      'totalCobrado': FieldValue.increment(-montoCobrado),
      'totalDeuda': FieldValue.increment(abonoDeuda),
      'totalSaldoAFavor': FieldValue.increment(-incrementoSaldo),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
      'diario.$key.recaudado': FieldValue.increment(-montoCobrado),
      'diario.$key.cobros': FieldValue.increment(-1),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
    } else {
      await _doc(municipalidadId).update(data);
    }
  }

  /// Revierte las estadísticas al eliminar un cobro 'pendiente'.
  Future<void> revertirPendiente({
    required String municipalidadId,
    required num saldoPendiente,
    required DateTime fechaCobroOriginal,
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(fechaCobroOriginal);
    final data = {
      'totalDeuda': FieldValue.increment(-saldoPendiente),
      'diario.$key.cobros': FieldValue.increment(-1),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
    } else {
      await _doc(municipalidadId).update(data);
    }
  }

  /// Revierte las estadísticas al eliminar un cobro realizado con saldo a favor (sin efectivo).
  Future<void> revertirCobroSaldo({
    required String municipalidadId,
    required num montoConsumido,
    required DateTime fechaCobroOriginal,
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(fechaCobroOriginal);
    final data = {
      'totalSaldoAFavor': FieldValue.increment(montoConsumido),
      'diario.$key.cobros': FieldValue.increment(-1),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
    } else {
      await _doc(municipalidadId).update(data);
    }
  }

  /// Registra un incremento en la deuda total (cuando un local no paga o paga parcial).
  Future<void> actualizarDeudaGenerada({
    required String municipalidadId,
    required num montoDeuda,
    WriteBatch? batch,
  }) async {
    final data = {
      'totalDeuda': FieldValue.increment(montoDeuda),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
    } else {
      await _doc(municipalidadId).update(data);
    }
  }

  /// Registra una reducción del saldo a favor global (cuando se usa para cubrir deuda).
  Future<void> actualizarConsumoSaldo({
    required String municipalidadId,
    required num montoConsumido,
    WriteBatch? batch,
  }) async {
    final data = {
      'totalSaldoAFavor': FieldValue.increment(-montoConsumido),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
    } else {
      await _doc(municipalidadId).update(data);
    }
  }

  /// Actualización al registrar o eliminar un local/mercado.
  /// Usa set(merge:true) porque el documento puede no existir aún.
  /// [deltaCuotaDiaria] suma/resta la cuota diaria del local creado/eliminado.
  Future<void> actualizarConteo({
    required String municipalidadId,
    int deltaLocales = 0,
    int deltaMercados = 0,
    num deltaDeuda = 0,
    num deltaCuotaDiaria = 0,
  }) async {
    await _doc(municipalidadId).set({
      'cantidadLocales': FieldValue.increment(deltaLocales),
      'cantidadMercados': FieldValue.increment(deltaMercados),
      'totalDeuda': FieldValue.increment(deltaDeuda),
      'totalCuotaDiaria': FieldValue.increment(deltaCuotaDiaria),
    }, SetOptions(merge: true));
  }

  /// Recalcula el mapa `diario` de hoy y la cuota diaria total desde los datos reales.
  Future<void> recalcularDiarioHoy(String municipalidadId) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));
    final key = DateFormat('yyyy-MM-dd').format(hoy);

    // 1. Cobros de hoy (ya estaba)
    final cobrosSnap = await _firestore
        .collection('cobros')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .get();

    num totalRecaudado = 0;
    int totalCobros = 0;

    for (final doc in cobrosSnap.docs) {
      final data = doc.data();
      final monto = (data['monto'] as num?) ?? 0;
      totalRecaudado += monto;
      totalCobros++;
    }

    // 2. Locales activos: suma de cuotaDiaria, deudaAcumulada y saldoAFavor
    //    Aprovechamos UNA SOLA query para extraer 3 métricas (costo 0 lecturas extra).
    final localesSnap = await _firestore
        .collection('locales')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('activo', isEqualTo: true)
        .get();

    num totalCuota = 0;
    num totalDeuda = 0;
    num totalSaldo = 0;
    for (final doc in localesSnap.docs) {
      final d = doc.data();
      totalCuota += (d['cuotaDiaria'] as num?) ?? 0;
      totalDeuda += (d['deudaAcumulada'] as num?) ?? 0;
      totalSaldo += (d['saldoAFavor'] as num?) ?? 0;
    }

    // 3. Escribir todo de una vez (diario + totales reales recalculados)
    // NOTA: Usamos update para el mapa de hoy, pero no corrige históricos.
    await _doc(municipalidadId).update({
      'diario.$key.recaudado': totalRecaudado,
      'diario.$key.cobros': totalCobros,
      'totalCuotaDiaria': totalCuota,
      'totalDeuda': totalDeuda,
      'totalSaldoAFavor': totalSaldo,
      'cantidadLocales': localesSnap.docs.length,
    });

    debugPrint('📊 Stats del día recalculados para $key');
  }

  /// RECALCULO NUCLEAR: Escanea TODOS los cobros y locales para reconstruir stats desde cero.
  /// Útil para reparar corrupción de datos o campos raíz duplicados.
  Future<void> recalcularTodo(String municipalidadId) async {
    debugPrint('🚀 Iniciando RECALCULO NUCLEAR de estadísticas para $municipalidadId...');
    
    // 1. Obtener todos los cobros (sin filtrar por fecha)
    final cobrosSnap = await _firestore
        .collection('cobros')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    num totalCobrado = 0;
    Map<String, Map<String, dynamic>> nuevoDiario = {};

    for (final doc in cobrosSnap.docs) {
      final d = doc.data();
      final monto = (d['monto'] as num?) ?? 0;
      final estado = d['estado'] as String?;
      final Timestamp? fechaTs = d['fecha'] as Timestamp?;
      
      if (fechaTs == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(fechaTs.toDate());

      // Solo contar si no está anulado
      if (estado != 'anulado') {
        nuevoDiario.putIfAbsent(key, () => {'recaudado': 0, 'cobros': 0});
        nuevoDiario[key]!['cobros'] += 1;
        
        // El recaudado solo viene de cobros normales (cash) o abonos parciales (cash)
        if (estado == 'cobrado' || estado == 'abono_parcial') {
          totalCobrado += monto;
          nuevoDiario[key]!['recaudado'] += monto;
        }
      }
    }

    // 2. Obtener locales para totales reales actuales de deuda y saldo
    final localesSnap = await _firestore
        .collection('locales')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    num totalCuota = 0;
    num totalDeuda = 0;
    num totalSaldo = 0;
    int localesActivos = 0;

    for (final doc in localesSnap.docs) {
      final d = doc.data();
      final activo = (d['activo'] as bool?) ?? false;
      if (activo) {
        localesActivos++;
        totalCuota += (d['cuotaDiaria'] as num?) ?? 0;
      }
      totalDeuda += (d['deudaAcumulada'] as num?) ?? 0;
      totalSaldo += (d['saldoAFavor'] as num?) ?? 0;
    }

    // 3. Mercados
    final mercadosSnap = await _firestore
        .collection('mercados')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    // 4. SOBREESCRIBIR el documento (USA set() sin merge para limpiar campos basura/duplicados)
    final StatsModel model = StatsModel(
      totalCobrado: totalCobrado,
      totalDeuda: totalDeuda,
      totalSaldoAFavor: totalSaldo,
      totalCuotaDiaria: totalCuota,
      cantidadLocales: localesActivos,
      cantidadMercados: mercadosSnap.docs.length,
      diario: nuevoDiario,
      ultimaActualizacion: DateTime.now(),
    );

    await _doc(municipalidadId).set(model.toJson());
    
    debugPrint('✅ RECALCULO NUCLEAR completado con éxito.');
  }

}
