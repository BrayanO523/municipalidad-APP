import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../dashboard/presentation/widgets/metric_card.dart';
import '../viewmodels/reportes_notifier.dart';

class ResumenReportesScreen extends ConsumerWidget {
  const ResumenReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final state = ref.watch(reportesResumenProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref, state, filter),
            const SizedBox(height: 24),
            _buildPeriodSelector(context, ref, filter),
            const SizedBox(height: 24),
            _buildMetricsGrid(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, ReportesResumenState state, DashboardFilterState filter) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Resumen Operativo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Consolidado de métricas clave del sistema',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () async {
            final mercados = ref.read(mercadosProvider).value ?? [];
            final bytes = await ReportePdfGenerator.generarReporteResumenOperativo(
              totalCobrado: state.totalCobrado,
              totalPendiente: state.totalPendiente,
              totalMora: state.totalMora,
              totalFavor: state.totalSaldosAFavor,
              periodoLabel: filter.label,
              mercados: mercados,
              cobros: state.cobros,
              locales: state.locales,
            );

            if (kIsWeb) {
              await descargarPdfWeb(bytes, 'Resumen_Operativo_${filter.label}.pdf');
            } else {
              await Printing.layoutPdf(
                onLayout: (_) async => bytes,
                name: 'Resumen_Operativo_${filter.label}',
              );
            }
          },
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Exportar PDF'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context, WidgetRef ref, DashboardFilterState filter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodTab(
              label: 'Hoy',
              isSelected: filter.period == DashboardPeriod.hoy,
              onTap: () => ref.read(dashboardFilterProvider.notifier).setPeriod(DashboardPeriod.hoy),
            ),
            _PeriodTab(
              label: 'Semana',
              isSelected: filter.period == DashboardPeriod.semana,
              onTap: () => ref.read(dashboardFilterProvider.notifier).setPeriod(DashboardPeriod.semana),
            ),
            _PeriodTab(
              label: 'Mes',
              isSelected: filter.period == DashboardPeriod.mes,
              onTap: () => ref.read(dashboardFilterProvider.notifier).setPeriod(DashboardPeriod.mes),
            ),
            _PeriodTab(
              label: 'Año',
              isSelected: filter.period == DashboardPeriod.anio,
              onTap: () => ref.read(dashboardFilterProvider.notifier).setPeriod(DashboardPeriod.anio),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, ReportesResumenState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
        final spacing = 20.0;
        final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: MetricCard(
                title: 'Total Cobrado',
                value: DateFormatter.formatCurrency(state.totalCobrado),
                icon: Icons.payments_rounded,
                color: const Color(0xFF00D9A6),
                subtitle: 'Ingresos efectivos en caja',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: MetricCard(
                title: 'Pendientes',
                value: DateFormatter.formatCurrency(state.totalPendiente),
                icon: Icons.hourglass_empty_rounded,
                color: const Color(0xFF6C63FF),
                subtitle: 'Cobros no realizados en periodo',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: MetricCard(
                title: 'Total Mora',
                value: DateFormatter.formatCurrency(state.totalMora),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEE5A6F),
                subtitle: 'Deuda histórica acumulada',
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: MetricCard(
                title: 'Saldos a Favor',
                value: DateFormatter.formatCurrency(state.totalSaldosAFavor),
                icon: Icons.savings_rounded,
                color: const Color(0xFFFF9F43),
                subtitle: 'Créditos por pagos adelantados',
              ),
            ),
          ],
        );
      },
    );
  }

}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withAlpha(178),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}


