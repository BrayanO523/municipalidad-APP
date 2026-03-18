import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';

/// Gráfico agrupado Corriente vs Mora para el periodo filtrado.
/// En lugar de mostrar diario, muestra el total del periodo actual (hoy/semana/mes).
class MoraCorrienteChart extends ConsumerWidget {
  final DashboardPeriod period;
  final DateTimeRange range;

  const MoraCorrienteChart({
    super.key,
    required this.period,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final rt = ref.watch(dashboardRealTimeStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) {
        // Totales del periodo
        final totalRecaudadoRaw = _totalPeriodo(
          stats,
          period,
          range,
          field: 'recaudado',
        );
        final totalRecaudado = totalRecaudadoRaw > 0
            ? totalRecaudadoRaw
            : (rt.recaudadoPeriodo.toDouble());
        final moraPeriodo = _totalPeriodo(stats, period, range, field: 'mora');
        final moraAcumulada = stats.totalMoraRecuperada.toDouble();
        final moraRt = rt.totalMoraRecuperada.toDouble();
        final totalMora = moraPeriodo > 0 ? moraPeriodo : moraAcumulada;
        final totalMoraFinal = totalMora > 0 ? totalMora : moraRt;
        final corriente = (totalRecaudado - totalMoraFinal).clamp(
          0.0,
          double.infinity,
        );

        if (corriente <= 0 && totalMoraFinal <= 0) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Corriente vs Mora (totales del periodo)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Expanded(
                    child: Center(child: Text('Sin datos del periodo')),
                  ),
                ],
              ),
            ),
          );
        }

        final maxY = (corriente + totalMoraFinal) * 1.25;

        final barGroups = [
          BarChartGroupData(
            x: 0,
            groupVertically: false,
            barRods: [
              BarChartRodData(
                toY: corriente,
                color: const Color(0xFF00D9A6),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
              BarChartRodData(
                toY: totalMoraFinal,
                color: const Color(0xFFFF9F43),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          ),
        ];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + leyenda
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Corriente vs Mora (totales ${_periodLabel(period)})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _LegendChip(
                      color: const Color(0xFF00D9A6),
                      label: 'Corriente',
                    ),
                    const SizedBox(width: 8),
                    _LegendChip(color: const Color(0xFFFF9F43), label: 'Mora'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      groupsSpace: 12,
                      barGroups: barGroups,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final label = rodIndex == 0 ? 'Corriente' : 'Mora';
                            return BarTooltipItem(
                              '$label: ${DateFormatter.formatCurrency(rod.toY)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: const SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 56,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value == maxY) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                DateFormatter.formatCurrency(value),
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 9,
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
                        horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: colorScheme.onSurface.withValues(alpha: 0.08),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

double _totalPeriodo(
  stats,
  DashboardPeriod period,
  DateTimeRange range, {
  required String field,
}) {
  // StatsModel expected: diario map with keys yyyy-MM-dd and fields 'recaudado', 'mora'
  final now = DateTime.now();

  bool include(DateTime date) {
    switch (period) {
      case DashboardPeriod.hoy:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case DashboardPeriod.semana:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return !date.isBefore(
              DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
            ) &&
            !date.isAfter(
              DateTime(
                endOfWeek.year,
                endOfWeek.month,
                endOfWeek.day,
                23,
                59,
                59,
                999,
              ),
            );
      case DashboardPeriod.mes:
        return date.year == now.year && date.month == now.month;
      case DashboardPeriod.anio:
        return date.year == now.year;
      case DashboardPeriod.personalizado:
        final rangeStart = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final rangeEnd = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        );
        return !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
    }
  }

  num total = 0;
  stats.diario.forEach((key, value) {
    if (value is! Map) return;
    final date = DateTime.tryParse(key);
    if (date == null) return;
    if (!include(date)) return;
    total += (value[field] as num?) ?? 0;
  });

  return total.toDouble();
}

String _periodLabel(DashboardPeriod period) {
  switch (period) {
    case DashboardPeriod.hoy:
      return 'hoy';
    case DashboardPeriod.semana:
      return 'semana';
    case DashboardPeriod.mes:
      return 'mes';
    case DashboardPeriod.anio:
      return 'año';
    case DashboardPeriod.personalizado:
      return 'periodo';
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
