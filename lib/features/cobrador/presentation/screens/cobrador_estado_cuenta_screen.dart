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
    final balanceVisual = VisualDebtUtils.calcularBalanceNetoVisual(local, cobrosList);
    final numAdelantados = adelantadosVirtuales.length;

    final cobrados = combinedList.where((c) => c.estado == 'cobrado').toList();
    final pendientes = combinedList.where((c) => c.estado == 'pendiente').toList();

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
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                    colors: [Theme.of(context).colorScheme.primary, AppColors.success],
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: balance >= 0
                    ? AppColors.success
                    : AppColors.danger,
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(width: 8),
              _MiniKpi(
                label: 'Deuda',
                value: DateFormatter.formatCurrency(deuda),
                color: deuda > 0 ? AppColors.danger : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 8),
              _MiniKpi(
                label: 'Días Adel.',
                value: '$numAdelantados',
                color: numAdelantados > 0
                    ? AppColors.warning
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
              style: TextStyle(fontSize: 8, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
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

  /// Agrupa cobros consecutivos que digan "Saldado por abono general" en un solo item.
  List<dynamic> _agruparSaldados(List<Cobro> lista) {
    final result = <dynamic>[];
    int i = 0;
    while (i < lista.length) {
      if (_esSaldadoPorAbono(lista[i])) {
        final grupo = <Cobro>[lista[i]];
        while (i + 1 < lista.length && _esSaldadoPorAbono(lista[i + 1])) {
          i++;
          grupo.add(lista[i]);
        }
        if (grupo.length >= 2) {
          result.add(grupo);
        } else {
          result.add(grupo.first);
        }
      } else {
        result.add(lista[i]);
      }
      i++;
    }
    return result;
  }

  bool _esSaldadoPorAbono(Cobro c) {
    if (c.observaciones == null) return false;
    final obsLower = c.observaciones!.toLowerCase();
    return obsLower.contains('saldado por abono general');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cobros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
            const SizedBox(height: 12),
            Text(
              'Sin registros',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final items = _agruparSaldados(cobros);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is List<Cobro>) {
          Cobro? masterPayment;
          final groupDates = item.where((c) => c.fecha != null).map((c) => DateUtils.dateOnly(c.fecha!)).toSet();
          
          for (final c in cobros) {
            if (c.fechasDeudasSaldadas != null && c.fechasDeudasSaldadas!.isNotEmpty) {
              final masterDates = c.fechasDeudasSaldadas!.map((d) => DateUtils.dateOnly(d)).toSet();
              if (masterDates.containsAll(groupDates)) {
                masterPayment = c;
                break;
              }
            }
          }

          if (masterPayment == null) {
            final sum = item.fold<double>(0, (s, c) => s + ((c.cuotaDiaria ?? c.monto ?? 0).toDouble()));
            for (final c in cobros) {
              if (c.monto != null && c.monto == sum && !item.contains(c)) {
                if (c.fecha != null && item.last.fecha != null && (c.fecha!.isAfter(item.first.fecha!) || c.fecha!.isAtSameMomentAs(item.last.fecha!))) {
                  masterPayment = c;
                  break;
                }
              }
            }
          }

          return _GrupoSaldadoCard(cobros: item, local: local, masterPayment: masterPayment);
        }
        return _CobroTile(
          cobro: item as Cobro,
          local: local,
          onReprint: (ctx, ref, c) => _reimprimirCobroIndividual(ctx, ref, local, c),
          onShare: (ctx, ref, c) => _compartirCobroIndividual(ctx, ref, local, c),
        );
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

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    String? periodoFavorStr;
    final favorResultante = (c.nuevoSaldoFavor ?? 0).toDouble();
    final cuota = (c.cuotaDiaria ?? 0).toDouble();
    final fechasRes = c.fechasDeudasSaldadas ?? [];
    if (favorResultante > 0 && cuota > 0) {
      int dias = (favorResultante / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = (c.fecha ?? DateTime.now()).add(const Duration(days: 1));
        if (fechasRes.isNotEmpty) {
          final sorted = List<DateTime>.from(fechasRes)..sort();
          inicioFavor = sorted.last.add(const Duration(days: 1));
        }
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
      }
    }

    String? periodoAbonadoStr;
    if (fechasRes.isNotEmpty) {
      periodoAbonadoStr = DateRangeFormatter.formatearRangos(fechasRes);
    }

    if (context.mounted) {
      await ReceiptDispatcher.presentReceiptOptions(
        context: context,
        ref: ref,
        local: local,
        monto: (c.monto != null && c.monto! > 0) ? c.monto!.toDouble() : (c.cuotaDiaria ?? 0).toDouble(),
        fecha: c.fecha ?? DateTime.now(),
        saldoPendiente: (c.saldoPendiente ?? 0).toDouble(),
        deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
        montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
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

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    String? periodoFavorStr;
    final favorResultante = (c.nuevoSaldoFavor ?? 0).toDouble();
    final cuota = (c.cuotaDiaria ?? 0).toDouble();
    final fechasRes = c.fechasDeudasSaldadas ?? [];
    if (favorResultante > 0 && cuota > 0) {
      int dias = (favorResultante / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = (c.fecha ?? DateTime.now()).add(const Duration(days: 1));
        if (fechasRes.isNotEmpty) {
          final sorted = List<DateTime>.from(fechasRes)..sort();
          inicioFavor = sorted.last.add(const Duration(days: 1));
        }
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
      }
    }

    String? periodoAbonadoStr;
    if (fechasRes.isNotEmpty) {
      periodoAbonadoStr = DateRangeFormatter.formatearRangos(fechasRes);
    }

    if (context.mounted) {
      await ReceiptDispatcher.compartirPdf(
        context: context,
        local: local,
        monto: (c.monto != null && c.monto! > 0) ? c.monto!.toDouble() : (c.cuotaDiaria ?? 0).toDouble(),
        fecha: c.fecha ?? DateTime.now(),
        saldoPendiente: (c.saldoPendiente ?? 0).toDouble(),
        deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
        montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
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
}

/// Card colapsable que agrupa cobros saldados consecutivos
class _GrupoSaldadoCard extends ConsumerWidget {
  final List<Cobro> cobros;
  final Local local;
  final Cobro? masterPayment;

  const _GrupoSaldadoCard({required this.cobros, required this.local, this.masterPayment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fechas = cobros
        .where((c) => c.fecha != null)
        .map((c) => c.fecha!)
        .toList()
      ..sort();

    final rangoStr = DateRangeFormatter.formatearRangos(fechas) ?? '-';
    final montoTotal = cobros.fold<double>(
      0,
      (sum, c) => sum + ((c.cuotaDiaria ?? c.monto ?? 0).toDouble()),
    );
    // Fallback: si los registros no tienen cuotaDiaria ni monto, usar la cuota del local
    final montoDisplay = montoTotal > 0
        ? montoTotal
        : (local.cuotaDiaria ?? 0).toDouble() * cobros.length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.25),
        ),
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
            child: const Icon(Icons.playlist_add_check_rounded, color: AppColors.success, size: 20),
          ),
          title: Text(
            rangoStr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${cobros.length} dias saldados por abono · ${DateFormatter.formatCurrency(montoDisplay)}',
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${cobros.length} dias',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          children: [
            ...cobros.map((c) {
              final fechaStr = c.fecha != null
                  ? '${c.fecha!.day.toString().padLeft(2, '0')}/${c.fecha!.month.toString().padLeft(2, '0')}/${c.fecha!.year}'
                  : '-';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      fechaStr,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                    ),
                    const Spacer(),
                    Text(
                      DateFormatter.formatCurrency(
                        (c.cuotaDiaria != null && c.cuotaDiaria! > 0) 
                          ? c.cuotaDiaria! 
                          : (c.monto != null && c.monto! > 0) 
                            ? c.monto! 
                            : (local.cuotaDiaria ?? 0)
                      ),
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _imprimirResumenGrupo(context, ref, rangoStr, montoDisplay, fechas),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text(
                  'Imprimir Resumen (Térmica)',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _compartirResumenGrupo(context, ref, rangoStr, montoDisplay, fechas),
                icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.success),
                label: const Text(
                  'Compartir Resumen (PDF)',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.success, width: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => _mostrarSelectorFechaPdf(context, ref, cobros),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.format_list_bulleted_rounded, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Ver Opciones por Día (Imprimir / Compartir)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    final cobrosOrdenados = List<Cobro>.from(cobros)
      ..sort((a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0)));

    final primerCobro = cobrosOrdenados.first;
    final ultimoCobro = cobrosOrdenados.last;

    double deudaAnterior = masterPayment != null ? (masterPayment!.deudaAnterior ?? 0).toDouble() : (primerCobro.deudaAnterior ?? 0).toDouble();
    double saldoPendiente = masterPayment != null ? (masterPayment!.saldoPendiente ?? 0).toDouble() : (ultimoCobro.saldoPendiente ?? 0).toDouble();
    double saldoAFavor = masterPayment != null ? (masterPayment!.nuevoSaldoFavor ?? 0).toDouble() : (ultimoCobro.nuevoSaldoFavor ?? 0).toDouble();
    
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
    
    double montoImprimir = (montoCobradoFisico > 0) ? montoCobradoFisico : montoTotalFallBack;
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

    String boleta = masterPayment != null ? (masterPayment!.numeroBoleta ?? masterPayment!.correlativo?.toString() ?? '0') : (primerCobro.numeroBoleta ?? primerCobro.correlativo?.toString() ?? '0');
    DateTime baseFecha = masterPayment != null ? (masterPayment!.fecha ?? DateTime.now()) : (primerCobro.creadoEn ?? DateTime.now());
    DateTime fechaImprimir = fechaHijo ?? baseFecha;

    String? periodoFavorStr;
    final cuota = (local.cuotaDiaria ?? 0).toDouble();
    if (saldoAFavor > 0 && cuota > 0) {
      int dias = (saldoAFavor / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = fechaImprimir.add(const Duration(days: 1));
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
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
      saldoPendiente: saldoPendiente,
      deudaAnterior: deudaAnterior,
      montoAbonadoDeuda: montoAbonadoDeuda,
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

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    final cobrosOrdenados = List<Cobro>.from(cobros)
      ..sort((a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0)));

    final primerCobro = cobrosOrdenados.first;
    final ultimoCobro = cobrosOrdenados.last;

    double deudaAnterior = masterPayment != null ? (masterPayment!.deudaAnterior ?? 0).toDouble() : (primerCobro.deudaAnterior ?? 0).toDouble();
    double saldoPendiente = masterPayment != null ? (masterPayment!.saldoPendiente ?? 0).toDouble() : (ultimoCobro.saldoPendiente ?? 0).toDouble();
    double saldoAFavor = masterPayment != null ? (masterPayment!.nuevoSaldoFavor ?? 0).toDouble() : (ultimoCobro.nuevoSaldoFavor ?? 0).toDouble();
    
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
    
    double montoImprimir = (montoCobradoFisico > 0) ? montoCobradoFisico : montoTotalFallBack;
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

    String boleta = masterPayment != null ? (masterPayment!.numeroBoleta ?? masterPayment!.correlativo?.toString() ?? '0') : (primerCobro.numeroBoleta ?? primerCobro.correlativo?.toString() ?? '0');
    DateTime baseFecha = masterPayment != null ? (masterPayment!.fecha ?? DateTime.now()) : (primerCobro.creadoEn ?? DateTime.now());
    DateTime fechaImprimir = fechaHijo ?? baseFecha;

    String? periodoFavorStr;
    final cuota = (local.cuotaDiaria ?? 0).toDouble();
    if (saldoAFavor > 0 && cuota > 0) {
      int dias = (saldoAFavor / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = fechaImprimir.add(const Duration(days: 1));
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
      }
    }

    if (context.mounted) {
      await ReceiptDispatcher.compartirPdf(
        context: context,
        local: local,
        monto: montoImprimir,
        fecha: fechaImprimir,
        saldoPendiente: saldoPendiente,
        deudaAnterior: deudaAnterior,
        montoAbonadoDeuda: montoAbonadoDeuda,
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

  void _mostrarSelectorFechaPdf(BuildContext context, WidgetRef ref, List<Cobro> listaCobros) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar Fecha',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Elige el día para reimprimir o compartir',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: listaCobros.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                  itemBuilder: (ctx, i) {
                    final c = listaCobros[i];
                    final fechaStr = c.fecha != null
                        ? '${c.fecha!.day.toString().padLeft(2, '0')}/${c.fecha!.month.toString().padLeft(2, '0')}/${c.fecha!.year}'
                        : 'Fecha desconocida';
                    final cuotaAct = (c.monto != null && c.monto! > 0)
                        ? c.monto!.toDouble()
                        : (c.cuotaDiaria != null && c.cuotaDiaria! > 0)
                          ? c.cuotaDiaria!.toDouble()
                          : (local.cuotaDiaria ?? 0).toDouble();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.success.withValues(alpha: 0.1),
                        child: const Icon(Icons.check, color: AppColors.success, size: 20),
                      ),
                      title: Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Abono: ${DateFormatter.formatCurrency(cuotaAct)}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print_rounded, size: 18),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _reimprimirHijo(context, ref, c);
                            },
                            tooltip: 'Imprimir',
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_rounded, size: 18),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _compartirHijo(context, ref, c);
                            },
                            tooltip: 'Compartir PDF',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reimprimirHijo(BuildContext context, WidgetRef ref, Cobro c) async {
    final user = ref.read(currentUsuarioProvider).value;
    final printer = ref.read(printerServiceProvider);
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    String? periodoFavorStr;
    final favorResultante = (c.nuevoSaldoFavor ?? 0).toDouble();
    final cuota = (c.cuotaDiaria ?? 0).toDouble();
    final fechasRes = c.fechasDeudasSaldadas ?? [];
    if (favorResultante > 0 && cuota > 0) {
      int dias = (favorResultante / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = (c.fecha ?? DateTime.now()).add(const Duration(days: 1));
        if (fechasRes.isNotEmpty) {
          final sorted = List<DateTime>.from(fechasRes)..sort();
          inicioFavor = sorted.last.add(const Duration(days: 1));
        }
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
      }
    }

    String? periodoAbonadoStr;
    if (fechasRes.isNotEmpty) {
      periodoAbonadoStr = DateRangeFormatter.formatearRangos(fechasRes);
    }

    double montoHijo = (c.monto != null && c.monto! > 0)
        ? c.monto!.toDouble()
        : (c.cuotaDiaria != null && c.cuotaDiaria! > 0)
            ? c.cuotaDiaria!.toDouble()
            : (local.cuotaDiaria ?? 0).toDouble();

    await printer.printReceipt(
      empresa: muni?.nombre ?? 'MUNICIPALIDAD',
      mercado: merc?.nombre ?? 'MERCADO',
      local: local.nombreSocial ?? 'Local',
      monto: montoHijo,
      fecha: c.fecha ?? DateTime.now(),
      numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? masterPayment?.numeroBoleta ?? masterPayment?.correlativo ?? '0'}',
      anioCorrelativo: c.fecha?.year ?? DateTime.now().year,
      cobrador: user?.nombre ?? 'Cobrador',
      saldoPendiente: (c.saldoPendiente ?? 0).toDouble(),
      deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
      montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
      saldoAFavor: favorResultante,
      fechasSaldadas: c.fechasDeudasSaldadas,
      periodoAbonadoStr: periodoAbonadoStr,
      periodoSaldoAFavorStr: periodoFavorStr,
      slogan: muni?.slogan,
      clave: local.clave,
      codigoLocal: local.codigo,
      codigoCatastral: local.codigoCatastral,
    );
  }

  Future<void> _compartirHijo(BuildContext context, WidgetRef ref, Cobro c) async {
    final user = ref.read(currentUsuarioProvider).value;
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(local.municipalidadId ?? '');
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    String? periodoFavorStr;
    final favorResultante = (c.nuevoSaldoFavor ?? 0).toDouble();
    final cuota = (c.cuotaDiaria ?? 0).toDouble();
    final fechasRes = c.fechasDeudasSaldadas ?? [];
    if (favorResultante > 0 && cuota > 0) {
      int dias = (favorResultante / cuota).floor();
      if (dias > 0) {
        DateTime inicioFavor = (c.fecha ?? DateTime.now()).add(const Duration(days: 1));
        if (fechasRes.isNotEmpty) {
          final sorted = List<DateTime>.from(fechasRes)..sort();
          inicioFavor = sorted.last.add(const Duration(days: 1));
        }
        periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
      }
    }

    String? periodoAbonadoStr;
    if (fechasRes.isNotEmpty) {
      periodoAbonadoStr = DateRangeFormatter.formatearRangos(fechasRes);
    }

    double montoHijo = (c.monto != null && c.monto! > 0)
        ? c.monto!.toDouble()
        : (c.cuotaDiaria != null && c.cuotaDiaria! > 0)
            ? c.cuotaDiaria!.toDouble()
            : (local.cuotaDiaria ?? 0).toDouble();

    if (context.mounted) {
      await ReceiptDispatcher.compartirPdf(
        context: context,
        local: local,
        monto: montoHijo,
        fecha: c.fecha ?? DateTime.now(),
        saldoPendiente: (c.saldoPendiente ?? 0).toDouble(),
        deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
        montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
        saldoAFavor: favorResultante,
        numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? masterPayment?.numeroBoleta ?? masterPayment?.correlativo ?? '0'}',
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

    final esPagadoConSaldoAFavor = estado == 'cobrado' && (cobro.monto == null || cobro.monto == 0);

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
        onTap: () => _mostrarDetalles(context, ref, color, esPagadoConSaldoAFavor),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    else if (esPagadoConSaldoAFavor)
                      Text(
                        'Cuota cubierta automáticamente con saldo a favor',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
                      color: esPendiente ? color : Theme.of(context).colorScheme.onSurface,
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
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
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
                  valor: DateFormatter.formatCurrency(cobro.pagoACuota ?? cobro.cuotaDiaria ?? 0),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12),
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
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
