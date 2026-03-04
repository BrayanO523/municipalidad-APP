import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../widgets/metric_card.dart';
import '../widgets/recent_cobros_table.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosHoy = ref.watch(cobrosHoyProvider);
    final locales = ref.watch(localesProvider);
    final mercados = ref.watch(mercadosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeader(),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1000
                    ? 4
                    : constraints.maxWidth > 600
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width:
                          (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                          crossAxisCount,
                      child: cobrosHoy.when(
                        data: (cobros) {
                          final totalCobrado = cobros.fold<num>(
                            0,
                            (sum, c) => sum + (c.monto ?? 0),
                          );
                          return MetricCard(
                            title: 'Cobrado Hoy',
                            value: DateFormatter.formatCurrency(totalCobrado),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF00D9A6),
                          );
                        },
                        loading: () => const MetricCard(
                          title: 'Cobrado Hoy',
                          value: '...',
                          icon: Icons.payments_rounded,
                          color: Color(0xFF00D9A6),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Cobrado Hoy',
                          value: 'Error',
                          icon: Icons.payments_rounded,
                          color: Color(0xFF00D9A6),
                        ),
                      ),
                    ),
                    SizedBox(
                      width:
                          (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                          crossAxisCount,
                      child: cobrosHoy.when(
                        data: (cobros) => MetricCard(
                          title: 'Cobros Hoy',
                          value: '${cobros.length}',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF6C63FF),
                        ),
                        loading: () => const MetricCard(
                          title: 'Cobros Hoy',
                          value: '...',
                          icon: Icons.receipt_long_rounded,
                          color: Color(0xFF6C63FF),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Cobros Hoy',
                          value: 'Error',
                          icon: Icons.receipt_long_rounded,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    SizedBox(
                      width:
                          (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                          crossAxisCount,
                      child: mercados.when(
                        data: (m) => MetricCard(
                          title: 'Mercados Activos',
                          value: '${m.where((e) => e.activo == true).length}',
                          icon: Icons.store_rounded,
                          color: const Color(0xFFFF9F43),
                        ),
                        loading: () => const MetricCard(
                          title: 'Mercados Activos',
                          value: '...',
                          icon: Icons.store_rounded,
                          color: Color(0xFFFF9F43),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Mercados Activos',
                          value: 'Error',
                          icon: Icons.store_rounded,
                          color: Color(0xFFFF9F43),
                        ),
                      ),
                    ),
                    SizedBox(
                      width:
                          (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                          crossAxisCount,
                      child: locales.when(
                        data: (l) => MetricCard(
                          title: 'Locales Registrados',
                          value: '${l.length}',
                          icon: Icons.storefront_rounded,
                          color: const Color(0xFFEE5A6F),
                        ),
                        loading: () => const MetricCard(
                          title: 'Locales Registrados',
                          value: '...',
                          icon: Icons.storefront_rounded,
                          color: Color(0xFFEE5A6F),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Locales Registrados',
                          value: 'Error',
                          icon: Icons.storefront_rounded,
                          color: Color(0xFFEE5A6F),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Cobros Recientes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const RecentCobrosTable(),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormatter.formatDate(now),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}
