import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../../core/utils/date_formatter.dart';
import '../widgets/metric_card.dart';
import '../widgets/recent_cobros_table.dart';
import '../widgets/dashboard_charts.dart';
import '../../../../core/utils/mass_import_locales.dart';
import '../../../../core/utils/cobros_migration.dart';
import '../widgets/custom_date_range_picker.dart';



class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final cobrosHoy = ref.watch(cobrosHoyProvider);
    final stats = ref.watch(statsProvider);
    final filter = ref.watch(dashboardFilterProvider);


    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: _DashboardHeader())],
            ),
            const SizedBox(height: 24),

            // â”€â”€ KPI cards â€” fila 1: recaudación del día â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1000
                    ? 4
                    : constraints.maxWidth > 600
                    ? 2
                    : 1;
                final cardW =
                    (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                    crossAxisCount;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardW,
                      child: stats.when(
                        data: (s) => MetricCard(
                          title: 'Recaudación Hoy',
                          value: DateFormatter.formatCurrency(s.recaudacionHoy),
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF00D9A6),
                        ),
                        loading: () => const MetricCard(
                          title: 'Recaudación Hoy',
                          value: '...',
                          icon: Icons.payments_rounded,
                          color: Color(0xFF00D9A6),
                        ),
                        error: (_, __) => const MetricCard(
                          title: 'Recaudación Hoy',
                          value: 'Error',
                          icon: Icons.payments_rounded,
                          color: Color(0xFF00D9A6),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: stats.when(
                        data: (s) => MetricCard(
                          title: 'Cobros Hoy',
                          value: '${s.cobrosHoy}',
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
                      width: cardW,
                      child: stats.when(
                        data: (s) {
                          debugPrint('📈 DATA RECIBIDA DE STATS: m=${s.cantidadMercados}, l=${s.cantidadLocales}, d=${s.totalDeuda}, f=${s.totalSaldoAFavor}, c=${s.totalCobrado}');
                          return MetricCard(
                            title: 'Mercados Activos',
                            value: '${s.cantidadMercados}',
                            icon: Icons.store_rounded,
                            color: const Color(0xFFFF9F43),
                          );
                        },
                        loading: () => const MetricCard(
                          title: 'Mercados Activos',
                          value: '...',
                          icon: Icons.store_rounded,
                          color: Color(0xFFFF9F43),
                        ),
                        error: (err, stack) {
                          debugPrint('❌ ERROR AL CARGAR STATS: $err\n$stack');
                          return const MetricCard(
                            title: 'Mercados Activos',
                            value: 'Error',
                            icon: Icons.store_rounded,
                            color: Color(0xFFFF9F43),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardW,
                      child: stats.when(
                        data: (s) => MetricCard(
                          title: 'Locales Registrados',
                          value: '${s.cantidadLocales}',
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
            const SizedBox(height: 16),

            // â”€â”€ KPI cards â€” fila 2: deudas y saldo a favor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            stats.when(
              data: (s) {
                final deudaTotal = s.totalDeuda;
                final saldoAFavorTotal = s.totalSaldoAFavor;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
                    final cardW = (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Pendiente de Cobro Hoy',
                            value: DateFormatter.formatCurrency(s.pendienteCobroHoy),
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFFFF6B35),
                            subtitle: 'Cuota esperada: ${DateFormatter.formatCurrency(s.totalCuotaDiaria)}',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Deuda Acumulada',
                            value: DateFormatter.formatCurrency(deudaTotal),
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEE5A6F),
                            subtitle: 'Total global de deudas',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Saldo a Favor',
                            value: DateFormatter.formatCurrency(
                              saldoAFavorTotal,
                            ),
                            icon: Icons.savings_rounded,
                            color: const Color(0xFF00D9A6),
                            subtitle: 'Total global de créditos',
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Gráficos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            DashboardChartsWidget(
              cobrosHoy: cobrosHoy.value ?? [],
            ),

            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // â”€â”€ Cobros de la Fecha â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Builder(
              builder: (context) {
                final titulo = filter.period == DashboardPeriod.hoy
                    ? 'Cobros de Hoy'
                    : 'Cobros del Periodo (${filter.label})';

                return Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const RecentCobrosTable(),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Widgets de apoyo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DashboardHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final range = await showDialog<DateTimeRange>(
                      context: context,
                      builder: (context) =>
                          CustomDateRangePicker(initialRange: filter.range),
                    );

                    if (range != null) {
                      // Si seleccionamos un rango manualmente, forzamos a que el periodo sea personalizado
                      ref
                          .read(dashboardFilterProvider.notifier)
                          .setPeriod(DashboardPeriod.personalizado);
                      ref
                          .read(dashboardFilterProvider.notifier)
                          .setCustomRange(range);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 2.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(138),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          filter.range.start != filter.range.end
                              ? '${DateFormatter.formatDate(filter.range.start)} - ${DateFormatter.formatDate(filter.range.end)}'
                              : DateFormatter.formatDate(filter.range.start),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(138),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  filter.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withAlpha(204),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            _PeriodSelector(),
            if (kDebugMode)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Parchar y Limpiar Sistema'),
                      content: const Text(
                        '¿Desea ejecutar el parchado integral de datos? Esto inicializará los nuevos correlativos en Mercados, limpiará campos obsoletos en Usuarios y Locales, y parchará el historial de cobros para el modo offline.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Inicializar'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Inicializando correlativos...'),
                        ),
                      );
                      final ds = ref.read(cobroDatasourceProvider);
                      final procesados = await ds
                          .inicializarCorrelativosSistema();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Operación exitosa: $procesados registros parchados.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al inicializar: $e'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.build_circle_outlined, size: 18),
                label: const Text('Parchar Correlativos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),

            const SizedBox(width: 8),
            if (kDebugMode)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Importación Masiva de Locales'),
                      content: const Text(
                        'Se importarán 590 locales únicos al Mercado Inmaculada Concepción. ¿Desea proceder? Esta acción creará documentos en Firestore automáticamente.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Importar'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Importando locales...'),
                        ),
                      );
                      final res = await MassImportLocales.ejecutar();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Importar Locales'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),



            const SizedBox(width: 8),
            if (kDebugMode)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        '¿RESETEAR SISTEMA COMPLETO?',
                        style: TextStyle(color: Colors.red),
                      ),
                      content: const Text(
                        'Esta acción eliminará TODOS los cobros y reiniciará los correlativos a 1. Es irreversible. ¿Está seguro?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('BORRAR TODO'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reseteando sistema...')),
                      );
                      final ds = ref.read(cobroDatasourceProvider);
                      final borrados = await ds.resetearSistemaCompleto();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sistema reseteado: $borrados cobros eliminados.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        ref.invalidate(cobrosHoyProvider);
                        ref.invalidate(mercadosProvider);
                        ref.invalidate(localesProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al resetear: $e'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Resetear Sistema'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            if (kDebugMode)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Vincular Todo a Choluteca'),
                      content: const Text(
                        'Esta acción forzará que todos los locales, usuarios y cobros estén vinculados a la Municipalidad de Choluteca y al Mercado Inmaculada Concepción. ¿Desea proceder?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Vincular'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vinculando datos...')),
                      );
                      final res = await CobrosMigration.vincularTodoACholuteca();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Resultado de Vinculación'),
                            content: SingleChildScrollView(child: Text(res)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        );
                        ref.invalidate(cobrosHoyProvider);
                        ref.invalidate(mercadosProvider);
                        ref.invalidate(localesProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Vincular a Choluteca'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final cobros = ref.read(cobrosHoyProvider).value ?? [];
                final locales = ref.read(localesProvider).value ?? [];
                final mercados = ref.read(mercadosProvider).value ?? [];
                final filter = ref.read(dashboardFilterProvider);

                final bytes = await ReportePdfGenerator.generarReporteDashboard(
                  cobros: cobros,
                  locales: locales,
                  mercados: mercados,
                  periodoLabel: filter.period == DashboardPeriod.hoy
                      ? 'Hoy'
                      : filter.label,
                );

                if (kIsWeb) {
                  await descargarPdfWeb(
                    bytes,
                    'Dashboard_${filter.label.replaceAll(" ", "_")}.pdf',
                  );
                } else {
                  await Printing.layoutPdf(
                    onLayout: (_) async => bytes,
                    name: 'Dashboard_${filter.label}',
                  );
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Exportar PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);

    return Wrap(
      spacing: 8,
      children: [
        _PeriodChip(
          label: 'Hoy',
          selected: filter.period == DashboardPeriod.hoy,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.hoy),
        ),
        _PeriodChip(
          label: 'Semana',
          selected: filter.period == DashboardPeriod.semana,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.semana),
        ),
        _PeriodChip(
          label: 'Mes',
          selected: filter.period == DashboardPeriod.mes,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.mes),
        ),
        _PeriodChip(
          label: 'Año',
          selected: filter.period == DashboardPeriod.anio,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.anio),
        ),
        _PeriodChip(
          label: 'Personalizado',
          selected: filter.period == DashboardPeriod.personalizado,
          onSelected: () => ref
              .read(dashboardFilterProvider.notifier)
              .setPeriod(DashboardPeriod.personalizado),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onSurface
            : colorScheme.onSurface.withValues(alpha: 0.54),
        fontSize: 12,
      ),
      selectedColor: const Color(0xFF00D9A6).withValues(alpha: 0.3),
      backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
      showCheckmark: false,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

