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

  num get totalCobrado => cobros
      .where((c) => c.estado == 'cobrado' || c.estado == 'cobrado_saldo')
      .fold<num>(0, (s, c) => s + (c.monto ?? 0));

  num get totalPendiente => cobros
      .where((c) => c.estado == 'pendiente')
      .fold<num>(0, (s, c) => s + (c.saldoPendiente ?? 0));

  num get totalMora => locales.fold<num>(0, (s, l) => s + (l.deudaAcumulada ?? 0));

  num get totalSaldosAFavor => locales.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0));

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
