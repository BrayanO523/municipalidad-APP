import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/repositories/cobro_repository.dart';
import '../../../locales/domain/entities/local.dart';

final cobroViewModelProvider = AsyncNotifierProvider<CobroViewModel, void>(() {
  return CobroViewModel();
});

class CobroViewModel extends AsyncNotifier<void> {
  late final CobroRepository _cobroRepository;

  @override
  FutureOr<void> build() {
    _cobroRepository = ref.read(cobroRepositoryProvider);
  }

  /// Realiza todo el flujo de registro de un cobro garantizando MVVM
  /// y usando el almacenamiento Offline NoSQL (Hive).
  /// Retorna la boleta y las fechas históricas saldadas (FIFO).
  Future<({String? numeroBoleta, List<DateTime> fechasSaldadas})> registrarPago({
    required Cobro cobro,
    required String localId,
    required num montoAbonadoDeuda,
    required num incrementoSaldoFavor,
    DateTime? fechaReferenciaMora,
  }) async {
    try {
      state = const AsyncValue.loading();

      // 1. Ejecutar registro de cobro (con FIFO).
      // NOTA: registrarCobroCompleto ya actualiza los balances del local de forma atómica en Firestore.
      final resultado = await _cobroRepository.registrarCobroCompleto(
        cobro,
        localId,
        montoAbonadoDeuda: montoAbonadoDeuda,
        incrementoSaldoFavor: incrementoSaldoFavor,
        fechaReferenciaMora: fechaReferenciaMora,
      );

      state = const AsyncValue.data(null);
      return (numeroBoleta: resultado.numeroBoleta, fechasSaldadas: resultado.fechasSaldadas);
    } catch (e, st) {
      debugPrint('🚨 ERROR CRÍTICO EN registrarPago: $e');
      debugPrint('STACKTRACE: $st');
      state = AsyncValue.error(e, st);
      return (numeroBoleta: null, fechasSaldadas: <DateTime>[]);
    }
  }

  Future<bool> eliminarCobro(Cobro cobro) async {
    try {
      state = const AsyncValue.loading();
      await _cobroRepository.eliminarCobro(cobro);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Registra deuda masiva para un local en un rango de fechas asignando
  /// por defecto el estado 'pendiente'.
  Future<int> agregarDeudaMasiva({
    required Local local,
    required DateTimeRange range,
    required String? cobradorId,
  }) async {
    try {
      state = const AsyncValue.loading();
      final creados = await _cobroRepository.registrarDeudaPorRango(
        local: local,
        start: range.start,
        end: range.end,
        cobradorId: cobradorId,
      );
      state = const AsyncValue.data(null);
      return creados;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }
}
