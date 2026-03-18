import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

class CobrosStatusPieChart extends StatelessWidget {
  final List<Cobro> cobrosHoy;
  final List<Local> locales;
  final String pendingLabel;

  const CobrosStatusPieChart({
    super.key,
    required this.cobrosHoy,
    required this.locales,
    required this.pendingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    final cobradosDiaColor = semantic.success;
    final cobradosConDeudaColor = semantic.danger;
    final pendientesColor = semantic.warning;

    final activos = locales.where((l) => l.activo == true).toList();
    final localesConCuota = activos
        .where((l) => (l.cuotaDiaria ?? 0) > 0)
        .toList();
    final totalEvaluados = localesConCuota.length;

    final localIdsConCobroPeriodo = <String>{};
    for (final c in cobrosHoy) {
      if (c.estado != 'anulado' && c.localId != null && (c.monto ?? 0) > 0) {
        localIdsConCobroPeriodo.add(c.localId!);
      }
    }

    var cobradosAlDia = 0;
    var cobradosConDeuda = 0;
    var pendientesPeriodo = 0;

    for (final l in localesConCuota) {
      final pagoEnPeriodo =
          l.id != null && localIdsConCobroPeriodo.contains(l.id);
      if (!pagoEnPeriodo) {
        pendientesPeriodo++;
        continue;
      }

      if ((l.deudaAcumulada ?? 0) > 0) {
        cobradosConDeuda++;
      } else {
        cobradosAlDia++;
      }
    }

    final cobrosAplicados = cobradosAlDia + cobradosConDeuda;
    final cobertura = totalEvaluados == 0
        ? 0.0
        : (cobrosAplicados / totalEvaluados) * 100;
    final localesConSaldoAFavor = activos
        .where((l) => (l.saldoAFavor ?? 0) > 0)
        .length;

    String pct(int value) {
      if (totalEvaluados <= 0) return '0.0%';
      final v = (value * 100) / totalEvaluados;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}%';
    }

    String sectionTitle(int value) {
      if (totalEvaluados <= 0) return '';
      final ratio = value / totalEvaluados;
      return ratio >= 0.08 ? '$value' : '';
    }

    final segments = <_PieSegment>[
      if (cobradosAlDia > 0)
        _PieSegment(value: cobradosAlDia, color: cobradosDiaColor),
      if (cobradosConDeuda > 0)
        _PieSegment(value: cobradosConDeuda, color: cobradosConDeudaColor),
      if (pendientesPeriodo > 0)
        _PieSegment(value: pendientesPeriodo, color: pendientesColor),
    ];

    Color onSection(Color base) =>
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion de Cobro por Local',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Periodo: $pendingLabel | Locales con cuota: $totalEvaluados',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (totalEvaluados == 0)
              Expanded(
                child: Center(
                  child: Text(
                    'Sin locales con cuota para evaluar',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: segments.asMap().entries.map((entry) {
                      final segment = entry.value;
                      return PieChartSectionData(
                        color: segment.color,
                        value: segment.value.toDouble(),
                        title: sectionTitle(segment.value),
                        radius: 34,
                        titleStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onSection(segment.color),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Indicator(
                  color: cobradosDiaColor,
                  text:
                      'Cobrados al dia ($cobradosAlDia, ${pct(cobradosAlDia)})',
                ),
                _Indicator(
                  color: cobradosConDeudaColor,
                  text:
                      'Cobrados con deuda ($cobradosConDeuda, ${pct(cobradosConDeuda)})',
                ),
                _Indicator(
                  color: pendientesColor,
                  text:
                      'Pendientes ($pendientesPeriodo, ${pct(pendientesPeriodo)})',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Cobertura del periodo: ${cobertura.toStringAsFixed(cobertura >= 10 ? 0 : 1)}% '
              '($cobrosAplicados/$totalEvaluados) | Con saldo a favor: $localesConSaldoAFavor',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieSegment {
  final int value;
  final Color color;

  const _PieSegment({required this.value, required this.color});
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
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
