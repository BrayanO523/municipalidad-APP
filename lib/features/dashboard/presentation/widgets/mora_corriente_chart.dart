import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';

/// Gráfico de barras agrupadas que muestra la recaudación corriente vs mora
/// recuperada por los últimos [dias] días usando el mapa `diario` del StatsModel.
class MoraCorrienteChart extends ConsumerWidget {
  final int dias;

  const MoraCorrienteChart({super.key, this.dias = 7});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) {
        // Construir lista de los últimos [dias] días
        final now = DateTime.now();
        final fmt = DateFormat('yyyy-MM-dd');
        final fmtLabel = DateFormat('dd/MM');

        // Generar lista (oldest → newest)
        final List<DateTime> fechas = List.generate(
          dias,
          (i) => now.subtract(Duration(days: dias - 1 - i)),
        );

        final List<String> labels = fechas.map((d) => fmtLabel.format(d)).toList();
        final List<double> corrienteValues = [];
        final List<double> moraValues = [];

        for (final fecha in fechas) {
          final key = fmt.format(fecha);
          final obj = stats.diario[key];
          final recaudado = (obj is Map ? (obj['recaudado'] as num?) ?? 0 : 0).toDouble();
          final mora = (obj is Map ? (obj['mora'] as num?) ?? 0 : 0).toDouble();
          final corriente = (recaudado - mora).clamp(0.0, double.infinity);
          corrienteValues.add(corriente);
          moraValues.add(mora);
        }

        final bool hayMora = moraValues.any((v) => v > 0);
        final bool hayCorriente = corrienteValues.any((v) => v > 0);

        if (!hayMora && !hayCorriente) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Corriente vs Mora (últimos $dias días)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Sin datos del periodo'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        double maxY = 0;
        for (int i = 0; i < dias; i++) {
          final total = corrienteValues[i] + moraValues[i];
          if (total > maxY) maxY = total;
        }
        maxY = maxY == 0 ? 100 : maxY * 1.25;

        final barGroups = List.generate(dias, (i) {
          return BarChartGroupData(
            x: i,
            groupVertically: false,
            barRods: [
              // Corriente (azul-verde)
              BarChartRodData(
                toY: corrienteValues[i],
                color: const Color(0xFF00D9A6),
                width: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              // Mora (naranja)
              BarChartRodData(
                toY: moraValues[i],
                color: const Color(0xFFFF9F43),
                width: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        });

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        'Corriente vs Mora (últimos $dias días)',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _LegendChip(color: const Color(0xFF00D9A6), label: 'Corriente'),
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
                              '${labels[group.x]}\n$label: ${DateFormatter.formatCurrency(rod.toY)}',
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
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[idx],
                                  style: TextStyle(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
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
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}
