import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../domain/entities/usuario.dart';
import '../../../dashboard/presentation/widgets/custom_date_range_picker.dart';

/// Pantalla de historial de desempeño de un cobrador.
/// Muestra KPIs de recaudación, un gráfico de ingresos diarios y el listado de transacciones.
class CobradorHistorialScreen extends ConsumerWidget {
  final Usuario cobrador;

  const CobradorHistorialScreen({super.key, required this.cobrador});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(cobradorHistorialRangoProvider);
    final cobrosAsync = ref.watch(
      cobradorCobrosStreamProvider(cobrador.id ?? ''),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cobrador.nombre ?? 'Cobrador',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              'Código: ${cobrador.codigoCobrador ?? "S/C"}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.54),
              ),
            ),
          ],
        ),
      ),
      body: cobrosAsync.when(
        data: (cobros) {
          // Filtrar cobros reales para KPIs (evitar registros de regularización sin monto)
          final cobrosReales = cobros.where((c) => (c.monto ?? 0) > 0).toList();
          final totalRecaudado = cobrosReales.fold<num>(
            0,
            (sum, c) => sum + (c.monto ?? 0),
          );
          final totalBoletas = cobros
              .where((c) => (c.correlativo ?? 0) > 0)
              .length;

          // Preparar datos para el gráfico (últimos 7 días con actividad)
          final Map<DateTime, double> revenueByDate = {};
          for (var c in cobrosReales) {
            if (c.fecha == null) continue;
            final dateOnly = DateTime(
              c.fecha!.year,
              c.fecha!.month,
              c.fecha!.day,
            );
            revenueByDate[dateOnly] =
                (revenueByDate[dateOnly] ?? 0) + (c.monto?.toDouble() ?? 0);
          }

          final sortedDates = revenueByDate.keys.toList()..sort();
          final recentDates = sortedDates.length > 7
              ? sortedDates.sublist(sortedDates.length - 7)
              : sortedDates;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CollectorKpiRow(
                        totalRecaudado: totalRecaudado,
                        totalBoletas: totalBoletas,
                        infoColor: semantic.info,
                        successColor: semantic.success,
                      ),
                      const SizedBox(height: 24),
                      _DateRangeFilter(range: range),
                      const SizedBox(height: 24),
                      if (recentDates.isNotEmpty) ...[
                        _CollectorRevenueChart(
                          revenueByDate: revenueByDate,
                          dates: recentDates,
                        ),
                        const SizedBox(height: 24),
                      ],
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Historial Reciente',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${cobros.length} registros',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (cobros.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No hay cobros registrados')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CobroItem(cobro: cobros[index]),
                      childCount: cobros.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DateRangeFilter extends ConsumerWidget {
  final DateTimeRange? range;

  const _DateRangeFilter({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = range == null
        ? 'Últimos 200 registros'
        : '${DateFormat('dd/MM/yyyy').format(range!.start)} - ${DateFormat('dd/MM/yyyy').format(range!.end)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periodo mostrado',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.54),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (range != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                ref
                    .read(cobradorHistorialRangoProvider.notifier)
                    .setRango(null);
              },
              tooltip: 'Limpiar filtro',
            ),
          ElevatedButton(
            onPressed: () async {
              final newRange = await showDialog<DateTimeRange>(
                context: context,
                builder: (context) => CustomDateRangePicker(
                  initialRange:
                      range ??
                      DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                ),
              );
              if (newRange != null) {
                ref
                    .read(cobradorHistorialRangoProvider.notifier)
                    .setRango(newRange);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: colorScheme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _CollectorKpiRow extends StatelessWidget {
  final num totalRecaudado;
  final int totalBoletas;
  final Color infoColor;
  final Color successColor;

  const _CollectorKpiRow({
    required this.totalRecaudado,
    required this.totalBoletas,
    required this.infoColor,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Total Recaudado',
            value: DateFormatter.formatCurrency(totalRecaudado),
            icon: Icons.account_balance_wallet_rounded,
            color: infoColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Boletas Emitidas',
            value: '$totalBoletas',
            icon: Icons.confirmation_number_rounded,
            color: successColor,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorRevenueChart extends StatelessWidget {
  final Map<DateTime, double> revenueByDate;
  final List<DateTime> dates;

  const _CollectorRevenueChart({
    required this.revenueByDate,
    required this.dates,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    double maxRevenue = 0;
    for (var d in dates) {
      final rev = revenueByDate[d] ?? 0;
      if (rev > maxRevenue) maxRevenue = rev;
    }
    maxRevenue = maxRevenue == 0 ? 100 : maxRevenue * 1.2;

    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresos Diarios (Recientes)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRevenue,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = DateFormat('dd/MM').format(dates[group.x]);
                      return BarTooltipItem(
                        '$label\n',
                        TextStyle(
                          color: colorScheme.onInverseSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: DateFormatter.formatCurrency(rod.toY),
                            style: TextStyle(
                              color: colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dates.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('dd/MM').format(dates[index]),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.outline.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(dates.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: revenueByDate[dates[index]] ?? 0,
                        color: semantic.info,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CobroItem extends StatelessWidget {
  final Cobro cobro;

  const _CobroItem({required this.cobro});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final isNegative =
        (cobro.monto ?? 0) < 0; // Por si hay reversiones manuales o errores

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (cobro.correlativo ?? 0) > 0
                  ? semantic.success.withValues(alpha: 0.1)
                  : semantic.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              (cobro.correlativo ?? 0) > 0
                  ? Icons.receipt_long_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: (cobro.correlativo ?? 0) > 0
                  ? semantic.success
                  : semantic.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final locales = ref.watch(localesProvider).value ?? [];
                    String? resolvedName;

                    if (cobro.localId != null) {
                      final local = locales.cast<Local?>().firstWhere(
                        (l) => l?.id == cobro.localId,
                        orElse: () => null,
                      );
                      resolvedName = local?.nombreSocial;
                    }

                    return Text(
                      resolvedName ?? cobro.localId ?? 'Local Desconocido',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                Text(
                  'Boleta: ${cobro.numeroBoleta ?? "S/B"} • ${cobro.fecha != null ? DateFormatter.formatDateTime(cobro.fecha!) : "-"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormatter.formatCurrency(cobro.monto ?? 0),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isNegative ? semantic.danger : colorScheme.onSurface,
                ),
              ),
              Text(
                cobro.estado?.toUpperCase() ?? '',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _getEstadoColor(context, cobro.estado),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(BuildContext context, String? estado) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    switch (estado) {
      case 'cobrado':
        return semantic.success;
      case 'abono_parcial':
        return semantic.warning;
      case 'adelantado':
        return semantic.info;
      case 'pendiente':
        return semantic.danger;
      default:
        return colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }
}
