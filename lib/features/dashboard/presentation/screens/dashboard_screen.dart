import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../widgets/metric_card.dart';
import '../widgets/recent_cobros_table.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/custom_date_range_picker.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final cobrosHoy = ref.watch(cobrosHoyProvider);
    final locales = ref.watch(localesProvider);
    final mercados = ref.watch(mercadosProvider);
    final filter = ref.watch(dashboardFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _DashboardHeader()),
                const SizedBox(width: 8),
                const _ParcharPagoACuotaButton(),
                const SizedBox(width: 8),
                const _ParcharCobrosButton(),
              ],
            ),
            const SizedBox(height: 24),

            // ── KPI cards — fila 1: recaudación del día ──────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1000
                    ? 4
                    : constraints.maxWidth > 600
                    ? 2
                    : 1;
                final cardW =
                    (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                    crossAxisCount;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardW,
                      child: cobrosHoy.when(
                        data: (cobros) {
                          final totalCobrado = cobros.fold<num>(
                            0,
                            (sum, c) => sum + (c.monto ?? 0),
                          );
                          return MetricCard(
                            title: 'Recaudación ${filter.label}',
                            value: DateFormatter.formatCurrency(totalCobrado),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF00D9A6),
                          );
                        },
                        loading: () => MetricCard(
                          title: 'Recaudación ${filter.label}',
                          value: '...',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF00D9A6),
                        ),
                        error: (_, __) => MetricCard(
                          title: 'Recaudación ${filter.label}',
                          value: 'Error',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF00D9A6),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: cobrosHoy.when(
                        data: (cobros) => MetricCard(
                          title: 'Cobros ${filter.label}',
                          value: '${cobros.length}',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF6C63FF),
                        ),
                        loading: () => MetricCard(
                          title: 'Cobros ${filter.label}',
                          value: '...',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF6C63FF),
                        ),
                        error: (_, __) => MetricCard(
                          title: 'Cobros ${filter.label}',
                          value: 'Error',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: mercados.when(
                        data: (m) => MetricCard(
                          title: 'Mercados Activos',
                          value: '${m.where((e) => e.activo == true).length}',
                          icon: Icons.store_rounded,
                          color: const Color(0xFFFF9F43),
                        ),
                        loading: () => const MetricCard(
                          title: 'Mercados Activos',
                          value: '...',
                          icon: Icons.store_rounded,
                          color: Color(0xFFFF9F43),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Mercados Activos',
                          value: 'Error',
                          icon: Icons.store_rounded,
                          color: Color(0xFFFF9F43),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: locales.when(
                        data: (l) => MetricCard(
                          title: 'Locales Registrados',
                          value: '${l.length}',
                          icon: Icons.storefront_rounded,
                          color: const Color(0xFFEE5A6F),
                        ),
                        loading: () => const MetricCard(
                          title: 'Locales Registrados',
                          value: '...',
                          icon: Icons.storefront_rounded,
                          color: Color(0xFFEE5A6F),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Locales Registrados',
                          value: 'Error',
                          icon: Icons.storefront_rounded,
                          color: Color(0xFFEE5A6F),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── KPI cards — fila 2: deudas y saldo a favor ───────────────────
            locales.when(
              data: (ls) {
                final activos = ls.where((l) => l.activo == true).toList();
                final deudaTotal = activos.fold<num>(
                  0,
                  (sum, l) => sum + (l.deudaAcumulada ?? 0),
                );
                final saldoAFavorTotal = activos.fold<num>(
                  0,
                  (sum, l) => sum + (l.saldoAFavor ?? 0),
                );
                final localesConDeuda = activos
                    .where((l) => (l.deudaAcumulada ?? 0) > 0)
                    .length;
                final localesConCredito = activos
                    .where((l) => (l.saldoAFavor ?? 0) > 0)
                    .length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
                    final cardW = (constraints.maxWidth - 16) / crossAxisCount;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Deuda Acumulada',
                            value: DateFormatter.formatCurrency(deudaTotal),
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEE5A6F),
                            subtitle:
                                '$localesConDeuda local${localesConDeuda == 1 ? '' : 'es'} con deuda',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Saldo a Favor',
                            value: DateFormatter.formatCurrency(
                              saldoAFavorTotal,
                            ),
                            icon: Icons.savings_rounded,
                            color: const Color(0xFF00D9A6),
                            subtitle:
                                '$localesConCredito local${localesConCredito == 1 ? '' : 'es'} con crédito',
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // ── Gráficos ─────────────────────────────────────────────────────
            DashboardChartsWidget(
              cobrosHoy: cobrosHoy.value ?? [],
              locales: locales.value ?? [],
              mercados: mercados.value ?? [],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // ── Cobros de la Fecha ───────────────────────────────────────────
            Builder(
              builder: (context) {
                final titulo = filter.period == DashboardPeriod.hoy
                    ? 'Cobros de Hoy'
                    : 'Cobros del Periodo (${filter.label})';

                return Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const RecentCobrosTable(),
          ],
        ),
      ),
    );
  }
}

// ── Widgets de apoyo ──────────────────────────────────────────────────────────

class _DashboardHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final range = await showDialog<DateTimeRange>(
                      context: context,
                      builder: (context) =>
                          CustomDateRangePicker(initialRange: filter.range),
                    );

                    if (range != null) {
                      // Si seleccionamos un rango manualmente, forzamos a que el periodo sea personalizado
                      ref
                          .read(dashboardFilterProvider.notifier)
                          .setPeriod(DashboardPeriod.personalizado);
                      ref
                          .read(dashboardFilterProvider.notifier)
                          .setCustomRange(range);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 2.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          filter.range.start != filter.range.end
                              ? '${DateFormatter.formatDate(filter.range.start)} - ${DateFormatter.formatDate(filter.range.end)}'
                              : DateFormatter.formatDate(filter.range.start),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white54,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  filter.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            _PeriodSelector(),
          ],
        ),
      ],
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);

    return Wrap(
      spacing: 8,
      children: [
        _PeriodChip(
          label: 'Hoy',
          selected: filter.period == DashboardPeriod.hoy,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.hoy),
        ),
        _PeriodChip(
          label: 'Semana',
          selected: filter.period == DashboardPeriod.semana,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.semana),
        ),
        _PeriodChip(
          label: 'Mes',
          selected: filter.period == DashboardPeriod.mes,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.mes),
        ),
        _PeriodChip(
          label: 'Personalizado',
          selected: filter.period == DashboardPeriod.personalizado,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.personalizado),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white54,
        fontSize: 12,
      ),
      selectedColor: const Color(0xFF00D9A6).withValues(alpha: 0.3),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      showCheckmark: false,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _ParcharCobrosButton extends ConsumerStatefulWidget {
  const _ParcharCobrosButton();

  @override
  ConsumerState<_ParcharCobrosButton> createState() =>
      _ParcharCobrosButtonState();
}

class _ParcharCobrosButtonState extends ConsumerState<_ParcharCobrosButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.build_circle_rounded, size: 18),
      label: const Text('Parchar Cobros'),
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                final ds = ref.read(cobroDatasourceProvider);
                final patched = await ds.parcharCobrosHuerfanos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Migración completada. $patched cobros huérfanos arreglados.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
    );
  }
}

class _ParcharPagoACuotaButton extends ConsumerStatefulWidget {
  const _ParcharPagoACuotaButton();

  @override
  ConsumerState<_ParcharPagoACuotaButton> createState() =>
      _ParcharPagoACuotaButtonState();
}

class _ParcharPagoACuotaButtonState
    extends ConsumerState<_ParcharPagoACuotaButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.auto_fix_high_rounded, size: 18),
      label: const Text('Validar Pago Cuota'),
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                final ds = ref.read(cobroDatasourceProvider);
                final patched = await ds.parcharPagoACuota();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Validación completada. $patched registros corregidos.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
    );
  }
}
