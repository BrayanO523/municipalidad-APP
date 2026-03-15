import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../../core/utils/receipt_dispatcher.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../cobros/presentation/viewmodels/cobro_viewmodel.dart';
import '../widgets/deuda_rango_dialog.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../../core/utils/visual_debt_utils.dart';
import '../../../../app/theme/app_theme.dart';

/// Pantalla de Estado de Cuenta del locatario — vista del Cobrador.
/// Muestra el balance financiero completo y el historial de cobros
/// de un local específico, con acceso rápido a llamar al representante.
class CobradorEstadoCuentaScreen extends ConsumerStatefulWidget {
  final Local local;

  const CobradorEstadoCuentaScreen({super.key, required this.local});

  @override
  ConsumerState<CobradorEstadoCuentaScreen> createState() =>
      _CobradorEstadoCuentaScreenState();
}

class _CobradorEstadoCuentaScreenState
    extends ConsumerState<CobradorEstadoCuentaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _llamar(String? telefono) async {
    if (telefono == null || telefono.isEmpty) return;
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _cargarDeudaPorRango(Local local) async {
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => DeudaRangoDialog(local: local),
    );

    if (picked == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Confirmar Deuda'),
          ],
        ),
        content: Text(
          'Se registrará deuda pendiente desde el ${DateFormatter.formatDate(picked.start)} hasta el ${DateFormatter.formatDate(picked.end)} para:\n\n${local.nombreSocial}\n\nLos días que ya tengan un registro serán ignorados automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final usuario = ref.read(currentUsuarioProvider).value;
    final viewModel = ref.read(cobroViewModelProvider.notifier);

    final creados = await viewModel.agregarDeudaMasiva(
      local: local,
      range: picked,
      cobradorId: usuario?.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creados > 0
                ? '✅ Se registraron $creados días de deuda para ${local.nombreSocial}'
                : 'ℹ️ No se crearon nuevos registros (ya existían o fuera de rango)',
          ),
          backgroundColor: creados > 0 ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localAsync = ref.watch(localStreamProvider(widget.local.id ?? ''));
    final cobrosAsync = ref.watch(
      localCobrosStreamProvider(widget.local.id ?? ''),
    );
    final mercados = ref.watch(mercadosProvider).value ?? [];

    return localAsync.when(
      data: (local) {
        if (local == null) {
          return const Scaffold(
            body: Center(child: Text('Local no encontrado')),
          );
        }
        return cobrosAsync.when(
          data: (cobrosList) =>
              _buildContent(context, local, cobrosList, mercados),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Local local,
    List<Cobro> cobrosList,
    List<Mercado> mercados,
  ) {
    // --- Lógica Visual Centralizada ---
    final hoyVirtual = VisualDebtUtils.generarHoyPendienteVirtual(
      local: local,
      actualCobros: cobrosList,
    );
    final adelantadosVirtuales = VisualDebtUtils.generarAdelantadosVirtuales(
      local: local,
      actualCobros: cobrosList,
    );

    final List<Cobro> combinedList = [
      ...cobrosList,
      ...adelantadosVirtuales,
      if (hoyVirtual != null) hoyVirtual,
    ];

    combinedList.sort(
      (a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
    );

    final deudaVisual = VisualDebtUtils.calcularDeudaVisual(local, cobrosList);
    final balanceVisual = VisualDebtUtils.calcularBalanceNetoVisual(
      local,
      cobrosList,
    );
    final numAdelantados = adelantadosVirtuales.length;

    final cobrados = combinedList.where((c) => c.estado == 'cobrado').toList();
    final pendientes = combinedList
        .where((c) => c.estado == 'pendiente')
        .toList();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                local: local,
                deuda: deudaVisual,
                saldo: local.saldoAFavor ?? 0,
                balance: balanceVisual,
                numAdelantados: numAdelantados,
                onLlamar: () => _llamar(local.telefonoRepresentante),
              ),
            ),
            leading: const BackButton(),
            title: Text(
              local.nombreSocial ?? 'Estado de Cuenta',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  final mercadoName =
                      mercados
                          .cast<Mercado>()
                          .firstWhere(
                            (m) => m.id == local.mercadoId,
                            orElse: () => const Mercado(nombre: '-'),
                          )
                          .nombre ??
                      '-';

                  final bytes =
                      await ReportePdfGenerator.generarEstadoCuentaLocalPdf(
                        local: local,
                        cobros: combinedList,
                        nombreMercado: mercadoName,
                      );
                  if (kIsWeb) {
                    await descargarPdfWeb(
                      bytes,
                      'EstadoCuenta_${local.nombreSocial?.replaceAll(" ", "_") ?? "Local"}.pdf',
                    );
                  } else {
                    await Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name: 'EstadoCuenta_${local.nombreSocial}',
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'Exportar estado de cuenta en PDF',
              ),
              if (local.telefonoRepresentante != null &&
                  local.telefonoRepresentante!.isNotEmpty)
                IconButton(
                  onPressed: () => _llamar(local.telefonoRepresentante),
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Llamar al representante',
                ),
              IconButton(
                onPressed: () => _cargarDeudaPorRango(local),
                icon: const Icon(Icons.history_edu_rounded),
                color: AppColors.danger,
                tooltip: 'Cargar deuda por rango',
              ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Todos (${combinedList.length})'),
                Tab(text: 'Cobrados (${cobrados.length})'),
                Tab(text: 'Pendientes (${pendientes.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _CobrosList(cobros: combinedList, local: local),
            _CobrosList(cobros: cobrados, local: local),
            _CobrosList(cobros: pendientes, local: local),
          ],
        ),
      ),
    );
  }
}

// ── Header expandible ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Local local;
  final num deuda;
  final num saldo;
  final num balance;
  final int numAdelantados;
  final VoidCallback onLlamar;

  const _Header({
    required this.local,
    required this.deuda,
    required this.saldo,
    required this.balance,
    required this.numAdelantados,
    required this.onLlamar,
  });

  @override
  Widget build(BuildContext context) {
    final tieneDeuda = deuda > 0;
    final tieneSaldo = saldo > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerLow,
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 70, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info básica con botón de llamada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar con inicial
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      AppColors.success,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    (local.nombreSocial ?? 'L').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      local.representante ?? '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (local.telefonoRepresentante != null &&
                        local.telefonoRepresentante!.isNotEmpty)
                      GestureDetector(
                        onTap: onLlamar,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.call_rounded,
                              size: 12,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              local.telefonoRepresentante!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Cuota: ${DateFormatter.formatCurrency(local.cuotaDiaria)}/día',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de estado global
              _EstadoBadge(tieneDeuda: tieneDeuda, tieneSaldo: tieneSaldo),
            ],
          ),
          const SizedBox(height: 8),
          // KPIs financieros en fila
          Row(
            children: [
              _MiniKpi(
                label: 'Balance',
                value: DateFormatter.formatCurrency(balance),
                color: balance >= 0 ? AppColors.success : AppColors.danger,
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(width: 8),
              _MiniKpi(
                label: 'Deuda',
                value: DateFormatter.formatCurrency(deuda),
                color: deuda > 0
                    ? AppColors.danger
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 8),
              _MiniKpi(
                label: 'Días Adel.',
                value: '$numAdelantados',
                color: numAdelantados > 0
                    ? AppColors.warning
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                icon: Icons.fast_forward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final bool tieneDeuda;
  final bool tieneSaldo;

  const _EstadoBadge({required this.tieneDeuda, required this.tieneSaldo});

  @override
  Widget build(BuildContext context) {
    if (tieneDeuda) {
      return _Badge(
        label: 'Con Deuda',
        color: AppColors.danger,
        icon: Icons.warning_rounded,
      );
    }
    if (tieneSaldo) {
      return _Badge(
        label: 'Con Crédito',
        color: AppColors.success,
        icon: Icons.savings_rounded,
      );
    }
    return _Badge(
      label: 'Al Día',
      color: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniKpi({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lista de cobros ───────────────────────────────────────────────────────────

class _CobrosList extends ConsumerWidget {
  final List<Cobro> cobros;
  final Local local;

  const _CobrosList({required this.cobros, required this.local});

  /// Agrupa cobros basándose en el número de boleta o correlativo,
  /// eliminando registros "hijo" redundantes que ya están contenidos
  /// dentro de la información de una boleta maestra.
  List<dynamic> _agruparPorBoleta(List<Cobro> lista) {
    final result = <dynamic>[];
    final groups = <String, List<Cobro>>{};
    final Set<DateTime> fechasCubiertasPorMaestros = {};

    // 1. Primer pase: Identificar grupos con boleta y recolectar fechas cubiertas
    for (final c in lista) {
      final boletaId = c.numeroBoleta ?? c.correlativo?.toString();
      if (boletaId != null && boletaId.isNotEmpty && boletaId != '0') {
        if (!groups.containsKey(boletaId)) {
          groups[boletaId] = [];
        }
        groups[boletaId]!.add(c);

        // Extraer fechas saldadas de este registro "maestro"
        if (c.fechasDeudasSaldadas != null) {
          for (final d in c.fechasDeudasSaldadas!) {
            fechasCubiertasPorMaestros.add(DateTime(d.year, d.month, d.day));
          }
        }
        // También la fecha del registro si aplicó a cuota hoy
        if ((c.pagoACuota ?? 0) > 0 && c.fecha != null) {
          fechasCubiertasPorMaestros.add(
            DateTime(c.fecha!.year, c.fecha!.month, c.fecha!.day),
          );
        }
      }
    }

    // 2. Segundo pase: Construir la lista final de items respetando el orden
    final Set<String> boletasAgregadas = {};
    for (final c in lista) {
      final boletaId = c.numeroBoleta ?? c.correlativo?.toString();

      if (boletaId != null && boletaId.isNotEmpty && boletaId != '0') {
        // Si tiene boleta, lo agregamos como grupo (una sola vez)
        if (!boletasAgregadas.contains(boletaId)) {
          result.add(groups[boletaId]!);
          boletasAgregadas.add(boletaId);
        }
      } else {
        // Si NO tiene boleta, verificamos si es huérfano o si es un hijo redundante
        final fechaRef = c.fecha;
        if (fechaRef != null) {
          final dRef = DateTime(fechaRef.year, fechaRef.month, fechaRef.day);
          // Si esta fecha ya está en el set de maestros, es un registro hijo (redundante). IGNORAR.
          if (fechasCubiertasPorMaestros.contains(dRef)) {
            continue;
          }
        }
        // Si llegó aquí, es un registro individual que no está en ninguna boleta.
        result.add([c]);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cobros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.24),
            ),
            const SizedBox(height: 12),
            Text(
              'Sin registros',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final items = _agruparPorBoleta(cobros);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is List<Cobro>) {
          Cobro? masterPayment;
          double maxMonto = 0;
          for (final c in item) {
            final m = (c.monto ?? 0).toDouble();
            if (m > maxMonto) {
              maxMonto = m;
              masterPayment = c;
            }
          }
          if (masterPayment == null && item.isNotEmpty) {
            masterPayment = item.first;
          }

          // Si es un cobro huérfano y PENDIENTE, mostrar como tile plano en lugar de acordeón
          if (item.length == 1 && item.first.estado != 'cobrado') {
            final boleta =
                item.first.numeroBoleta ?? item.first.correlativo?.toString();
            if (boleta == null || boleta.isEmpty || boleta == '0') {
              return _CobroTile(
                cobro: item.first,
                local: local,
                onReprint: (ctx, ref, c) =>
                    _reimprimirCobroIndividual(ctx, ref, local, c),
                onShare: (ctx, ref, c) =>
                    _compartirCobroIndividual(ctx, ref, local, c),
              );
            }
          }

          return _GrupoBoletaCard(
            cobros: item,
            local: local,
            masterPayment: masterPayment,
            onImprimirCobro: (ctx, ref, cobro, fecha) =>
                _imprimirDiaEspecifico(ctx, ref, local, cobro, fecha),
            onCompartirCobro: (ctx, ref, cobro, fecha) =>
                _compartirDiaEspecifico(ctx, ref, local, cobro, fecha),
          );
        }
        return const SizedBox.shrink(); // No debería ocurrir
      },
    );
  }

  Future<void> _reimprimirCobroIndividual(
    BuildContext context,
    WidgetRef ref,
    Local local,
    Cobro c,
  ) async {
    final user = ref.read(currentUsuarioProvider).value;
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    String? periodoFavorStr;
    final favorResultante = (c.nuevoSaldoFavor ?? 0).toDouble();
    final cuota = (c.cuotaDiaria ?? 0).toDouble();
    final fechasRes = c.fechasDeudasSaldadas ?? [];
    if (favorResultante > 0 && cuota > 0) {
      int dias = (favorResultante / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = (c.fecha ?? DateTime.now()).add(
          const Duration(days: 1),
        );
        if (fechasRes.isNotEmpty) {
          final sorted = List<DateTime>.from(fechasRes)..sort();
          inicioFavor = sorted.last.add(const Duration(days: 1));
        }
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
          inicioFavor,
          dias,
        );
      }
    }

    String? periodoAbonadoStr;
    if (fechasRes.isNotEmpty) {
      periodoAbonadoStr = DateRangeFormatter.formatearRangos(fechasRes);
    }

    final cuotaLocal = (c.cuotaDiaria ?? local.cuotaDiaria ?? 0).toDouble();
    double abonoCuotaHoy = (c.pagoACuota ?? 0).toDouble();
    double pagoHoy = cuotaLocal - abonoCuotaHoy;
    if (pagoHoy < 0) pagoHoy = 0;

    // El saldoPendiente guardado incluye la cuota del día no pagada.
    // Para el recibo, la "Deuda actual" solo debe reflejar deuda VENCIDA real,
    // no la cuota de hoy que aún no es una deuda en sentido estricto.
    final saldoDeudaReal = ((c.saldoPendiente ?? 0).toDouble() - pagoHoy).clamp(0.0, double.infinity);

    if (context.mounted) {
      await ReceiptDispatcher.presentReceiptOptions(
        context: context,
        ref: ref,
        local: local,
        monto: (c.monto != null && c.monto! > 0)
            ? c.monto!.toDouble()
            : (c.cuotaDiaria ?? 0).toDouble(),
        fecha: c.fecha ?? DateTime.now(),
        saldoPendiente: saldoDeudaReal,
        deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
        montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
        pagoHoy: pagoHoy > 0 ? pagoHoy : null,
        abonoCuotaHoy: abonoCuotaHoy > 0 ? abonoCuotaHoy : null,
        saldoAFavor: favorResultante,
        numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? '0'}',
        municipalidadNombre: muni?.nombre ?? 'MUNICIPALIDAD',
        mercadoNombre: merc?.nombre,
        cobradorNombre: user?.nombre,
        fechasSaldadas: c.fechasDeudasSaldadas,
        periodoAbonadoStr: periodoAbonadoStr,
        periodoSaldoAFavorStr: periodoFavorStr,
        slogan: muni?.slogan,
      );
    }
  }

  Future<void> _compartirCobroIndividual(
    BuildContext context,
    WidgetRef ref,
    Local local,
    Cobro c,
  ) async {
    final user = ref.read(currentUsuarioProvider).value;
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    String? periodoFavorStr;
    final favorResultante = (c.nuevoSaldoFavor ?? 0).toDouble();
    final cuota = (c.cuotaDiaria ?? 0).toDouble();
    final fechasRes = c.fechasDeudasSaldadas ?? [];
    if (favorResultante > 0 && cuota > 0) {
      int dias = (favorResultante / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = (c.fecha ?? DateTime.now()).add(
          const Duration(days: 1),
        );
        if (fechasRes.isNotEmpty) {
          final sorted = List<DateTime>.from(fechasRes)..sort();
          inicioFavor = sorted.last.add(const Duration(days: 1));
        }
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
          inicioFavor,
          dias,
        );
      }
    }

    String? periodoAbonadoStr;
    if (fechasRes.isNotEmpty) {
      periodoAbonadoStr = DateRangeFormatter.formatearRangos(fechasRes);
    }

    final cuotaLocal = (c.cuotaDiaria ?? local.cuotaDiaria ?? 0).toDouble();
    double abonoCuotaHoy = (c.pagoACuota ?? 0).toDouble();
    double pagoHoy = cuotaLocal - abonoCuotaHoy;
    if (pagoHoy < 0) pagoHoy = 0;

    // El saldoPendiente guardado incluye la cuota del día no pagada.
    // Para el recibo, la "Deuda actual" solo debe reflejar deuda VENCIDA real.
    final saldoDeudaReal = ((c.saldoPendiente ?? 0).toDouble() - pagoHoy).clamp(0.0, double.infinity);

    if (context.mounted) {
      await ReceiptDispatcher.compartirPdf(
        context: context,
        local: local,
        monto: (c.monto != null && c.monto! > 0)
            ? c.monto!.toDouble()
            : (c.cuotaDiaria ?? 0).toDouble(),
        fecha: c.fecha ?? DateTime.now(),
        saldoPendiente: saldoDeudaReal,
        deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
        montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
        pagoHoy: pagoHoy > 0 ? pagoHoy : null,
        abonoCuotaHoy: abonoCuotaHoy > 0 ? abonoCuotaHoy : null,
        saldoAFavor: favorResultante,
        numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? '0'}',
        muni: muni?.nombre ?? 'MUNICIPALIDAD',
        merc: merc?.nombre,
        cobrador: user?.nombre,
        fechasSaldadas: c.fechasDeudasSaldadas,
        periodoAbonadoStr: periodoAbonadoStr,
        periodoSaldoAFavorStr: periodoFavorStr,
        slogan: muni?.slogan,
      );
    }
  }

  Future<void> _imprimirDiaEspecifico(
    BuildContext context,
    WidgetRef ref,
    Local local,
    Cobro c,
    DateTime fecha,
  ) async {
    final user = ref.read(currentUsuarioProvider).value;
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    double cuota = (c.cuotaDiaria ?? local.cuotaDiaria ?? 0).toDouble();
    double montoIndividual = cuota > 0 ? cuota : 0;
    final DateTime fechaOriginal = c.fecha ?? c.creadoEn ?? DateTime.now();
    
    final bool esElMismoDia = fecha.year == fechaOriginal.year &&
        fecha.month == fechaOriginal.month &&
        fecha.day == fechaOriginal.day;

    double deudaAnterior = (c.deudaAnterior ?? 0).toDouble();
    
    // El cobro maestro puede incluir la cuota del día no pagada en su saldoPendiente.
    // Hay que deducir esto del saldoPendiente a mostrar en CUALQUIER recibo hijo que salga de aquí.
    final abonoCuotaMaster = (c.pagoACuota ?? 0).toDouble();
    final faltaPagarHoyMaster = (montoIndividual - abonoCuotaMaster).clamp(0.0, double.infinity);
    final saldoPendienteReal = ((c.saldoPendiente ?? 0).toDouble() - faltaPagarHoyMaster).clamp(0.0, double.infinity);

    double abonoDeuda = 0;
    double pagoHoy = 0;
    double abonoCuotaHoy = 0;

    if (esElMismoDia) {
      // Si la fecha elegida es el día que se hizo el cobro real, 
      // mostramos la información general (o proporcional) de la deuda de ese día
      abonoDeuda = (c.montoAbonadoDeuda ?? 0).toDouble();
      abonoCuotaHoy = abonoCuotaMaster;
      pagoHoy = faltaPagarHoyMaster;
    } else {
      // Si es un día pendiente que se cubrió con este pago (en el pasado o futuro)
      // Todo ese dinero se fue como Abono de Deuda en concepto de cuota.
      abonoDeuda = montoIndividual;
    }

    if (context.mounted) {
      await ReceiptDispatcher.presentReceiptOptions(
        context: context,
        ref: ref,
        local: local,
        monto: abonoDeuda + pagoHoy,
        fecha: fechaOriginal,
        saldoPendiente: saldoPendienteReal,
        deudaAnterior: deudaAnterior,
        montoAbonadoDeuda: abonoDeuda,
        pagoHoy: pagoHoy > 0 ? pagoHoy : null,
        abonoCuotaHoy: abonoCuotaHoy > 0 ? abonoCuotaHoy : null,
        saldoAFavor: 0,
        numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? '0'}',
        municipalidadNombre: muni?.nombre ?? 'MUNICIPALIDAD',
        mercadoNombre: merc?.nombre,
        cobradorNombre: user?.nombre,
        fechasSaldadas: [fecha],
        periodoAbonadoStr: DateFormatter.formatDate(fecha),
        periodoSaldoAFavorStr: null,
        slogan: muni?.slogan,
      );
    }
  }

  Future<void> _compartirDiaEspecifico(
    BuildContext context,
    WidgetRef ref,
    Local local,
    Cobro c,
    DateTime fecha,
  ) async {
    final user = ref.read(currentUsuarioProvider).value;
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    double cuota = (c.cuotaDiaria ?? local.cuotaDiaria ?? 0).toDouble();
    double montoIndividual = cuota > 0 ? cuota : 0;
    final DateTime fechaOriginal = c.fecha ?? c.creadoEn ?? DateTime.now();
    
    final bool esElMismoDia = fecha.year == fechaOriginal.year &&
        fecha.month == fechaOriginal.month &&
        fecha.day == fechaOriginal.day;

    double deudaAnterior = (c.deudaAnterior ?? 0).toDouble();
    
    // El cobro maestro puede incluir la cuota del día no pagada en su saldoPendiente.
    // Hay que deducir esto del saldoPendiente a mostrar.
    final abonoCuotaMaster = (c.pagoACuota ?? 0).toDouble();
    final faltaPagarHoyMaster = (montoIndividual - abonoCuotaMaster).clamp(0.0, double.infinity);
    final saldoPendienteReal = ((c.saldoPendiente ?? 0).toDouble() - faltaPagarHoyMaster).clamp(0.0, double.infinity);

    double abonoDeuda = 0;
    double pagoHoy = 0;
    double abonoCuotaHoy = 0;

    if (esElMismoDia) {
      // Si la fecha elegida es el día que se hizo el cobro real, 
      abonoDeuda = (c.montoAbonadoDeuda ?? 0).toDouble();
      abonoCuotaHoy = abonoCuotaMaster;
      pagoHoy = faltaPagarHoyMaster;
    } else {
      // Si es un día pendiente que se cubrió con este pago (pasado o futuro retrasado)
      // Todo ese dinero se fue como Abono de Deuda para esta fecha específica.
      abonoDeuda = montoIndividual;
    }

    if (context.mounted) {
      await ReceiptDispatcher.compartirPdf(
        context: context,
        local: local,
        monto: abonoDeuda + pagoHoy,
        fecha: fechaOriginal,
        saldoPendiente: saldoPendienteReal,
        deudaAnterior: deudaAnterior,
        montoAbonadoDeuda: abonoDeuda,
        pagoHoy: pagoHoy > 0 ? pagoHoy : null,
        abonoCuotaHoy: abonoCuotaHoy > 0 ? abonoCuotaHoy : null,
        saldoAFavor: 0,
        numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? '0'}',
        muni: muni?.nombre ?? 'MUNICIPALIDAD',
        merc: merc?.nombre,
        cobrador: user?.nombre,
        fechasSaldadas: [fecha],
        periodoAbonadoStr: DateFormatter.formatDate(fecha),
        periodoSaldoAFavorStr: null,
        slogan: muni?.slogan,
      );
    }
  }
}

/// Card colapsable que agrupa cobros por boleta única y despliega todas las fechas que abarca (pasado, presente y futuro)
class _GrupoBoletaCard extends ConsumerWidget {
  final List<Cobro> cobros;
  final Local local;
  final Cobro? masterPayment;
  final Future<void> Function(BuildContext, WidgetRef, Cobro, DateTime) onImprimirCobro;
  final Future<void> Function(BuildContext, WidgetRef, Cobro, DateTime) onCompartirCobro;

  const _GrupoBoletaCard({
    required this.cobros,
    required this.local,
    this.masterPayment,
    required this.onImprimirCobro,
    required this.onCompartirCobro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Recolectar TODAS las fechas involucradas en esta transacción
    final Set<DateTime> fechasExtraidas = {};
    final Map<DateTime, Cobro> cobroPorFecha = {};
    final Map<DateTime, int> prioridadPorFecha = {};
    void registrarCobro(DateTime fecha, Cobro cobro, int prioridad) {
      final normalizada = _normalizarDia(fecha);
      final prioridadActual = prioridadPorFecha[normalizada];
      if (prioridadActual == null || prioridad < prioridadActual) {
        cobroPorFecha[normalizada] = cobro;
        prioridadPorFecha[normalizada] = prioridad;
      }
      fechasExtraidas.add(normalizada);
    }

    for (final c in cobros) {
      if (c.fecha != null) {
        registrarCobro(c.fecha!, c, 0);
      }
      if (c.fechasDeudasSaldadas != null) {
        for (final d in c.fechasDeudasSaldadas!) {
          registrarCobro(d, c, 1);
        }
      }
      final bool aplicoCuotaHoy = (c.pagoACuota ?? 0) > 0;
      if (aplicoCuotaHoy && c.creadoEn != null) {
        registrarCobro(c.creadoEn!, c, 2);
      }

      // Expandir fechas futuras por saldo a favor (si aplica)
      final favor = (c.nuevoSaldoFavor ?? 0).toDouble();
      final cuota = (c.cuotaDiaria ?? local.cuotaDiaria ?? 0).toDouble();
      if (favor > 0 && cuota > 0) {
        int diasAdelantados = (favor / cuota).floor();
        if (diasAdelantados > 0) {
          DateTime base = c.creadoEn ?? DateTime.now();
          if (c.fechasDeudasSaldadas != null &&
              c.fechasDeudasSaldadas!.isNotEmpty) {
            final sorted = List<DateTime>.from(c.fechasDeudasSaldadas!)..sort();
            base = sorted.last;
          }
          final Cobro fuente = masterPayment ?? c;
          for (int i = 1; i <= diasAdelantados; i++) {
            final futura = base.add(Duration(days: i));
            registrarCobro(futura, fuente, 3);
          }
        }
      }
    }

    final List<DateTime> fechasOrdenadas = fechasExtraidas.toList()..sort();
    final rangoStr = DateRangeFormatter.formatearRangos(fechasOrdenadas) ?? '-';

    double montoDisplay = masterPayment != null
        ? (masterPayment!.monto ?? 0).toDouble()
        : 0.0;
    if (montoDisplay <= 0) {
      montoDisplay = cobros.fold<double>(
        0,
        (sum, c) => sum + (c.monto ?? 0).toDouble(),
      );
      if (montoDisplay <= 0) {
        montoDisplay =
            (local.cuotaDiaria ?? 0).toDouble() * fechasOrdenadas.length;
      }
    }

    final String numeroRecibo =
        masterPayment?.numeroBoleta ??
        masterPayment?.correlativo?.toString() ??
        '-';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
          title: Text(
            numeroRecibo != '-' ? 'Boleta #$numeroRecibo' : 'Recibo agrupado',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${fechasOrdenadas.length} cuotas cubiertas · ${DateFormatter.formatCurrency(montoDisplay)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rangoStr.length > 15 && fechasOrdenadas.length > 2
                  ? '${fechasOrdenadas.length} días'
                  : rangoStr,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          children: [
            ...fechasOrdenadas.map((fecha) {
              final fechaStr =
                  '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fechaStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.74),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormatter.formatCurrency((local.cuotaDiaria ?? 0)),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _imprimirResumenGrupo(
                  context,
                  ref,
                  rangoStr,
                  montoDisplay,
                  fechasOrdenadas,
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text(
                  'Imprimir Boleta Completa',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _compartirResumenGrupo(
                  context,
                  ref,
                  rangoStr,
                  montoDisplay,
                  fechasOrdenadas,
                ),
                icon: const Icon(
                  Icons.share_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                label: const Text(
                  'Compartir PDF',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.success, width: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _mostrarSelectorFecha(
                  context,
                  ref,
                  rangoStr,
                  montoDisplay,
                  fechasOrdenadas,
                  cobroPorFecha,
                ),
                icon: const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                label: const Text(
                  'Elegir fecha para imprimir/compartir',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.success.withValues(alpha: 0.7),
                    width: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorFecha(
    BuildContext context,
    WidgetRef ref,
    String rangoStr,
    double montoTotalFallBack,
    List<DateTime> fechas,
    Map<DateTime, Cobro> cobroPorFecha,
  ) {
    if (fechas.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 12,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Seleccionar fecha',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Imprime o comparte el día específico dentro de esta boleta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: fechas.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                    itemBuilder: (sheetContext, index) {
                      final fecha = fechas[index];
                      final fechaStr = DateFormatter.formatDate(fecha);
                      final fechaCobro = cobroPorFecha[fecha];
                      final montoFecha = _montoEstimadoCobro(fechaCobro);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.success,
                        ),
                        title: Text(
                          fechaStr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        subtitle: Text(
                          'Abono: ${DateFormatter.formatCurrency(montoFecha)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.58),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_rounded),
                              color: AppColors.success,
                              tooltip: 'Imprimir fecha seleccionada',
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                await _imprimirFechaEspecifica(
                                  context,
                                  ref,
                                  fecha,
                                  fechaCobro,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_rounded),
                              color: AppColors.success,
                              tooltip: 'Compartir fecha seleccionada',
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                await _compartirFechaEspecifica(
                                  context,
                                  ref,
                                  fecha,
                                  fechaCobro,
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Cerrar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  DateTime _normalizarDia(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  Future<void> _imprimirFechaEspecifica(
    BuildContext context,
    WidgetRef ref,
    DateTime fecha,
    Cobro? cobro,
  ) async {
    if (cobro != null) {
      await onImprimirCobro(context, ref, cobro, fecha);
      return;
    }
    _mostrarFechaSinRegistro(context, fecha);
  }

  Future<void> _compartirFechaEspecifica(
    BuildContext context,
    WidgetRef ref,
    DateTime fecha,
    Cobro? cobro,
  ) async {
    if (cobro != null) {
      await onCompartirCobro(context, ref, cobro, fecha);
      return;
    }
    _mostrarFechaSinRegistro(context, fecha);
  }

  void _mostrarFechaSinRegistro(BuildContext context, DateTime fecha) {
    final fechaStr = DateFormatter.formatDate(fecha);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No hay datos asociados al $fechaStr'),
      ),
    );
  }

  double _montoEstimadoCobro(Cobro? cobro) {
    if (cobro == null) return (local.cuotaDiaria ?? 0).toDouble();
    if (cobro.monto != null && cobro.monto! > 0) {
      return cobro.monto!.toDouble();
    }
    final cuota = cobro.cuotaDiaria;
    if (cuota != null && cuota > 0) {
      return cuota.toDouble();
    }
    return (local.cuotaDiaria ?? 0).toDouble();
  }

  Future<void> _imprimirResumenGrupo(
    BuildContext context,
    WidgetRef ref,
    String rangoStr,
    double montoTotalFallBack,
    List<DateTime> fechas, {
    DateTime? fechaHijo,
  }) async {
    final user = ref.read(currentUsuarioProvider).value;
    final printer = ref.read(printerServiceProvider);
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    final cobrosOrdenados = List<Cobro>.from(cobros)
      ..sort(
        (a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0)),
      );

    final primerCobro = cobrosOrdenados.first;
    final ultimoCobro = cobrosOrdenados.last;

    double deudaAnterior = masterPayment != null
        ? (masterPayment!.deudaAnterior ?? 0).toDouble()
        : (primerCobro.deudaAnterior ?? 0).toDouble();
    double saldoPendiente = masterPayment != null
        ? (masterPayment!.saldoPendiente ?? 0).toDouble()
        : (ultimoCobro.saldoPendiente ?? 0).toDouble();
    double saldoAFavor = masterPayment != null
        ? (masterPayment!.nuevoSaldoFavor ?? 0).toDouble()
        : (ultimoCobro.nuevoSaldoFavor ?? 0).toDouble();

    double montoAbonadoDeuda = 0.0;
    double montoCobradoFisico = 0.0;

    if (masterPayment != null) {
      montoAbonadoDeuda = (masterPayment!.montoAbonadoDeuda ?? 0).toDouble();
      montoCobradoFisico = (masterPayment!.monto ?? 0).toDouble();
    } else {
      for (var c in cobrosOrdenados) {
        montoAbonadoDeuda += (c.montoAbonadoDeuda ?? 0).toDouble();
        montoCobradoFisico += (c.monto ?? 0).toDouble();
      }
    }

    double montoImprimir = (montoCobradoFisico > 0)
        ? montoCobradoFisico
        : montoTotalFallBack;
    // Último respaldo: usar cuota diaria del local × cantidad de días
    if (montoImprimir <= 0) {
      montoImprimir = (local.cuotaDiaria ?? 0).toDouble() * cobros.length;
    }

    // SAFEGUARD: Reconstruir matemáticamente para obligar al PDF a dibujar el bloque de deuda como espera el usuario
    if (montoAbonadoDeuda <= 0) {
      montoAbonadoDeuda = montoImprimir;
    }
    if (deudaAnterior < montoAbonadoDeuda) {
      deudaAnterior = montoAbonadoDeuda + saldoPendiente;
    }

    String boleta = masterPayment != null
        ? (masterPayment!.numeroBoleta ??
              masterPayment!.correlativo?.toString() ??
              '0')
        : (primerCobro.numeroBoleta ??
              primerCobro.correlativo?.toString() ??
              '0');
    DateTime baseFecha = masterPayment != null
        ? (masterPayment!.fecha ?? DateTime.now())
        : (primerCobro.creadoEn ?? DateTime.now());
    DateTime fechaImprimir = fechaHijo ?? baseFecha;

    String? periodoFavorStr;
    final cuotaLocal = (local.cuotaDiaria ?? 0).toDouble();
    
    double abonoCuotaHoy = 0;
    final hoy = DateTime.now();
    for (var c in cobros) {
      final f = c.fecha ?? c.creadoEn;
      if (f != null &&
          f.year == hoy.year &&
          f.month == hoy.month &&
          f.day == hoy.day) {
        abonoCuotaHoy += (c.pagoACuota ?? 0).toDouble();
      }
    }
    double pagoHoy = cuotaLocal - abonoCuotaHoy;
    if (pagoHoy < 0) pagoHoy = 0;

    // Descontar la cuota de hoy del saldo pendiente, ya que no es deuda real vencida
    final saldoDeudaReal = (saldoPendiente - pagoHoy).clamp(0.0, double.infinity);

    if (saldoAFavor > 0 && cuotaLocal > 0) {
      int dias = (saldoAFavor / cuotaLocal).floor();
      if (dias > 0) {
        DateTime inicioFavor = fechaImprimir.add(const Duration(days: 1));
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
          inicioFavor,
          dias,
        );
      }
    }

    await printer.printReceipt(
      empresa: muni?.nombre ?? 'MUNICIPALIDAD',
      mercado: merc?.nombre ?? 'MERCADO',
      local: local.nombreSocial ?? 'Local',
      monto: montoImprimir,
      fecha: fechaImprimir,
      numeroBoleta: boleta,
      anioCorrelativo: fechaImprimir.year,
      cobrador: user?.nombre ?? 'Cobrador',
      saldoPendiente: saldoDeudaReal,
      deudaAnterior: deudaAnterior,
      montoAbonadoDeuda: montoAbonadoDeuda,
      pagoHoy: pagoHoy > 0 ? pagoHoy : null,
      abonoCuotaHoy: abonoCuotaHoy > 0 ? abonoCuotaHoy : null,
      saldoAFavor: saldoAFavor,
      periodoAbonadoStr: rangoStr,
      periodoSaldoAFavorStr: periodoFavorStr,
      fechasSaldadas: fechas,
      slogan: muni?.slogan,
      clave: local.clave,
      codigoLocal: local.codigo,
      codigoCatastral: local.codigoCatastral,
    );
  }

  Future<void> _compartirResumenGrupo(
    BuildContext context,
    WidgetRef ref,
    String rangoStr,
    double montoTotalFallBack,
    List<DateTime> fechas, {
    DateTime? fechaHijo,
  }) async {
    final user = ref.read(currentUsuarioProvider).value;
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    final cobrosOrdenados = List<Cobro>.from(cobros)
      ..sort(
        (a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0)),
      );

    final primerCobro = cobrosOrdenados.first;
    final ultimoCobro = cobrosOrdenados.last;

    double deudaAnterior = masterPayment != null
        ? (masterPayment!.deudaAnterior ?? 0).toDouble()
        : (primerCobro.deudaAnterior ?? 0).toDouble();
    double saldoPendiente = masterPayment != null
        ? (masterPayment!.saldoPendiente ?? 0).toDouble()
        : (ultimoCobro.saldoPendiente ?? 0).toDouble();
    double saldoAFavor = masterPayment != null
        ? (masterPayment!.nuevoSaldoFavor ?? 0).toDouble()
        : (ultimoCobro.nuevoSaldoFavor ?? 0).toDouble();

    double montoAbonadoDeuda = 0.0;
    double montoCobradoFisico = 0.0;

    if (masterPayment != null) {
      montoAbonadoDeuda = (masterPayment!.montoAbonadoDeuda ?? 0).toDouble();
      montoCobradoFisico = (masterPayment!.monto ?? 0).toDouble();
    } else {
      for (var c in cobrosOrdenados) {
        montoAbonadoDeuda += (c.montoAbonadoDeuda ?? 0).toDouble();
        montoCobradoFisico += (c.monto ?? 0).toDouble();
      }
    }

    double montoImprimir = (montoCobradoFisico > 0)
        ? montoCobradoFisico
        : montoTotalFallBack;
    // Último respaldo: usar cuota diaria del local × cantidad de días
    if (montoImprimir <= 0) {
      montoImprimir = (local.cuotaDiaria ?? 0).toDouble() * cobros.length;
    }

    // SAFEGUARD: Reconstruir matemáticamente para obligar al PDF a dibujar el bloque de deuda como espera el usuario
    if (montoAbonadoDeuda <= 0) {
      montoAbonadoDeuda = montoImprimir;
    }
    if (deudaAnterior < montoAbonadoDeuda) {
      deudaAnterior = montoAbonadoDeuda + saldoPendiente;
    }

    String boleta = masterPayment != null
        ? (masterPayment!.numeroBoleta ??
              masterPayment!.correlativo?.toString() ??
              '0')
        : (primerCobro.numeroBoleta ??
              primerCobro.correlativo?.toString() ??
              '0');
    DateTime baseFecha = masterPayment != null
        ? (masterPayment!.fecha ?? DateTime.now())
        : (primerCobro.creadoEn ?? DateTime.now());
    DateTime fechaImprimir = fechaHijo ?? baseFecha;

    String? periodoFavorStr;
    final cuotaLocal = (local.cuotaDiaria ?? 0).toDouble();

    double abonoCuotaHoy = 0;
    final hoy = DateTime.now();
    for (var c in cobros) {
      final f = c.fecha ?? c.creadoEn;
      if (f != null &&
          f.year == hoy.year &&
          f.month == hoy.month &&
          f.day == hoy.day) {
        abonoCuotaHoy += (c.pagoACuota ?? 0).toDouble();
      }
    }
    double pagoHoy = cuotaLocal - abonoCuotaHoy;
    if (pagoHoy < 0) pagoHoy = 0;

    // Descontar la cuota de hoy del saldo pendiente, ya que no es deuda real vencida
    final saldoDeudaReal = (saldoPendiente - pagoHoy).clamp(0.0, double.infinity);

    if (saldoAFavor > 0 && cuotaLocal > 0) {
      int dias = (saldoAFavor / cuotaLocal).floor();
      if (dias > 0) {
        DateTime inicioFavor = fechaImprimir.add(const Duration(days: 1));
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
          inicioFavor,
          dias,
        );
      }
    }

    if (context.mounted) {
      await ReceiptDispatcher.compartirPdf(
        context: context,
        local: local,
        monto: montoImprimir,
        fecha: fechaImprimir,
        saldoPendiente: saldoDeudaReal,
        deudaAnterior: deudaAnterior,
        montoAbonadoDeuda: montoAbonadoDeuda,
        pagoHoy: pagoHoy > 0 ? pagoHoy : null,
        abonoCuotaHoy: abonoCuotaHoy > 0 ? abonoCuotaHoy : null,
        saldoAFavor: saldoAFavor,
        numeroBoleta: boleta,
        muni: muni?.nombre ?? 'MUNICIPALIDAD',
        merc: merc?.nombre,
        cobrador: user?.nombre,
        fechasSaldadas: fechas,
        periodoAbonadoStr: rangoStr,
        periodoSaldoAFavorStr: periodoFavorStr,
        slogan: muni?.slogan,
      );
    }
  }

  // Las funciones _mostrarSelectorFechaPdf, _reimprimirHijo y _compartirHijo han sido eliminadas
  // ya que ahora se utiliza la vista agrupada por boleta completa.
}

class _CobroTile extends ConsumerWidget {
  final Cobro cobro;
  final Local local;
  final Function(BuildContext, WidgetRef, Cobro) onReprint;
  final Function(BuildContext, WidgetRef, Cobro) onShare;

  const _CobroTile({
    required this.cobro,
    required this.local,
    required this.onReprint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = cobro.estado ?? 'desconocido';

    final Color color;
    final IconData icon;
    final String label;

    final esPagadoConSaldoAFavor =
        estado == 'cobrado' && (cobro.monto == null || cobro.monto == 0);

    switch (estado) {
      case 'cobrado':
        if (esPagadoConSaldoAFavor) {
          color = AppColors.success;
          icon = Icons.savings_rounded;
          label = 'Saldo a Favor';
        } else {
          color = AppColors.success;
          icon = Icons.check_circle_rounded;
          label = 'Cobrado';
        }
      case 'pendiente':
        color = AppColors.danger;
        icon = Icons.cancel_rounded;
        label = 'Pendiente';
      case 'abono_parcial':
        color = AppColors.warning;
        icon = Icons.timelapse_rounded;
        label = 'Abono';
      case 'adelantado':
        color = AppColors.warning;
        icon = Icons.fast_forward_rounded;
        label = 'Adelantado';
      default:
        color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);
        icon = Icons.help_outline_rounded;
        label = estado;
    }

    final esPendiente = estado == 'pendiente';
    final esAdelantado = estado == 'adelantado';

    num monto = esPendiente ? (cobro.saldoPendiente ?? 0) : (cobro.monto ?? 0);
    if (esPagadoConSaldoAFavor) {
      monto = cobro.pagoACuota ?? cobro.cuotaDiaria ?? 0;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _mostrarDetalles(context, ref, color, esPagadoConSaldoAFavor),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: esAdelantado
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: esAdelantado ? 0.3 : 0.15),
              width: esAdelantado ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cobro.fecha != null
                          ? DateFormatter.formatDateTime(cobro.fecha!)
                          : '—',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (cobro.observaciones != null &&
                        cobro.observaciones!.isNotEmpty)
                      Text(
                        cobro.observaciones!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    else if (esPagadoConSaldoAFavor)
                      Text(
                        'Cuota cubierta automáticamente con saldo a favor',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormatter.formatCurrency(monto),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: esPendiente
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(
    BuildContext context,
    WidgetRef ref,
    Color colorEstado,
    bool esPagadoConSaldoAFavor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalles del Cobro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetalleFila(
                label: 'Fecha',
                valor: cobro.fecha != null
                    ? DateFormatter.formatDateTime(cobro.fecha!)
                    : '-',
              ),
              if (esPagadoConSaldoAFavor) ...[
                _DetalleFila(
                  label: 'Monto Recibido',
                  valor: DateFormatter.formatCurrency(0),
                ),
                _DetalleFila(
                  label: 'Cubierto con Saldo a Favor',
                  valor: DateFormatter.formatCurrency(
                    cobro.pagoACuota ?? cobro.cuotaDiaria ?? 0,
                  ),
                ),
              ] else ...[
                _DetalleFila(
                  label: 'Monto Pagado',
                  valor: DateFormatter.formatCurrency(cobro.monto),
                ),
              ],
              _DetalleFila(
                label: 'Saldo Pendiente Posterior',
                valor: DateFormatter.formatCurrency(cobro.saldoPendiente),
              ),
              if (cobro.observaciones != null &&
                  cobro.observaciones!.isNotEmpty)
                _DetalleFila(
                  label: 'Observaciones',
                  valor: cobro.observaciones!,
                )
              else if (esPagadoConSaldoAFavor)
                const _DetalleFila(
                  label: 'Observaciones',
                  valor: 'Cuota cubierta automáticamente con saldo a favor',
                ),
              if (cobro.correlativo != null)
                _DetalleFila(
                  label: 'Correlativo',
                  valor: '${cobro.correlativo}',
                ),
              const SizedBox(height: 24),
              if (cobro.estado != 'adelantado' &&
                  !(cobro.id?.startsWith('VIRTUAL') ?? false))
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      onReprint(context, ref, cobro);
                    },
                    icon: const Icon(Icons.print_rounded),
                    label: const Text(
                      'Reimprimir Boleta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorEstado.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (cobro.estado != 'adelantado' &&
                  !(cobro.id?.startsWith('VIRTUAL') ?? false)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      onShare(context, ref, cobro);
                    },
                    icon: const Icon(
                      Icons.share_rounded,
                      color: AppColors.success,
                    ),
                    label: const Text(
                      'Compartir por WhatsApp (PDF)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.success),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else
                Center(
                  child: Text(
                    'Este es un registro generado automáticamente y no posee boleta física.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetalleFila extends StatelessWidget {
  final String label;
  final String valor;

  const _DetalleFila({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
