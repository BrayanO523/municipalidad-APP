import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

class CobrosStatusPieChart extends StatelessWidget {
  final List<Cobro> cobrosHoy;
  final List<Local> locales;

  const CobrosStatusPieChart({
    super.key,
    required this.cobrosHoy,
    required this.locales,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    int totalLocales = locales.where((l) => l.activo == true).length;
    int cobrados = cobrosHoy
        .where((c) => c.estado == 'cobrado' || c.estado == 'abono_parcial')
        .length;
    int pendientes = totalLocales - cobrados;

    if (pendientes < 0) pendientes = 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de Cobros',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            if (totalLocales == 0)
              Expanded(
                child: Center(
                  child: Text(
                    'Sin locales activos',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: RepaintBoundary(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          color: const Color(0xFF00D9A6),
                          value: cobrados.toDouble(),
                          title: '$cobrados',
                          radius: 35,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: const Color(0xFFFF9F43),
                          value: pendientes.toDouble(),
                          title: '$pendientes',
                          radius: 35,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: [
                _Indicator(
                  color: const Color(0xFF00D9A6),
                  text: 'Cobrados ($cobrados)',
                ),
                _Indicator(
                  color: const Color(0xFFFF9F43),
                  text: 'Pendientes ($pendientes)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
