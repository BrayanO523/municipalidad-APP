import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../../core/utils/date_formatter.dart';
import '../widgets/metric_card.dart';
import '../widgets/recent_cobros_table.dart';
import '../widgets/dashboard_charts.dart';
import '../../../../core/utils/mass_import_eventuales.dart';
import '../../../../core/utils/mass_import_locales.dart';
import '../../../../core/utils/mass_import_faltantes_locales_inmaculada.dart';
import '../../../../core/utils/cobros_migration.dart';
import '../widgets/custom_date_range_picker.dart';
import '../../../cobros/data/services/deuda_service.dart';

const bool _kShowDevTools =
    kDebugMode || bool.fromEnvironment('DEV_TOOLS', defaultValue: false);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Disparar verificación de deuda retroactiva al iniciar el dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarDeudaRetroactiva();
    });
  }

  Future<void> _verificarDeudaRetroactiva() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hoy = DateTime.now();
      final hoyString = DateFormat('yyyyMMdd').format(hoy);
      final hoyKey = 'last_deuda_sync_web_$hoyString';

      // Si ya se sincronizó hoy en este navegador, saltar
      if (prefs.containsKey(hoyKey)) return;

      final usuario = ref.read(currentUsuarioProvider).value;
      if (usuario == null) return;

      // Esperar a que los locales y stats carguen
      final localesActivos = await ref.read(localesProvider.future);
      final stats = await ref.read(statsProvider.future);

      final service = DeudaService(
        cobroDs: ref.read(cobroDatasourceProvider),
        localDs: ref.read(localDatasourceProvider),
        firestore: FirebaseFirestore.instance,
        statsDs: ref.read(statsDatasourceProvider),
      );

      await service.verificarYRegistrarPendientes(
        localesActivos: localesActivos,
        diasAtras: 7,
        cobradorId: usuario.id,
        fechaInicioOperaciones: stats.fechaInicioOperaciones,
      );

      // Guardar que ya se revisó hoy en este navegador
      await prefs.setString(hoyKey, hoyString);
      
      // Invalidar stats y agregaciones para reflejar cambios si los hubo
      ref.invalidate(statsProvider);
      // ref.invalidate(statsAggregationsProvider); // Removido por refactor a localesProvider
    } catch (e) {
      debugPrint('⚠️ Error en verificación de deuda web: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cobrosHoy = ref.watch(cobrosHoyProvider);
    final rt = ref.watch(dashboardRealTimeStatsProvider);
    final filter = ref.watch(dashboardFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 700;
          final pagePadding = isMobile
              ? const EdgeInsets.all(16)
              : const EdgeInsets.all(24);
          return SingleChildScrollView(
            padding: pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: _DashboardHeader())],
                ),
                const SizedBox(height: 24),

                // ── KPI cards — fila 1: recaudación del día ──────────────────
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
                          child: MetricCard(
                            title: 'Recaudación ${filter.label}',
                            value: DateFormatter.formatCurrency(rt.recaudadoPeriodo),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF00D9A6),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Cobros ${filter.label}',
                            value: '${rt.cobrosPeriodo}',
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Mercados Activos',
                            value: '${rt.cantidadMercados}',
                            icon: Icons.store_rounded,
                            color: const Color(0xFFFF9F43),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Locales Registrados',
                            value: '${rt.cantidadLocales}',
                            icon: Icons.storefront_rounded,
                            color: const Color(0xFFEE5A6F),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── KPI cards — fila 2: deudas y saldo a favor ───────────────
                LayoutBuilder(
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
                            value: DateFormatter.formatCurrency(rt.pendienteHoy),
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFFFF6B35),
                            subtitle: 'Cuota esperada: ${DateFormatter.formatCurrency(rt.cuotaEsperadaHoy)}',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Deuda Acumulada',
                            value: DateFormatter.formatCurrency(rt.deudaTotal),
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEE5A6F),
                            subtitle: 'Total global de deudas',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Saldo a Favor',
                            value: DateFormatter.formatCurrency(rt.saldoAFavorTotal),
                            icon: Icons.savings_rounded,
                            color: const Color(0xFF00D9A6),
                            subtitle: 'Total global de créditos',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Gráficos ──────────────────────────────────────────────────
                DashboardChartsWidget(
                  cobrosHoy: cobrosHoy.value ?? [],
                ),

                const SizedBox(height: 24),

                // ── Cobros de la Fecha ────────────────────────────────────────
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
          );
        },
      ),
    );
  }
}

// ── Widgets de apoyo ─────────────────────────────────────────────────────────

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
                    ).colorScheme.onSurface.withAlpha(138),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            _MarketSelector(),
            _PeriodSelector(),
            if (_kShowDevTools)
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
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
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
            if (_kShowDevTools)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Importación de Eventuales'),
                      content: const Text(
                        'Se importarán los eventuales desde el CSV eventuales_completo_con_ruta.csv. Esta acción creará o actualizará documentos en Firestore automáticamente. ¿Desea proceder?',
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
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Importando eventuales...'),
                        ),
                      );
                      final res = await MassImportEventuales.ejecutar();
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
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Importar Eventuales'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),

            const SizedBox(width: 8),
            if (_kShowDevTools)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Recrear Locales desde CSV',
                        style: TextStyle(color: Colors.red),
                      ),
                      content: const Text(
                        'Se eliminarán todos los locales actuales del Mercado Inmaculada Concepción y luego se volverán a importar desde el CSV. Esta acción sobrescribe el catálogo de locales de ese mercado. ¿Desea proceder?',
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
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Recrear'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recreando locales desde CSV...'),
                        ),
                      );
                      final res = await MassImportLocales.recrearDesdeCsv();
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
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('Recrear Locales'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),

            const SizedBox(width: 8),
            if (_kShowDevTools)
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
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
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
            if (_kShowDevTools)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('ImportaciÃ³n de Faltantes (Locales)'),
                      content: const Text(
                        'Se importarÃ¡n 116 locales faltantes (hojas 001/019/333) al Mercado Inmaculada ConcepciÃ³n usando docId por CLAVE. Se omiten por ahora los casos especiales (codigo 335 y 616). Â¿Desea proceder?',
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
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Importando locales faltantes...'),
                        ),
                      );
                      final res =
                          await MassImportFaltantesLocalesInmaculada.ejecutar();
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
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('Importar Faltantes'),
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
            if (_kShowDevTools)
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Revertir Importar Faltantes',
                        style: TextStyle(color: Colors.red),
                      ),
                      content: const Text(
                        'Se eliminarÃ¡n los locales creados por el script de faltantes (creadoPor=import_faltantes_script) que NO tengan movimientos (deuda/saldo en 0). Si algÃºn local ya fue modificado o tiene movimientos, NO se borrarÃ¡. Â¿Desea proceder?',
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
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Revertir'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Revirtiendo importaciÃ³n de faltantes...'),
                        ),
                      );
                      final res =
                          await MassImportFaltantesLocalesInmaculada.revertir();
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
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Revertir Faltantes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),



            const SizedBox(width: 8),
            if (_kShowDevTools)
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
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reseteando sistema...')),
                      );
                      final ds = ref.read(cobroDatasourceProvider);
                      final user = ref.read(currentUsuarioProvider).value;
                      if (user?.municipalidadId == null) {
                        throw Exception('No se pudo obtener la municipalidad del usuario');
                      }
                      await ds.softResetSistema(user!.municipalidadId!);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sistema reseteado. Las operaciones inician a partir de hoy.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        ref.invalidate(cobrosHoyProvider);
                        ref.invalidate(mercadosProvider);
                        ref.invalidate(localesProvider);
                        ref.invalidate(statsProvider);
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
            if (_kShowDevTools)
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
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
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
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Recalcular Estadísticas'),
                      ],
                    ),
                    content: const Text(
                      'Esta acción escaneará todos los cobros y locales para reconstruir los contadores globales desde cero. Útil si hay desajustes por ediciones manuales. ¿Desea continuar?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Recalcular'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (!context.mounted) return;
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recalculando estadísticas globales...')),
                    );
                    
                    final ds = ref.read(statsDatasourceProvider);
                    final user = ref.read(currentUsuarioProvider).value;
                    if (user?.municipalidadId == null) {
                      throw Exception('No se pudo identificar la municipalidad');
                    }

                    await ds.recalcularTodo(user!.municipalidadId!);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Estadísticas sincronizadas con éxito.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Refrescar el provider de stats
                      ref.invalidate(statsProvider);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error al recalcular: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.sync_problem_rounded, size: 18),
              label: const Text('Recalcular Stats'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange, width: 0.5),
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

class _MarketSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mercadosAsync = ref.watch(mercadosProvider);
    final selectedId = ref.watch(dashboardMercadoIdProvider);

    return mercadosAsync.when(
      data: (mercados) {
        if (mercados.isEmpty) return const SizedBox.shrink();

        // Si no hay nada seleccionado, seleccionar el primero automáticamente
        if (selectedId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(dashboardMercadoIdProvider.notifier).set(mercados.first.id);
          });
          return const SizedBox.shrink();
        }

        // Verificar que el ID seleccionado sea válido (por si se eliminó o cambió)
        final idValido = mercados.any((m) => m.id == selectedId) ? selectedId : null;
        if (idValido == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(dashboardMercadoIdProvider.notifier).set(mercados.first.id);
          });
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: idValido,
                underline: const SizedBox(),
                hint: const Text('Elegir Mercado', style: TextStyle(fontSize: 13)),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                items: mercados.map(
                  (m) => DropdownMenuItem<String>(
                    value: m.id,
                    child: Text(m.nombre ?? 'Sin nombre'),
                  ),
                ).toList(),
                onChanged: (id) {
                  if (id != null) {
                    ref.read(dashboardMercadoIdProvider.notifier).set(id);
                  }
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 100,
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
