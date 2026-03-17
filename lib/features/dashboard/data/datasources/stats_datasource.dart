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

  DocumentReference<Map<String, dynamic>> _doc(String municipalidadId, [String? mercadoId]) {
    final docId = mercadoId == null ? municipalidadId : '${municipalidadId}_m_$mercadoId';
    return _firestore.collection('stats').doc(docId);
  }

  Stream<StatsModel> streamStats(String municipalidadId, {String? mercadoId}) {
    return _doc(municipalidadId, mercadoId).snapshots().map((doc) {
      if (!doc.exists) return StatsModel();
      return StatsModel.fromJson(doc.data()!);
    });
  }

  /// Actualización atómica de estadísticas al registrar un cobro.
  /// Afecta tanto al global como al mercado específico.
  Future<void> actualizarAlCobrar({
    required String municipalidadId,
    required String mercadoId,
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
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
  }

  /// Revierte las estadísticas al eliminar/anular un cobro normal (Efectivo).
  Future<void> revertirCobro({
    required String municipalidadId,
    required String mercadoId,
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
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
  }

  /// Revierte las estadísticas al eliminar un cobro 'pendiente'.
  Future<void> revertirPendiente({
    required String municipalidadId,
    required String mercadoId,
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
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
  }

  /// Revierte las estadísticas al eliminar un cobro realizado con saldo a favor (sin efectivo).
  Future<void> revertirCobroSaldo({
    required String municipalidadId,
    required String mercadoId,
    required num montoConsumido,
    required DateTime fechaCobroOriginal,
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(fechaCobroOriginal);
    final data = {
      'totalSaldoAFavor': FieldValue.increment(montoConsumido),
      'diario.$key.recaudado': FieldValue.increment(-montoConsumido),
      'diario.$key.cobros': FieldValue.increment(-1),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
  }

  /// Registra un incremento en la deuda total (cuando un local no paga o paga parcial).
  Future<void> actualizarDeudaGenerada({
    required String municipalidadId,
    required String mercadoId,
    required num montoDeuda,
    WriteBatch? batch,
  }) async {
    final data = {
      'totalDeuda': FieldValue.increment(montoDeuda),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
  }

  /// Registra una reducción del saldo a favor global (cuando se usa para cubrir deuda).
  Future<void> actualizarConsumoSaldo({
    required String municipalidadId,
    required String mercadoId,
    required num montoConsumido,
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = {
      'totalSaldoAFavor': FieldValue.increment(-montoConsumido),
      'diario.$key.recaudado': FieldValue.increment(montoConsumido),
      'diario.$key.cobros': FieldValue.increment(1),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
  }

  /// Actualización al registrar o eliminar un local/mercado.
  Future<void> actualizarConteo({
    required String municipalidadId,
    String? mercadoId,
    int deltaLocales = 0,
    int deltaMercados = 0,
    num deltaDeuda = 0,
    num deltaSaldo = 0,
    num deltaCuotaDiaria = 0,
    WriteBatch? batch,
  }) async {
    final data = {
      'cantidadLocales': FieldValue.increment(deltaLocales),
      if (deltaMercados != 0) 'cantidadMercados': FieldValue.increment(deltaMercados),
      'totalDeuda': FieldValue.increment(deltaDeuda),
      'totalSaldoAFavor': FieldValue.increment(deltaSaldo),
      'totalCuotaDiaria': FieldValue.increment(deltaCuotaDiaria),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
      if (mercadoId != null) batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.set(_doc(municipalidadId), data, SetOptions(merge: true));
      if (mercadoId != null) {
        b.set(_doc(municipalidadId, mercadoId), data, SetOptions(merge: true));
      }
      await b.commit();
    }
  }

  /// Registra un ajuste manual en la deuda y opcionalmente en la recaudación de hoy.
  /// Útil para cuando el administrador borra o edita deudas a mano.
  Future<void> actualizarPorAjusteManual({
    required String municipalidadId,
    required String mercadoId,
    required num deltaDeuda,
    required num deltaRecaudado,
    WriteBatch? batch,
  }) async {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = {
      'totalDeuda': FieldValue.increment(deltaDeuda),
      'totalCobrado': FieldValue.increment(deltaRecaudado),
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };

    if (deltaRecaudado != 0) {
      data['diario.$key.recaudado'] = FieldValue.increment(deltaRecaudado);
      if (deltaRecaudado > 0) {
        data['diario.$key.cobros'] = FieldValue.increment(1);
      }
    }

    if (batch != null) {
      batch.update(_doc(municipalidadId), data);
      batch.update(_doc(municipalidadId, mercadoId), data);
    } else {
      final b = _firestore.batch();
      b.update(_doc(municipalidadId), data);
      b.update(_doc(municipalidadId, mercadoId), data);
      await b.commit();
    }
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
  /// 
  /// FASE 1: Corrige la 'deudaAcumulada' de los locales basándose en cobros pendientes.
  /// FASE 2: Reconstruye los contadores globales Y por mercado (Recaudación, Deuda, Saldo, etc).
  Future<void> recalcularTodo(String municipalidadId) async {
    debugPrint('🚀 Iniciando RECALCULO NUCLEAR de estadísticas para $municipalidadId...');
    
    // 1. Obtener todos los cobros para esta municipalidad
    final cobrosSnap = await _firestore
        .collection('cobros')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    // Estructuras para AGREGACIÓN GERAL y por MERCADO
    num totalCobradoGlobal = 0;
    Map<String, Map<String, dynamic>> diarioGlobal = {};
    
    // mercadoId -> totalCobrado
    final Map<String, num> cobradoPorMercado = {};
    // mercadoId -> mapa diario
    final Map<String, Map<String, Map<String, dynamic>>> diarioPorMercado = {};
    
    // localId -> suma de saldos pendientes
    final Map<String, num> deudaRealPorLocal = {};

    for (final doc in cobrosSnap.docs) {
      final d = doc.data();
      final monto = (d['monto'] as num?) ?? 0;
      final estado = d['estado'] as String?;
      final saldoPendiente = (d['saldoPendiente'] as num?) ?? 0;
      final localId = d['localId'] as String?;
      final mercadoId = d['mercadoId'] as String?;
      final Timestamp? fechaTs = d['fecha'] as Timestamp?;
      
      if (fechaTs == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(fechaTs.toDate());

      if (estado != 'anulado') {
        // Inicializar mapas si no existen
        diarioGlobal.putIfAbsent(key, () => {'recaudado': 0, 'cobros': 0});
        if (mercadoId != null) {
          diarioPorMercado.putIfAbsent(mercadoId, () => {});
          diarioPorMercado[mercadoId]!.putIfAbsent(key, () => {'recaudado': 0, 'cobros': 0});
        }

        if ((d['correlativo'] as num? ?? 0) > 0) {
          diarioGlobal[key]!['cobros'] += 1;
          if (mercadoId != null) diarioPorMercado[mercadoId]![key]!['cobros'] += 1;
          
          if (estado == 'cobrado' || estado == 'abono_parcial' || estado == 'cobrado_saldo') {
            totalCobradoGlobal += monto;
            diarioGlobal[key]!['recaudado'] += monto;
            
            if (mercadoId != null) {
              cobradoPorMercado[mercadoId] = (cobradoPorMercado[mercadoId] ?? 0) + monto;
              diarioPorMercado[mercadoId]![key]!['recaudado'] += monto;
            }
          }
        }

        if (localId != null && (estado == 'pendiente' || estado == 'abono_parcial')) {
          deudaRealPorLocal[localId] = (deudaRealPorLocal[localId] ?? 0) + saldoPendiente;
        }
      }
    }

    // 2. Obtener locales para totales reales actuales
    final localesSnap = await _firestore
        .collection('locales')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    num totalCuotaGlobal = 0;
    num totalDeudaGlobal = 0;
    num totalSaldoGlobal = 0;
    int localesActivosCount = 0;

    final Map<String, num> cuotaPorMercado = {};
    final Map<String, num> deudaPorMercado = {};
    final Map<String, num> saldoPorMercado = {};
    final Map<String, int> conteoLocalesPorMercado = {};

    WriteBatch batchLocales = _firestore.batch();
    int opsBatch = 0;
    int corregidos = 0;

    for (final doc in localesSnap.docs) {
      final d = doc.data();
      final localId = doc.id;
      final mercadoId = d['mercadoId'] as String?;
      final activo = (d['activo'] as bool?) ?? false;
      final deudaGuardada = (d['deudaAcumulada'] as num?) ?? 0;
      final saldoGuardado = (d['saldoAFavor'] as num?) ?? 0;
      final cuota = (d['cuotaDiaria'] as num?) ?? 0;

      final deudaReal = deudaRealPorLocal[localId] ?? 0;

      // Agregación Global
      totalDeudaGlobal += deudaReal;
      totalSaldoGlobal += saldoGuardado;
      if (activo) {
        localesActivosCount++;
        totalCuotaGlobal += cuota;
      }

      // Agregación por Mercado
      if (mercadoId != null) {
        deudaPorMercado[mercadoId] = (deudaPorMercado[mercadoId] ?? 0) + deudaReal;
        saldoPorMercado[mercadoId] = (saldoPorMercado[mercadoId] ?? 0) + saldoGuardado;
        if (activo) {
          conteoLocalesPorMercado[mercadoId] = (conteoLocalesPorMercado[mercadoId] ?? 0) + 1;
          cuotaPorMercado[mercadoId] = (cuotaPorMercado[mercadoId] ?? 0) + cuota;
        }
      }
      
      if (deudaGuardada != deudaReal) {
        batchLocales.update(doc.reference, {
          'deudaAcumulada': deudaReal,
          'actualizadoEn': FieldValue.serverTimestamp(),
          'parchadoEn': FieldValue.serverTimestamp(),
        });
        corregidos++;
        opsBatch++;
        if (opsBatch >= 450) {
          await batchLocales.commit();
          batchLocales = _firestore.batch();
          opsBatch = 0;
        }
      }
    }

    if (opsBatch > 0) await batchLocales.commit();
    debugPrint('🛠️ FASE 1: Se corrigieron $corregidos locales.');

    // 3. Mercados (conteo)
    final mercadosSnap = await _firestore
        .collection('mercados')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .get();

    // 4. GUARDAR STATS GLOBALES
    final globalModel = StatsModel(
      totalCobrado: totalCobradoGlobal,
      totalDeuda: totalDeudaGlobal,
      totalSaldoAFavor: totalSaldoGlobal,
      totalCuotaDiaria: totalCuotaGlobal,
      cantidadLocales: localesActivosCount,
      cantidadMercados: mercadosSnap.docs.length,
      diario: diarioGlobal,
      ultimaActualizacion: DateTime.now(),
    );
    await _doc(municipalidadId).set(globalModel.toJson());

    // 5. GUARDAR STATS POR MERCADO
    final bStats = _firestore.batch();
    int statsOps = 0;

    for (final doc in mercadosSnap.docs) {
      final mId = doc.id;
      final mModel = StatsModel(
        totalCobrado: cobradoPorMercado[mId] ?? 0,
        totalDeuda: deudaPorMercado[mId] ?? 0,
        totalSaldoAFavor: saldoPorMercado[mId] ?? 0,
        totalCuotaDiaria: cuotaPorMercado[mId] ?? 0,
        cantidadLocales: conteoLocalesPorMercado[mId] ?? 0,
        cantidadMercados: 0, // No aplica para mercado individual
        diario: diarioPorMercado[mId] ?? {},
        ultimaActualizacion: DateTime.now(),
      );
      bStats.set(_doc(municipalidadId, mId), mModel.toJson());
      statsOps++;
      if (statsOps >= 450) {
        await bStats.commit();
        // (En teoría no habrá +450 mercados, but safety first)
      }
    }
    if (statsOps > 0) await bStats.commit();
    
    debugPrint('✅ RECALCULO NUCLEAR completado. Stats globales y por mercado sincronizadas.');
  }

}
