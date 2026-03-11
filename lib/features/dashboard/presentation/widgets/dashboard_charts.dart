import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/di/providers.dart';
import '../../../cobros/domain/entities/cobro.dart';
import 'cobros_status_pie_chart.dart';
import 'recaudacion_bar_chart.dart';

class DashboardChartsWidget extends ConsumerWidget {
  final List<Cobro> cobrosHoy;

  const DashboardChartsWidget({
    super.key,
    required this.cobrosHoy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los streams de locales y mercados se obtienen aquí, no en el DashboardScreen,
    // para que el screen principal no los abra al cargar la primera vista.
    final locales = ref.watch(localesProvider).value ?? [];
    final mercados = ref.watch(mercadosProvider).value ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
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

