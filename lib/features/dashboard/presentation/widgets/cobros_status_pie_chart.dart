import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

class CobrosStatusPieChart extends StatelessWidget {
  final List<Cobro>
  cobrosHoy; // Ya no se usa para el cÃ¡lculo, pero se mantiene la firma
  final List<Local> locales;

  const CobrosStatusPieChart({
    super.key,
    required this.cobrosHoy,
    required this.locales,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final activos = locales.where((l) => l.activo == true).toList();
    final int totalLocales = activos.length;

    int localesConDeuda = 0;
    int localesAdelantados = 0;
    int localesAlDia = 0;

    for (var l in activos) {
      if ((l.deudaAcumulada ?? 0) > 0) {
        localesConDeuda++;
      } else if ((l.saldoAFavor ?? 0) > 0) {
        localesAdelantados++;
      } else {
        localesAlDia++;
      }
    }

    // Asegurar que haya algo que mostrar incluso si todos estÃ¡n en 0
    final hasData = totalLocales > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de Locales',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            if (!hasData)
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
                        if (localesAlDia > 0)
                          PieChartSectionData(
                            color: const Color(0xFF00D9A6), // Verde
                            value: localesAlDia.toDouble(),
                            title: '$localesAlDia',
                            radius: 35,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (localesConDeuda > 0)
                          PieChartSectionData(
                            color: const Color(0xFFEE5A6F), // Rojo
                            value: localesConDeuda.toDouble(),
                            title: '$localesConDeuda',
                            radius: 35,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (localesAdelantados > 0)
                          PieChartSectionData(
                            color: const Color(0xFF3A86FF), // Azul
                            value: localesAdelantados.toDouble(),
                            title: '$localesAdelantados',
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
                  text: 'Al DÃ­a ($localesAlDia)',
                ),
                _Indicator(
                  color: const Color(0xFFEE5A6F),
                  text: 'Con Deuda ($localesConDeuda)',
                ),
                _Indicator(
                  color: const Color(0xFF3A86FF),
                  text: 'Adelantados ($localesAdelantados)',
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

