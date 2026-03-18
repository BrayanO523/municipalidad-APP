import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../../core/utils/date_formatter.dart';
import '../widgets/metric_card.dart';
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
      debugPrint('Error en verificación de deuda web: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final cobrosHoy = ref.watch(cobrosHoyProvider);
    final rt = ref.watch(dashboardRealTimeStatsProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final moraPeriodo = rt.totalMoraRecuperada;
    final totalPeriodo = rt.recaudadoPeriodo;
    final corrientePeriodo = (totalPeriodo - moraPeriodo).clamp(
      0,
      double.infinity,
    );
    final inicioPeriodo = DateTime(
      filter.range.start.year,
      filter.range.start.month,
      filter.range.start.day,
    );
    final finPeriodo = DateTime(
      filter.range.end.year,
      filter.range.end.month,
      filter.range.end.day,
    );
    final diasPeriodo = (finPeriodo.difference(inicioPeriodo).inDays + 1).clamp(
      1,
      366,
    );
    final cuotaEsperadaPeriodo = (rt.cuotaEsperadaHoy * diasPeriodo).toDouble();
    final pendientePeriodo = (cuotaEsperadaPeriodo - totalPeriodo).clamp(
      0,
      double.infinity,
    );
    final cumplimientoPeriodo = cuotaEsperadaPeriodo > 0
        ? ((totalPeriodo / cuotaEsperadaPeriodo) * 100)
        : 0.0;
    final cobrosValidos = (cobrosHoy.value ?? [])
        .where((c) => c.estado != 'anulado')
        .where((c) => (c.correlativo ?? 0) > 0 || c.numeroBoleta != null)
        .toList();
    final nombrePorCobrador = <String, String>{
      for (final u in usuarios)
        if ((u.id ?? '').isNotEmpty)
          u.id!: (u.nombre?.trim().isNotEmpty ?? false)
              ? u.nombre!.trim()
              : 'Sin nombre',
    };
    final montoPorCobrador = <String, num>{};
    for (final c in cobrosValidos) {
      final cobradorId = (c.cobradorId ?? '').trim();
      if (cobradorId.isEmpty) continue;
      montoPorCobrador[cobradorId] =
          (montoPorCobrador[cobradorId] ?? 0) + (c.monto ?? 0);
    }
    final rankingCobradores = montoPorCobrador.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final moraPorCobrador = <String, num>{};
    for (final c in cobrosValidos) {
      final cobradorId = (c.cobradorId ?? '').trim();
      if (cobradorId.isEmpty) continue;
      final mora = c.montoMora ?? 0;
      if (mora <= 0) continue;
      moraPorCobrador[cobradorId] = (moraPorCobrador[cobradorId] ?? 0) + mora;
    }
    final rankingMora = moraPorCobrador.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DashboardHeader(
                        cantidadMercados: rt.cantidadMercados,
                        cantidadLocales: rt.cantidadLocales,
                        deudaTotal: rt.deudaTotal,
                        saldoAFavorTotal: rt.saldoAFavorTotal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // KPIs operativos del periodo
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
                            title: 'Corriente ${filter.label}',
                            value: DateFormatter.formatCurrency(
                              corrientePeriodo,
                            ),
                            icon: Icons.payments_rounded,
                            color: semantic.success,
                            subtitle: 'Total del periodo menos mora recuperada',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Mora Recuperada ${filter.label}',
                            value: DateFormatter.formatCurrency(moraPeriodo),
                            icon: Icons.currency_exchange_rounded,
                            color: semantic.warning,
                            subtitle: 'Pagos aplicados a deuda vencida',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Total Recaudado ${filter.label}',
                            value: DateFormatter.formatCurrency(totalPeriodo),
                            icon: Icons.account_balance_wallet_rounded,
                            color: semantic.info,
                            subtitle: 'Corriente + mora del periodo',
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: MetricCard(
                            title: 'Cobros ${filter.label}',
                            value: '${rt.cobrosPeriodo}',
                            icon: Icons.receipt_long_rounded,
                            color: semantic.danger,
                            subtitle: 'Recibos válidos emitidos en el periodo',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Gráficos principales
                DashboardChartsWidget(cobrosHoy: cobrosHoy.value ?? []),

                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 1200
                        ? 3
                        : constraints.maxWidth > 760
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
                          child: _ChartCard(
                            title: 'Participación por Cobrador ${filter.label}',
                            icon: Icons.leaderboard_rounded,
                            color: semantic.info,
                            child: _ParticipacionCobradoresChart(
                              ranking: rankingCobradores,
                              nombres: nombrePorCobrador,
                              totalRecaudado: totalPeriodo.toDouble(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: _ChartCard(
                            title:
                                'Mora Recuperada por Cobrador ${filter.label}',
                            icon: Icons.currency_exchange_rounded,
                            color: semantic.danger,
                            child: _MoraCobradoresChart(
                              ranking: rankingMora,
                              nombres: nombrePorCobrador,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardW,
                          child: _ChartCard(
                            title: 'Cumplimiento del Periodo ${filter.label}',
                            icon: Icons.track_changes_rounded,
                            color: semantic.warning,
                            child: _CumplimientoPeriodoChart(
                              cumplimiento: cumplimientoPeriodo.toDouble(),
                              recaudado: totalPeriodo.toDouble(),
                              meta: cuotaEsperadaPeriodo.toDouble(),
                              pendiente: pendientePeriodo.toDouble(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeaderStatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(30), color.withAlpha(12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(56)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withAlpha(36),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ParticipacionCobradoresChart extends StatelessWidget {
  final List<MapEntry<String, num>> ranking;
  final Map<String, String> nombres;
  final double totalRecaudado;

  const _ParticipacionCobradoresChart({
    required this.ranking,
    required this.nombres,
    required this.totalRecaudado,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    if (ranking.isEmpty || totalRecaudado <= 0) {
      return Text(
        'Sin actividad de cobros en el periodo.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    final top = ranking.take(4).toList();

    return Column(
      children: top.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final nombre = nombres[item.key] ?? item.key;
        final porcentaje = ((item.value.toDouble() / totalRecaudado) * 100)
            .clamp(0.0, 100.0);
        final ratio = porcentaje / 100;
        final barColor = idx == 0
            ? semantic.info
            : idx == 1
            ? semantic.success
            : semantic.warning;

        return Tooltip(
          message:
              '$nombre\nMonto: ${DateFormatter.formatCurrency(item.value)}\nParticipacion: ${porcentaje.toStringAsFixed(porcentaje >= 10 ? 0 : 1)}%',
          child: Padding(
            padding: EdgeInsets.only(bottom: idx == top.length - 1 ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormatter.formatCurrency(item.value)} | ${porcentaje.toStringAsFixed(porcentaje >= 10 ? 0 : 1)}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MoraCobradoresChart extends StatelessWidget {
  final List<MapEntry<String, num>> ranking;
  final Map<String, String> nombres;

  const _MoraCobradoresChart({required this.ranking, required this.nombres});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    if (ranking.isEmpty) {
      return Text(
        'Sin mora recuperada en el periodo.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    final top = ranking.take(4).toList();
    final maxMora = top.first.value.toDouble() <= 0
        ? 1.0
        : top.first.value.toDouble();

    return Column(
      children: top.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final nombre = nombres[item.key] ?? item.key;
        final ratio = (item.value.toDouble() / maxMora).clamp(0.0, 1.0);
        final barColor = idx == 0 ? semantic.danger : semantic.warning;
        return Tooltip(
          message:
              '$nombre\nMora recuperada: ${DateFormatter.formatCurrency(item.value)}',
          child: Padding(
            padding: EdgeInsets.only(bottom: idx == top.length - 1 ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.formatCurrency(item.value),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CumplimientoPeriodoChart extends StatelessWidget {
  final double cumplimiento;
  final double recaudado;
  final double meta;
  final double pendiente;

  const _CumplimientoPeriodoChart({
    required this.cumplimiento,
    required this.recaudado,
    required this.meta,
    required this.pendiente,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final normalized = (cumplimiento / 100).clamp(0.0, 1.0);
    final color = cumplimiento >= 90
        ? semantic.success
        : cumplimiento >= 65
        ? semantic.warning
        : semantic.danger;
    final estado = cumplimiento >= 90
        ? 'Meta casi cumplida'
        : cumplimiento >= 65
        ? 'Meta en progreso'
        : 'Meta rezagada';

    return Tooltip(
      message:
          'Cumplimiento: ${cumplimiento.toStringAsFixed(cumplimiento >= 10 ? 0 : 1)}%\n'
          'Recaudado: ${DateFormatter.formatCurrency(recaudado)}\n'
          'Meta: ${DateFormatter.formatCurrency(meta)}'
          '${pendiente > 0 ? '\nPendiente: ${DateFormatter.formatCurrency(pendiente)}' : ''}',
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: normalized,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
                Icon(Icons.track_changes_rounded, size: 18, color: color),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  estado,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recaudado ${DateFormatter.formatCurrency(recaudado)} de ${DateFormatter.formatCurrency(meta)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (pendiente > 0)
                  Text(
                    'Pendiente: ${DateFormatter.formatCurrency(pendiente)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  final int cantidadMercados;
  final int cantidadLocales;
  final num deudaTotal;
  final num saldoAFavorTotal;

  const _DashboardHeader({
    required this.cantidadMercados,
    required this.cantidadLocales,
    required this.deudaTotal,
    required this.saldoAFavorTotal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHigh.withAlpha(210),
            colorScheme.surfaceContainerLow.withAlpha(190),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(90)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;
              final descripcion = filter.period == DashboardPeriod.personalizado
                  ? 'Rango personalizado aplicado al panel.'
                  : filter.description;
              final rangoLabel = filter.range.start != filter.range.end
                  ? '${DateFormatter.formatDate(filter.range.start)} - ${DateFormatter.formatDate(filter.range.end)}'
                  : DateFormatter.formatDate(filter.range.start);

              Widget buildDateSelector({required bool expanded}) => InkWell(
                onTap: () async {
                  final range = await showDialog<DateTimeRange>(
                    context: context,
                    builder: (context) =>
                        CustomDateRangePicker(initialRange: filter.range),
                  );

                  if (range != null) {
                    ref
                        .read(dashboardFilterProvider.notifier)
                        .setPeriod(DashboardPeriod.personalizado);
                    ref
                        .read(dashboardFilterProvider.notifier)
                        .setCustomRange(range);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: expanded
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      if (expanded)
                        Expanded(
                          child: Text(
                            rangoLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        )
                      else
                        Text(
                          rangoLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                ),
              );

              final controls = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  buildDateSelector(expanded: false),
                  _PeriodSelector(),
                  _MarketSelector(),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(dashboardFilterProvider.notifier)
                          .setPeriod(DashboardPeriod.hoy);
                      ref.read(dashboardMercadoIdProvider.notifier).set(null);
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Limpiar filtros'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(cobrosHoyProvider);
                      ref.invalidate(mercadosProvider);
                      ref.invalidate(localesProvider);
                      ref.invalidate(statsProvider);
                      ref.invalidate(dashboardRealTimeStatsProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Recargar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ),
                ],
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Centro de Control de Cobros',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        _HeaderStatPill(
                          icon: Icons.store_rounded,
                          label: 'Mercados',
                          value: '$cantidadMercados',
                          color: context.semanticColors.warning,
                        ),
                        _HeaderStatPill(
                          icon: Icons.storefront_rounded,
                          label: 'Locales',
                          value: '$cantidadLocales',
                          color: context.semanticColors.danger,
                        ),
                        _HeaderStatPill(
                          icon: Icons.warning_amber_rounded,
                          label: 'Deuda',
                          value: DateFormatter.formatCurrency(deudaTotal),
                          color: context.semanticColors.danger,
                        ),
                        _HeaderStatPill(
                          icon: Icons.savings_rounded,
                          label: 'Saldo a favor',
                          value: DateFormatter.formatCurrency(saldoAFavorTotal),
                          color: context.semanticColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    controls,
                  ],
                );
              }

              final topRightBadges = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _HeaderStatPill(
                    icon: Icons.store_rounded,
                    label: 'Mercados',
                    value: '$cantidadMercados',
                    color: context.semanticColors.warning,
                  ),
                  _HeaderStatPill(
                    icon: Icons.storefront_rounded,
                    label: 'Locales',
                    value: '$cantidadLocales',
                    color: context.semanticColors.danger,
                  ),
                  _HeaderStatPill(
                    icon: Icons.warning_amber_rounded,
                    label: 'Deuda',
                    value: DateFormatter.formatCurrency(deudaTotal),
                    color: context.semanticColors.danger,
                  ),
                  _HeaderStatPill(
                    icon: Icons.savings_rounded,
                    label: 'Saldo a favor',
                    value: DateFormatter.formatCurrency(saldoAFavorTotal),
                    color: context.semanticColors.success,
                  ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Centro de Control de Cobros',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              descripcion,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.54,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      topRightBadges,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: buildDateSelector(expanded: true)),
                        const SizedBox(width: 8),
                        _PeriodSelector(),
                        const SizedBox(width: 8),
                        _MarketSelector(),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(dashboardFilterProvider.notifier)
                                .setPeriod(DashboardPeriod.hoy);
                            ref
                                .read(dashboardMercadoIdProvider.notifier)
                                .set(null);
                          },
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 16,
                          ),
                          label: const Text('Limpiar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.invalidate(cobrosHoyProvider);
                            ref.invalidate(mercadosProvider);
                            ref.invalidate(localesProvider);
                            ref.invalidate(statsProvider);
                            ref.invalidate(dashboardRealTimeStatsProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Recargar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                                backgroundColor: semantic.success,
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
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondary,
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
                                backgroundColor: semantic.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('Importar Eventuales'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.warning,
                      foregroundColor: semantic.onWarning,
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
                          title: Text(
                            'Recrear Locales desde CSV',
                            style: TextStyle(color: semantic.danger),
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
                                backgroundColor: semantic.danger,
                                foregroundColor: semantic.onDanger,
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
                                backgroundColor: semantic.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Recrear Locales'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.danger,
                      foregroundColor: semantic.onDanger,
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
                                backgroundColor: semantic.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Importar Locales'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.info,
                      foregroundColor: semantic.onInfo,
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
                            'Importación de Faltantes (Locales)',
                          ),
                          content: const Text(
                            'Se importarán 116 locales faltantes (hojas 001/019/333) al Mercado Inmaculada Concepción usando docId por CLAVE. Se omiten por ahora los casos especiales (codigo 335 y 616). ¿Desea proceder?',
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
                                backgroundColor: semantic.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: const Text('Importar Faltantes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.info,
                      foregroundColor: semantic.onInfo,
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
                          title: Text(
                            'Revertir Importar Faltantes',
                            style: TextStyle(color: semantic.danger),
                          ),
                          content: const Text(
                            'Se eliminarán los locales creados por el script de faltantes (creadoPor=import_faltantes_script) que NO tengan movimientos (deuda/saldo en 0). Si algún local ya fue modificado o tiene movimientos, NO se borrará. ¿Desea proceder?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: semantic.danger,
                                foregroundColor: semantic.onDanger,
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
                              content: Text(
                                'Revirtiendo importación de faltantes...',
                              ),
                            ),
                          );
                          final res =
                              await MassImportFaltantesLocalesInmaculada.revertir();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res),
                                backgroundColor: semantic.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Revertir Faltantes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.danger,
                      foregroundColor: semantic.onDanger,
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
                          title: Text(
                            '¿RESETEAR SISTEMA COMPLETO?',
                            style: TextStyle(color: semantic.danger),
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
                                backgroundColor: semantic.danger,
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
                            const SnackBar(
                              content: Text('Reseteando sistema...'),
                            ),
                          );
                          final ds = ref.read(cobroDatasourceProvider);
                          final user = ref.read(currentUsuarioProvider).value;
                          if (user?.municipalidadId == null) {
                            throw Exception(
                              'No se pudo obtener la municipalidad del usuario',
                            );
                          }
                          await ds.softResetSistema(user!.municipalidadId!);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sistema reseteado. Las operaciones inician a partir de hoy.',
                                ),
                                backgroundColor: semantic.warning,
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
                      backgroundColor: semantic.danger.withValues(alpha: 0.1),
                      foregroundColor: semantic.danger,
                      side: BorderSide(color: semantic.danger, width: 0.5),
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
                            const SnackBar(
                              content: Text('Vinculando datos...'),
                            ),
                          );
                          final res =
                              await CobrosMigration.vincularTodoACholuteca();
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Resultado de Vinculación'),
                                content: SingleChildScrollView(
                                  child: Text(res),
                                ),
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
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Vincular a Choluteca'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.info,
                      foregroundColor: semantic.onInfo,
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
                          title: const Text('Migrar Mora Histórica'),
                          content: const Text(
                            'Esta acción recalculará la mora para todos los cobros históricos anteriores a hoy. ¿Desea proceder?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Migrar Mora'),
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
                              content: Text(
                                'Migrando Mora (puede tardar unos segundos)...',
                              ),
                            ),
                          );

                          final res =
                              await CobrosMigration.migrarMoraHistorica();

                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Resultado de Migración'),
                              content: SingleChildScrollView(child: Text(res)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                          ref.invalidate(dashboardRealTimeStatsProvider);
                          ref.invalidate(statsProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Migrar Mora Histórica'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.info,
                      foregroundColor: semantic.onInfo,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                if (_kShowDevTools) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: semantic.warning,
                              ),
                              const SizedBox(width: 8),
                              const Text('Recalcular Estadísticas'),
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
                            const SnackBar(
                              content: Text(
                                'Recalculando estadísticas globales...',
                              ),
                            ),
                          );

                          final ds = ref.read(statsDatasourceProvider);
                          final user = ref.read(currentUsuarioProvider).value;
                          if (user?.municipalidadId == null) {
                            throw Exception(
                              'No se pudo identificar la municipalidad',
                            );
                          }

                          await ds.recalcularTodo(user!.municipalidadId!);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Estadísticas sincronizadas con éxito.',
                                ),
                                backgroundColor: semantic.success,
                              ),
                            );
                            // Refrescar el provider de stats
                            ref.invalidate(statsProvider);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al recalcular: $e'),
                                backgroundColor: semantic.danger,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.sync_problem_rounded, size: 18),
                    label: const Text('Recalcular Stats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: semantic.warning.withValues(alpha: 0.1),
                      foregroundColor: semantic.warning,
                      side: BorderSide(color: semantic.warning, width: 0.5),
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

                      final bytes =
                          await ReportePdfGenerator.generarReporteDashboard(
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
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketSelector extends ConsumerWidget {
  static const double _kSelectorWidth = 270;
  static const double _kSelectorHeight = 40;

  Widget _buildPlaceholder(BuildContext context, {required bool loading}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minHeight: _kSelectorHeight,
        minWidth: _kSelectorWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: _kSelectorWidth - (loading ? 74 : 58),
            child: Text(
              loading ? 'Cargando mercados...' : 'Mercados no disponibles',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mercadosAsync = ref.watch(mercadosProvider);
    final selectedId = ref.watch(dashboardMercadoIdProvider);

    return mercadosAsync.when(
      data: (mercados) {
        if (mercados.isEmpty) return _buildPlaceholder(context, loading: false);

        // Si el mercado seleccionado ya no existe, volver a "Todos".
        final idValido =
            selectedId == null || mercados.any((m) => m.id == selectedId)
            ? selectedId
            : null;
        if (selectedId != null && idValido == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(dashboardMercadoIdProvider.notifier).set(null);
          });
        }

        return Container(
          constraints: const BoxConstraints(
            minHeight: _kSelectorHeight,
            minWidth: _kSelectorWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
              SizedBox(
                width: _kSelectorWidth - 48,
                child: DropdownButton<String?>(
                  value: idValido,
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Text('Todos', style: TextStyle(fontSize: 13)),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos los mercados'),
                    ),
                    ...mercados.map(
                      (m) => DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(
                          m.nombre ?? 'Sin nombre',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (id) {
                    ref.read(dashboardMercadoIdProvider.notifier).set(id);
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _buildPlaceholder(context, loading: true),
      error: (_, __) => _buildPlaceholder(context, loading: false),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  static const double _kSelectorWidth = 180;
  static const double _kSelectorHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final periodNotifier = ref.read(dashboardFilterProvider.notifier);
    final selectedPeriod = switch (filter.period) {
      DashboardPeriod.hoy => DashboardPeriod.hoy,
      DashboardPeriod.semana => DashboardPeriod.semana,
      DashboardPeriod.mes => DashboardPeriod.mes,
      DashboardPeriod.anio => DashboardPeriod.anio,
      DashboardPeriod.personalizado => null,
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minHeight: _kSelectorHeight,
        minWidth: _kSelectorWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: _kSelectorWidth - 48,
            child: DropdownButton<DashboardPeriod>(
              value: selectedPeriod,
              isDense: true,
              isExpanded: true,
              underline: const SizedBox(),
              hint: Text(
                filter.period == DashboardPeriod.personalizado
                    ? 'Personalizado'
                    : 'Periodo',
                style: const TextStyle(fontSize: 13),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem<DashboardPeriod>(
                  value: DashboardPeriod.hoy,
                  child: Text('Hoy'),
                ),
                DropdownMenuItem<DashboardPeriod>(
                  value: DashboardPeriod.semana,
                  child: Text('Semana'),
                ),
                DropdownMenuItem<DashboardPeriod>(
                  value: DashboardPeriod.mes,
                  child: Text('Mes'),
                ),
                DropdownMenuItem<DashboardPeriod>(
                  value: DashboardPeriod.anio,
                  child: Text('Año'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                periodNotifier.setPeriod(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
