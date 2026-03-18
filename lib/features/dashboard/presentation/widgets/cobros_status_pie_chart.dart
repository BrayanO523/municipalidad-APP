import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

class CobrosStatusPieChart extends StatelessWidget {
  final List<Cobro>
  cobrosHoy; // Ya no se usa para el cálculo, pero se mantiene la firma
  final List<Local> locales;

  const CobrosStatusPieChart({
    super.key,
    required this.cobrosHoy,
    required this.locales,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final alDiaColor = semantic.success;
    final pendienteColor = semantic.warning;
    final deudaColor = semantic.danger;
    final adelantadoColor = semantic.info;

    Color onSection(Color base) =>
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final activos = locales.where((l) => l.activo == true).toList();
    final int totalLocales = activos.length;

    // Indexar los localIds que ya pagaron HOY
    final Set<String> localIdsConCobroHoy = {};
    for (var c in cobrosHoy) {
      if (c.localId != null && (c.monto ?? 0) > 0) {
        localIdsConCobroHoy.add(c.localId!);
      }
    }

    int localesConDeuda = 0;
    int localesAdelantados = 0;
    int localesAlDia = 0;
    int localesPendienteHoy = 0;

    for (var l in activos) {
      if ((l.deudaAcumulada ?? 0) > 0) {
        localesConDeuda++;
      } else if ((l.saldoAFavor ?? 0) > 0) {
        localesAdelantados++;
      } else if (l.id != null && !localIdsConCobroHoy.contains(l.id)) {
        // Sin deuda, sin saldo a favor, y NO ha pagado hoy → Pendiente Hoy
        localesPendienteHoy++;
      } else {
        localesAlDia++;
      }
    }

    // Asegurar que haya algo que mostrar incluso si todos están en 0
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
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    startDegreeOffset: -90,
                    sections: [
                      if (localesAlDia > 0)
                        PieChartSectionData(
                          color: alDiaColor,
                          value: localesAlDia.toDouble(),
                          title: '$localesAlDia',
                          radius: 35,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: onSection(alDiaColor),
                          ),
                        ),
                      if (localesPendienteHoy > 0)
                        PieChartSectionData(
                          color: pendienteColor,
                          value: localesPendienteHoy.toDouble(),
                          title: '$localesPendienteHoy',
                          radius: 35,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: onSection(pendienteColor),
                          ),
                        ),
                      if (localesConDeuda > 0)
                        PieChartSectionData(
                          color: deudaColor,
                          value: localesConDeuda.toDouble(),
                          title: '$localesConDeuda',
                          radius: 35,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: onSection(deudaColor),
                          ),
                        ),
                      if (localesAdelantados > 0)
                        PieChartSectionData(
                          color: adelantadoColor,
                          value: localesAdelantados.toDouble(),
                          title: '$localesAdelantados',
                          radius: 35,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: onSection(adelantadoColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: [
                _Indicator(color: alDiaColor, text: 'Al Día ($localesAlDia)'),
                _Indicator(
                  color: pendienteColor,
                  text: 'Pendiente Hoy ($localesPendienteHoy)',
                ),
                _Indicator(
                  color: deudaColor,
                  text: 'Con Deuda ($localesConDeuda)',
                ),
                _Indicator(
                  color: adelantadoColor,
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
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
