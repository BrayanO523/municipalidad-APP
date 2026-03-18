import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

class ReportesResumenState {
  final DashboardPeriod period;
  final List<Cobro> cobros;
  final List<Local> locales;
  final bool isLoading;

  ReportesResumenState({
    required this.period,
    required this.cobros,
    required this.locales,
    this.isLoading = false,
  });

  bool _esAnulado(Cobro cobro) {
    return (cobro.estado ?? '').toLowerCase() == 'anulado';
  }

  bool _esCobroConEfectivo(Cobro cobro) {
    final estado = (cobro.estado ?? '').toLowerCase();
    return (cobro.monto ?? 0) > 0 &&
        estado != 'cobrado_saldo' &&
        estado != 'anulado';
  }

  bool _esPendienteActivo(Cobro cobro) {
    final estado = (cobro.estado ?? '').toLowerCase();
    return estado == 'pendiente' || estado == 'abono_parcial';
  }

  /// Delta de saldo a favor por cobro.
  /// Positivo: genera credito. Negativo: consume credito.
  num _deltaSaldoFavor(Cobro cobro) {
    final monto = cobro.monto ?? 0;
    final abonoDeuda = cobro.montoAbonadoDeuda ?? 0;
    final pagoCuota = cobro.pagoACuota ?? 0;
    return monto - abonoDeuda - pagoCuota;
  }

  num get totalCobrado => cobros
      .where(_esCobroConEfectivo)
      .fold<num>(0, (s, c) => s + (c.monto ?? 0));

  num get totalPendiente => cobros
      .where(_esPendienteActivo)
      .fold<num>(0, (s, c) => s + (c.saldoPendiente ?? 0));

  /// Mora recuperada en el periodo seleccionado.
  num get totalMora => cobros.fold<num>(0, (s, c) {
        if (_esAnulado(c)) return s;
        return s + (c.montoMora ?? 0);
      });

  /// Credito generado en el periodo (solo deltas positivos).
  num get saldoFavorGeneradoPeriodo => cobros.fold<num>(0, (s, c) {
        if (_esAnulado(c)) return s;
        final delta = _deltaSaldoFavor(c);
        if (delta <= 0) return s;
        return s + delta;
      });

  /// Credito consumido en el periodo (magnitud positiva).
  num get saldoFavorConsumidoPeriodo => cobros.fold<num>(0, (s, c) {
        if (_esAnulado(c)) return s;
        final delta = _deltaSaldoFavor(c);
        if (delta >= 0) return s;
        return s + (-delta);
      });

  /// Saldo a favor vigente (foto actual) para los locales del cobrador.
  num get totalSaldosAFavor => locales.fold<num>(0, (s, l) {
        final saldo = l.saldoAFavor ?? 0;
        if (saldo <= 0) return s;
        return s + saldo;
      });

  // Alias para no romper la UI actual.
  num get totalSaldoFavorConsumido => saldoFavorConsumidoPeriodo;

  ReportesResumenState copyWith({
    DashboardPeriod? period,
    List<Cobro>? cobros,
    List<Local>? locales,
    bool? isLoading,
  }) {
    return ReportesResumenState(
      period: period ?? this.period,
      cobros: cobros ?? this.cobros,
      locales: locales ?? this.locales,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ReportesNotifier extends Notifier<ReportesResumenState> {
  @override
  ReportesResumenState build() {
    final filter = ref.watch(dashboardFilterProvider);
    final cobros = ref.watch(cobrosHoyProvider).value ?? [];
    final locales = ref.watch(localesProvider).value ?? [];

    return ReportesResumenState(
      period: filter.period,
      cobros: cobros,
      locales: locales,
    );
  }

  void cambiarPeriodo(DashboardPeriod nuevoPeriodo) {
    ref.read(dashboardFilterProvider.notifier).setPeriod(nuevoPeriodo);
  }
}

final reportesResumenProvider = NotifierProvider<ReportesNotifier, ReportesResumenState>(
  ReportesNotifier.new,
);
