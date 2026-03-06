import 'package:flutter/material.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import 'cobros_status_pie_chart.dart';
import 'recaudacion_bar_chart.dart';

class DashboardChartsWidget extends StatelessWidget {
  final List<Cobro> cobrosHoy;
  final List<Local> locales;
  final List<Mercado> mercados;

  const DashboardChartsWidget({
    super.key,
    required this.cobrosHoy,
    required this.locales,
    required this.mercados,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          // Como el contenedor ahora es de ancho completo, usamos Row
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 320,
                  child: CobrosStatusPieChart(
                    cobrosHoy: cobrosHoy,
                    locales: locales,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 320,
                  child: RecaudacionBarChart(
                    cobrosHoy: cobrosHoy,
                    mercados: mercados,
                  ),
                ),
              ),
            ],
          );
        } else {
          // Pantalla pequeña, apilados verticalmente
          return Column(
            children: [
              SizedBox(
                height: 260,
                width: double.infinity,
                child: CobrosStatusPieChart(
                  cobrosHoy: cobrosHoy,
                  locales: locales,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                width: double.infinity,
                child: RecaudacionBarChart(
                  cobrosHoy: cobrosHoy,
                  mercados: mercados,
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
