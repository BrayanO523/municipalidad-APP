import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../mercados/domain/entities/mercado.dart';

class RecaudacionBarChart extends StatelessWidget {
  final List<Cobro> cobrosHoy;
  final List<Mercado> mercados;

  const RecaudacionBarChart({
    super.key,
    required this.cobrosHoy,
    required this.mercados,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupar cobros por mercadoId (solo cobrados/abono_parcial)
    final mapMonto = <String, double>{};
    for (final c in cobrosHoy) {
      if (c.mercadoId == null || c.estado == 'pendiente') continue;
      mapMonto[c.mercadoId!] =
          (mapMonto[c.mercadoId!] ?? 0) + (c.monto?.toDouble() ?? 0);
    }

    List<BarChartGroupData> barGroups = [];
    int x = 0;
    double maxY = 0;
    final List<String> xAxisTitles = [];

    for (var m in mercados) {
      if (m.activo == false) continue;
      final monto = mapMonto[m.id] ?? 0;
      if (monto > maxY) maxY = monto;

      final mercadoName = m.nombre ?? 'M$x';
      final shortName = mercadoName.length > 12
          ? '${mercadoName.substring(0, 12)}...'
          : mercadoName;

      barGroups.add(
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: monto,
              color: const Color(0xFF6C63FF),
              width: 24,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY == 0 ? 100 : maxY * 1.25,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
      xAxisTitles.add(shortName);
      x++;
    }

    maxY = maxY == 0 ? 100 : maxY * 1.25;

    return Card(
      elevation: 0,
      color: const Color(0xFF232537),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recaudación por Mercado',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (mapMonto.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 40,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sin recaudación hoy',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RepaintBoundary(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barGroups: barGroups,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                                '${xAxisTitles[group.x]}\n${DateFormatter.formatCurrency(rod.toY)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= xAxisTitles.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  xAxisTitles[idx],
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value == maxY) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                DateFormatter.formatCurrency(value),
                                style: const TextStyle(
                                  color: Colors.white38,
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
                        horizontalInterval: maxY > 0 ? (maxY / 4) : 25,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Colors.white10,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
