import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../../core/widgets/scrollable_table.dart';
import '../../../../core/widgets/usuario_filter.dart';
import '../../../../core/utils/receipt_dispatcher.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../usuarios/domain/entities/usuario.dart';
import '../viewmodels/cobro_viewmodel.dart';
import '../viewmodels/cobros_paginados_notifier.dart';

class CobrosScreen extends ConsumerStatefulWidget {
  const CobrosScreen({super.key});

  @override
  ConsumerState<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends ConsumerState<CobrosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchColumn = 'Local';
  _CobrosOrden _ordenFiltro = _CobrosOrden.ninguno;
  String _estadoFiltro = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cobrosPaginadosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobilePadding = outerConstraints.maxWidth <= 700;
          return Padding(
            padding: isMobilePadding
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CobrosHeader(
                  cobros: state.cobros,
                  searchController: _searchController,
                  selectedColumn: _searchColumn,
                  selectedOrder: _ordenFiltro,
                  selectedEstado: _estadoFiltro,
                  onSearch: (value) => setState(() => _searchQuery = value),
                  onColumnChanged: (value) {
                    if (value == null) return;
                    setState(() => _searchColumn = value);
                  },
                  onOrderChanged: (value) {
                    setState(() => _ordenFiltro = value);
                  },
                  onEstadoChanged: (value) {
                    setState(() => _estadoFiltro = value);
                  },
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: state.cargando && state.cobros.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : state.errorMsg != null
                      ? Center(
                          child: Text(
                            state.errorMsg!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      : _CobrosFullTable(
                          state: state,
                          searchQuery: _searchQuery,
                          searchColumn: _searchColumn,
                          orderMode: _ordenFiltro,
                          estadoFiltro: _estadoFiltro,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Header de filtros.
enum _CobrosPeriod { hoy, semana, mes }

enum _CobrosOrden {
  ninguno,
  alfabeticoAsc,
  alfabeticoDesc,
  montoMayor,
  montoMenor,
}

class _CobrosHeader extends ConsumerStatefulWidget {
  final List<Cobro> cobros;
  final TextEditingController searchController;
  final String selectedColumn;
  final _CobrosOrden selectedOrder;
  final String selectedEstado;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onColumnChanged;
  final ValueChanged<_CobrosOrden> onOrderChanged;
  final ValueChanged<String> onEstadoChanged;

  const _CobrosHeader({
    required this.cobros,
    required this.searchController,
    required this.selectedColumn,
    required this.selectedOrder,
    required this.selectedEstado,
    required this.onSearch,
    required this.onColumnChanged,
    required this.onOrderChanged,
    required this.onEstadoChanged,
  });
  @override
  ConsumerState<_CobrosHeader> createState() => _CobrosHeaderState();
}

class _CobrosHeaderState extends ConsumerState<_CobrosHeader> {
  _CobrosPeriod? _periodo = _CobrosPeriod.hoy;

  @override
  void initState() {
    super.initState();
    // Arrancar con el rango de hoy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _aplicar(_CobrosPeriod.hoy);
    });
  }

  Future<void> _aplicar(_CobrosPeriod p) async {
    final cobradorActual = ref.read(cobrosPaginadosProvider).cobradorId;
    await _aplicarConCobrador(p, cobradorId: cobradorActual);
  }

  Future<void> _aplicarConCobrador(
    _CobrosPeriod p, {
    required String? cobradorId,
  }) async {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);

    DateTimeRange? rango;
    switch (p) {
      case _CobrosPeriod.hoy:
        rango = DateTimeRange(start: hoy, end: hoy);
        break;
      case _CobrosPeriod.semana:
        rango = DateTimeRange(
          start: hoy.subtract(const Duration(days: 6)),
          end: hoy,
        );
        break;
      case _CobrosPeriod.mes:
        rango = DateTimeRange(
          start: DateTime(hoy.year, hoy.month, 1),
          end: hoy,
        );
        break;
    }

    if (!mounted) return;
    setState(() => _periodo = p);
    ref
        .read(cobrosPaginadosProvider.notifier)
        .aplicarFiltros(rango: rango, cobradorId: cobradorId);
  }

  void _cambiarCobrador(String? id) {
    ref
        .read(cobrosPaginadosProvider.notifier)
        .aplicarFiltros(rango: _rangoActualOHoy(), cobradorId: id);
  }

  void _recargar() {
    ref.read(cobrosPaginadosProvider.notifier).recargar();
  }

  Future<void> _restablecerFiltros() async {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    if (mounted) {
      setState(() => _periodo = _CobrosPeriod.hoy);
    }
    widget.searchController.clear();
    widget.onSearch('');
    widget.onOrderChanged(_CobrosOrden.ninguno);
    widget.onEstadoChanged('Todos');
    ref
        .read(cobrosPaginadosProvider.notifier)
        .aplicarFiltros(
          rango: DateTimeRange(start: hoy, end: hoy),
          cobradorId: null,
        );
  }

  DateTimeRange _rangoActualOHoy() {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final rango = ref.read(cobrosPaginadosProvider).rangoFechas;
    if (rango == null) {
      return DateTimeRange(start: hoy, end: hoy);
    }
    final inicio = DateTime(
      rango.start.year,
      rango.start.month,
      rango.start.day,
    );
    final fin = DateTime(rango.end.year, rango.end.month, rango.end.day);
    if (fin.isBefore(inicio)) {
      return DateTimeRange(start: fin, end: inicio);
    }
    return DateTimeRange(start: inicio, end: fin);
  }

  Future<void> _seleccionarDesde() async {
    final now = DateTime.now();
    final rangoActual = _rangoActualOHoy();
    final picked = await showDatePicker(
      context: context,
      initialDate: rangoActual.start,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    final desde = DateTime(picked.year, picked.month, picked.day);
    final hasta = rangoActual.end.isBefore(desde) ? desde : rangoActual.end;
    await _aplicarRangoManual(DateTimeRange(start: desde, end: hasta));
  }

  Future<void> _seleccionarHasta() async {
    final now = DateTime.now();
    final rangoActual = _rangoActualOHoy();
    final picked = await showDatePicker(
      context: context,
      initialDate: rangoActual.end,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    final hasta = DateTime(picked.year, picked.month, picked.day);
    final desde = hasta.isBefore(rangoActual.start) ? hasta : rangoActual.start;
    await _aplicarRangoManual(DateTimeRange(start: desde, end: hasta));
  }

  _CobrosPeriod? _periodoDesdeRango(DateTimeRange rango) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final inicio = DateTime(
      rango.start.year,
      rango.start.month,
      rango.start.day,
    );
    final fin = DateTime(rango.end.year, rango.end.month, rango.end.day);

    if (inicio == hoy && fin == hoy) return _CobrosPeriod.hoy;
    if (inicio == hoy.subtract(const Duration(days: 6)) && fin == hoy) {
      return _CobrosPeriod.semana;
    }
    if (inicio == DateTime(hoy.year, hoy.month, 1) && fin == hoy) {
      return _CobrosPeriod.mes;
    }
    return null;
  }

  Future<void> _aplicarRangoManual(DateTimeRange rango) async {
    if (!mounted) return;
    setState(() => _periodo = _periodoDesdeRango(rango));
    ref
        .read(cobrosPaginadosProvider.notifier)
        .aplicarFiltros(
          rango: rango,
          cobradorId: ref.read(cobrosPaginadosProvider).cobradorId,
        );
  }

  Future<void> _abrirFiltrosBottomSheet() async {
    var ordenLocal = widget.selectedOrder;
    var estadoLocal = widget.selectedEstado;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final colorScheme = Theme.of(sheetCtx).colorScheme;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Future<void> applyAndClose() async {
              widget.onOrderChanged(ordenLocal);
              widget.onEstadoChanged(estadoLocal);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            }

            Future<void> resetAndClose() async {
              widget.onOrderChanged(_CobrosOrden.ninguno);
              widget.onEstadoChanged('Todos');
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            }

            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    6,
                    16,
                    16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                                colorScheme.secondaryContainer.withValues(
                                  alpha: 0.62,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.24,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Filtros de Cobros',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'Ajusta orden y estado para revisar más rápido.',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.sort_by_alpha_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Orden alfabético',
                                    style: Theme.of(sheetCtx)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OrderModeChip(
                                      label: 'A - Z',
                                      selected:
                                          ordenLocal ==
                                          _CobrosOrden.alfabeticoAsc,
                                      onTap: () => setSheetState(
                                        () => ordenLocal =
                                            _CobrosOrden.alfabeticoAsc,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OrderModeChip(
                                      label: 'Z - A',
                                      selected:
                                          ordenLocal ==
                                          _CobrosOrden.alfabeticoDesc,
                                      onTap: () => setSheetState(
                                        () => ordenLocal =
                                            _CobrosOrden.alfabeticoDesc,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_money_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Orden por monto',
                                    style: Theme.of(sheetCtx)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OrderModeChip(
                                      label: 'Monto mayor',
                                      selected:
                                          ordenLocal == _CobrosOrden.montoMayor,
                                      onTap: () => setSheetState(
                                        () => ordenLocal =
                                            _CobrosOrden.montoMayor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OrderModeChip(
                                      label: 'Monto menor',
                                      selected:
                                          ordenLocal == _CobrosOrden.montoMenor,
                                      onTap: () => setSheetState(
                                        () => ordenLocal =
                                            _CobrosOrden.montoMenor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _OrderModeChip(
                                label: 'Sin orden',
                                selected: ordenLocal == _CobrosOrden.ninguno,
                                onTap: () => setSheetState(
                                  () => ordenLocal = _CobrosOrden.ninguno,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.label_important_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estado',
                                    style: Theme.of(sheetCtx)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Todos',
                                      selected: estadoLocal == 'Todos',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'Todos',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Cobrado',
                                      selected: estadoLocal == 'cobrado',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'cobrado',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Pendiente',
                                      selected: estadoLocal == 'pendiente',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'pendiente',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Abono parcial',
                                      selected: estadoLocal == 'abono_parcial',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'abono_parcial',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Abono deuda',
                                      selected: estadoLocal == 'abono_deuda',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'abono_deuda',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Adelantado',
                                      selected: estadoLocal == 'adelantado',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'adelantado',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Anulado',
                                      selected: estadoLocal == 'anulado',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'anulado',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Cancelado',
                                      selected: estadoLocal == 'cancelado',
                                      onTap: () => setSheetState(
                                        () => estadoLocal = 'cancelado',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(child: SizedBox.shrink()),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: resetAndClose,
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 16,
                                ),
                                label: const Text('Restablecer'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: applyAndClose,
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Aplicar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getDescripcion(DateTimeRange rango) {
    final periodo = _periodo;
    switch (periodo) {
      case _CobrosPeriod.hoy:
        return 'Solo cobros del día de hoy';
      case _CobrosPeriod.semana:
        return 'Últimos 7 días de actividad';
      case _CobrosPeriod.mes:
        return 'Desde el 1 del mes actual hasta hoy';
      case null:
        return 'Del ${DateFormatter.formatDate(rango.start)} al ${DateFormatter.formatDate(rango.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(cobrosPaginadosProvider);
    final descripcion = _getDescripcion(_rangoActualOHoy());

    return Container(
      decoration: context.webHeaderDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isDesktop = w >= 1100;
            final isTablet = w >= 760 && w < 1100;
            final isMobile = w < 760;

            Widget actions({required bool compact}) {
              final compactStyle = OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
              );
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: compactStyle,
                      onPressed: _recargar,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Recargar'),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: compactStyle,
                      onPressed: _abrirFiltrosBottomSheet,
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: const Text('Filtros'),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: compactStyle,
                      onPressed: _restablecerFiltros,
                      icon: const Icon(Icons.restart_alt_rounded, size: 15),
                      label: const Text('Restablecer'),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 14,
                        ),
                      ),
                      onPressed: widget.cobros.isEmpty ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                      label: const Text('Exportar PDF'),
                    ),
                  ),
                ],
              );
            }

            final headerLeft = Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cobros',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                      ),
                      Text(
                        '${widget.cobros.length} registros visibles',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );

            final header = isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerLeft,
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actions(compact: true),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: headerLeft),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: actions(compact: !isDesktop),
                        ),
                      ),
                    ],
                  );

            Widget periodFilters({required bool compact}) {
              final chips = _buildPeriodChips();
              if (!compact) {
                return Wrap(spacing: 8, runSpacing: 8, children: chips);
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: chips
                      .map(
                        (chip) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: chip,
                        ),
                      )
                      .toList(),
                ),
              );
            }

            Widget filtersDesktop() {
              final rangoActivo = _rangoActualOHoy();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: periodFilters(compact: false)),
                  const SizedBox(width: 8),
                  _CobrosDateFilterButton(
                    label: 'Desde',
                    fecha: rangoActivo.start,
                    icon: Icons.calendar_today_rounded,
                    onPressed: _seleccionarDesde,
                  ),
                  const SizedBox(width: 8),
                  _CobrosDateFilterButton(
                    label: 'Hasta',
                    fecha: rangoActivo.end,
                    icon: Icons.date_range_rounded,
                    onPressed: _seleccionarHasta,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 260,
                    child: UsuarioFilter(
                      label: 'Cobrador',
                      selectedUsuarioId: state.cobradorId,
                      onUsuarioChanged: (u) => _cambiarCobrador(u?.id),
                    ),
                  ),
                ],
              );
            }

            Widget filtersTablet() {
              final rangoActivo = _rangoActualOHoy();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  periodFilters(compact: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _CobrosDateFilterButton(
                          label: 'Desde',
                          fecha: rangoActivo.start,
                          icon: Icons.calendar_today_rounded,
                          onPressed: _seleccionarDesde,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CobrosDateFilterButton(
                          label: 'Hasta',
                          fecha: rangoActivo.end,
                          icon: Icons.date_range_rounded,
                          onPressed: _seleccionarHasta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  UsuarioFilter(
                    label: 'Cobrador',
                    selectedUsuarioId: state.cobradorId,
                    onUsuarioChanged: (u) => _cambiarCobrador(u?.id),
                  ),
                ],
              );
            }

            Widget searchDesktop() {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 220,
                    child: _CobrosSearchColumnDropdown(
                      value: widget.selectedColumn,
                      onChanged: widget.onColumnChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CobrosSearchInput(
                      controller: widget.searchController,
                      onChanged: widget.onSearch,
                    ),
                  ),
                ],
              );
            }

            Widget searchTablet() {
              return Column(
                children: [
                  _CobrosSearchColumnDropdown(
                    value: widget.selectedColumn,
                    onChanged: widget.onColumnChanged,
                  ),
                  const SizedBox(height: 8),
                  _CobrosSearchInput(
                    controller: widget.searchController,
                    onChanged: widget.onSearch,
                  ),
                ],
              );
            }

            final filtersGroup = Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Color.alphaBlend(
                  colorScheme.primary.withValues(alpha: 0.01),
                  colorScheme.surfaceContainerLowest,
                ),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.36),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    descripcion,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  isTablet || isMobile ? filtersTablet() : filtersDesktop(),
                  const SizedBox(height: 8),
                  isTablet || isMobile ? searchTablet() : searchDesktop(),
                ],
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, const SizedBox(height: 8), filtersGroup],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildPeriodChips() {
    return [
      _PeriodChip(
        label: 'Hoy',
        selected: _periodo == _CobrosPeriod.hoy,
        onSelected: () => _aplicar(_CobrosPeriod.hoy),
      ),
      _PeriodChip(
        label: 'Semana',
        selected: _periodo == _CobrosPeriod.semana,
        onSelected: () => _aplicar(_CobrosPeriod.semana),
      ),
      _PeriodChip(
        label: 'Mes',
        selected: _periodo == _CobrosPeriod.mes,
        onSelected: () => _aplicar(_CobrosPeriod.mes),
      ),
    ];
  }

  Future<void> _exportPdf() async {
    final descripcion = _getDescripcion(_rangoActualOHoy());
    final locales = ref.read(localesProvider).value ?? [];
    final mercados = ref.read(mercadosProvider).value ?? [];
    final bytes = await ReportePdfGenerator.generarReporteCobros(
      cobros: widget.cobros,
      locales: locales,
      mercados: mercados,
      periodoLabel: descripcion,
    );
    if (kIsWeb) {
      await descargarPdfWeb(bytes, 'Reporte_Cobros.pdf');
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Reporte_Cobros',
      );
    }
  }
}

class _CobrosSearchColumnDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _CobrosSearchColumnDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.arrow_drop_down_rounded),
      decoration: InputDecoration(
        labelText: 'Buscar por',
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: 'Local', child: Text('Local')),
        DropdownMenuItem(value: 'Mercado', child: Text('Mercado')),
        DropdownMenuItem(value: 'Estado', child: Text('Estado')),
        DropdownMenuItem(value: 'Cobrador', child: Text('Cobrador')),
        DropdownMenuItem(value: 'Teléfono', child: Text('Teléfono')),
        DropdownMenuItem(value: 'Observaciones', child: Text('Observaciones')),
      ],
      onChanged: onChanged,
    );
  }
}

class _CobrosSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CobrosSearchInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Buscar cobro',
        hintText: 'Local, mercado, cobrador o teléfono...',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CobrosDateFilterButton extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final IconData icon;
  final VoidCallback onPressed;

  const _CobrosDateFilterButton({
    required this.label,
    required this.fecha,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text('$label: ${DateFormatter.formatDate(fecha)}'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _OrderModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.surface,
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.7)
                : colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 16,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.surface,
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.7)
                : colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// Tabla de cobros con paginación.
class _CobrosFullTable extends ConsumerStatefulWidget {
  final CobrosPaginadosState state;
  final String searchQuery;
  final String searchColumn;
  final _CobrosOrden orderMode;
  final String estadoFiltro;

  const _CobrosFullTable({
    required this.state,
    required this.searchQuery,
    required this.searchColumn,
    required this.orderMode,
    required this.estadoFiltro,
  });

  @override
  ConsumerState<_CobrosFullTable> createState() => _CobrosFullTableState();
}

class _CobrosFullTableState extends ConsumerState<_CobrosFullTable> {
  String nombreLocal(String? id, List<Local> locales) {
    if (id == null) return '-';
    return locales
        .where((l) => l.id == id)
        .map((l) => l.nombreSocial ?? '-')
        .firstWhere((_) => true, orElse: () => 'Desconocido');
  }

  String nombreMercado(String? id, List<Mercado> mercados) {
    if (id == null) return '-';
    return mercados
        .where((m) => m.id == id)
        .map((m) => m.nombre ?? '-')
        .firstWhere((_) => true, orElse: () => 'Desconocido');
  }

  String nombreCobrador(String? id, List<Usuario> usuarios) {
    if (id == null) return '-';
    return usuarios
        .where((u) => u.id == id)
        .map((u) => u.nombre ?? '-')
        .firstWhere((_) => true, orElse: () => 'Desconocido');
  }

  double _montoParaOrden(Cobro cobro) {
    if (cobro.estado == 'pendiente') {
      return (cobro.saldoPendiente ?? 0).toDouble();
    }
    return (cobro.monto ?? 0).toDouble();
  }

  String _estadoComparable(Cobro cobro) {
    final estado = (cobro.estado ?? '').trim().toLowerCase();
    if (estado.isEmpty) return 'pendiente';
    return estado;
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar activamente los datos maestros para que la tabla reaccione
    final locales = ref.watch(localesProvider).value ?? [];
    final mercados = ref.watch(mercadosProvider).value ?? [];
    final usuarios = ref.watch(usuariosProvider).value ?? [];

    final q = widget.searchQuery.toLowerCase();
    final searchFiltered = q.isEmpty
        ? widget.state.cobros
        : widget.state.cobros.where((c) {
            switch (widget.searchColumn) {
              case 'Local':
                return nombreLocal(
                  c.localId,
                  locales,
                ).toLowerCase().contains(q);
              case 'Mercado':
                return nombreMercado(
                  c.mercadoId,
                  mercados,
                ).toLowerCase().contains(q);
              case 'Estado':
                final estadoRaw = (c.estado ?? '').toLowerCase();
                final estadoLabel = _cobroEstadoLabel(c.estado).toLowerCase();
                return estadoRaw.contains(q) || estadoLabel.contains(q);
              case 'Cobrador':
                return nombreCobrador(
                  c.cobradorId,
                  usuarios,
                ).toLowerCase().contains(q);
              case 'Teléfono':
                return (c.telefonoRepresentante ?? '').toLowerCase().contains(
                  q,
                );
              case 'Observaciones':
                return (c.observaciones ?? '').toLowerCase().contains(q);
              default:
                return true;
            }
          }).toList();

    final estadoFiltered = widget.estadoFiltro == 'Todos'
        ? searchFiltered
        : searchFiltered
              .where((c) => _estadoComparable(c) == widget.estadoFiltro)
              .toList();

    final filtered = [...estadoFiltered];
    switch (widget.orderMode) {
      case _CobrosOrden.ninguno:
        break;
      case _CobrosOrden.alfabeticoAsc:
        filtered.sort(
          (a, b) => nombreLocal(a.localId, locales).toLowerCase().compareTo(
            nombreLocal(b.localId, locales).toLowerCase(),
          ),
        );
        break;
      case _CobrosOrden.alfabeticoDesc:
        filtered.sort(
          (a, b) => nombreLocal(b.localId, locales).toLowerCase().compareTo(
            nombreLocal(a.localId, locales).toLowerCase(),
          ),
        );
        break;
      case _CobrosOrden.montoMayor:
        filtered.sort(
          (a, b) => _montoParaOrden(b).compareTo(_montoParaOrden(a)),
        );
        break;
      case _CobrosOrden.montoMenor:
        filtered.sort(
          (a, b) => _montoParaOrden(a).compareTo(_montoParaOrden(b)),
        );
        break;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          if (kDebugMode && widget.state.seleccionados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 34,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: Text(
                      'Eliminar (${widget.state.seleccionados.length})',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        _confirmarEliminacionMultiple(context, ref),
                  ),
                ),
              ),
            ),

          // Tabla / Cards
          Expanded(
            child: LayoutBuilder(
              builder: (context, tableConstraints) {
                final isMobileView = tableConstraints.maxWidth < 600;

                if (isMobileView) {
                  // Vista de tarjetas para móvil.
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Sin resultados',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final c = filtered[index];

                              // Formatear periodos si existen
                              String? periodoAbonadoStr;
                              if (c.montoAbonadoDeuda != null &&
                                  c.montoAbonadoDeuda! > 0) {
                                periodoAbonadoStr =
                                    DateRangeFormatter.formatearRangoAbonado(
                                      c.fecha,
                                      c.montoAbonadoDeuda!.toDouble(),
                                      c.cuotaDiaria?.toDouble(),
                                    );
                              }

                              String? periodoFavorStr;
                              if (c.nuevoSaldoFavor != null &&
                                  c.nuevoSaldoFavor! > 0) {
                                final dias =
                                    (c.nuevoSaldoFavor! / (c.cuotaDiaria ?? 1))
                                        .floor();
                                final inicioFavor =
                                    c.fecha?.add(const Duration(days: 1)) ??
                                    DateTime.now();
                                periodoFavorStr =
                                    DateRangeFormatter.calcularPeriodoFuturo(
                                      inicioFavor,
                                      dias,
                                    );
                              }

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Fila 1: Local + Monto
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  nombreLocal(
                                                    c.localId,
                                                    locales,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                c.estado == 'pendiente'
                                                    ? CurrencyFormatter.format(
                                                        (c.saldoPendiente ?? 0)
                                                            .toDouble(),
                                                      )
                                                    : CurrencyFormatter.format(
                                                        (c.monto ?? 0)
                                                            .toDouble(),
                                                      ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: c.estado == 'pendiente'
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.error
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Fila 2: Mercado + Cobrador
                                          Text(
                                            '${nombreMercado(c.mercadoId, mercados)} • ${nombreCobrador(c.cobradorId, usuarios)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                          if (periodoAbonadoStr != null ||
                                              periodoFavorStr != null) ...[
                                            const SizedBox(height: 6),
                                            if (periodoAbonadoStr != null)
                                              Text(
                                                'Abono: $periodoAbonadoStr',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: context
                                                      .semanticColors
                                                      .warning,
                                                ),
                                              ),
                                            if (periodoFavorStr != null)
                                              Text(
                                                'A favor: $periodoFavorStr',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: context
                                                      .semanticColors
                                                      .success,
                                                ),
                                              ),
                                          ],

                                          const SizedBox(height: 8),
                                          // Fila 3: Fecha + Estado + Boleta + Acciones
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.4),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormatter.formatDateTime(
                                                  c.fecha,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _EstadoChip(estado: c.estado),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  c.numeroBoletaFmt,
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.print_rounded,
                                                    size: 16,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () =>
                                                      _imprimirCobro(c),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons
                                                        .delete_forever_rounded,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                    size: 16,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () =>
                                                      _confirmarEliminacion(
                                                        context,
                                                        ref,
                                                        c,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (kDebugMode)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Checkbox(
                                          value: widget.state.seleccionados
                                              .contains(c.id),
                                          onChanged: (val) {
                                            if (c.id != null) {
                                              ref
                                                  .read(
                                                    cobrosPaginadosProvider
                                                        .notifier,
                                                  )
                                                  .toggleSeleccion(c.id!);
                                            }
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  );
                }

                // Vista de tabla para desktop.
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ScrollableTable(
                    child: DataTable(
                      headingRowHeight: 48,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      columnSpacing: 24,
                      headingTextStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      columns: [
                        if (kDebugMode)
                          DataColumn(
                            label: Checkbox(
                              value:
                                  filtered.isNotEmpty &&
                                  filtered.every(
                                    (c) => widget.state.seleccionados.contains(
                                      c.id,
                                    ),
                                  ),
                              onChanged: (val) {
                                ref
                                    .read(cobrosPaginadosProvider.notifier)
                                    .seleccionarTodos(filtered);
                              },
                            ),
                          ),
                        const DataColumn(label: Text('Fecha')),
                        const DataColumn(label: Text('Mercado')),
                        const DataColumn(label: Text('Local')),
                        const DataColumn(label: Text('Monto')),
                        const DataColumn(label: Text('Estado')),
                        const DataColumn(label: Text('Cobrador')),
                        const DataColumn(label: Text('Boleta')),
                        const DataColumn(label: Text('Acciones')),
                      ],
                      rows: filtered.map((c) {
                        return DataRow(
                          selected: widget.state.seleccionados.contains(c.id),
                          onSelectChanged: kDebugMode
                              ? (val) {
                                  if (c.id != null) {
                                    ref
                                        .read(cobrosPaginadosProvider.notifier)
                                        .toggleSeleccion(c.id!);
                                  }
                                }
                              : null,
                          cells: [
                            if (kDebugMode)
                              DataCell(
                                Checkbox(
                                  value: widget.state.seleccionados.contains(
                                    c.id,
                                  ),
                                  onChanged: (val) {
                                    if (c.id != null) {
                                      ref
                                          .read(
                                            cobrosPaginadosProvider.notifier,
                                          )
                                          .toggleSeleccion(c.id!);
                                    }
                                  },
                                ),
                              ),
                            DataCell(
                              Text(DateFormatter.formatDateTime(c.fecha)),
                            ),
                            DataCell(
                              Text(nombreMercado(c.mercadoId, mercados)),
                            ),
                            DataCell(Text(nombreLocal(c.localId, locales))),
                            DataCell(
                              Text(
                                c.estado == 'pendiente'
                                    ? CurrencyFormatter.format(
                                        (c.saldoPendiente ?? 0).toDouble(),
                                      )
                                    : CurrencyFormatter.format(
                                        (c.monto ?? 0).toDouble(),
                                      ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: c.estado == 'pendiente'
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                            DataCell(_EstadoChip(estado: c.estado)),
                            DataCell(
                              Text(nombreCobrador(c.cobradorId, usuarios)),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c.numeroBoletaFmt,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.print_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () => _imprimirCobro(c),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_forever_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      size: 20,
                                    ),
                                    tooltip: 'Eliminar cobro',
                                    onPressed: () =>
                                        _confirmarEliminacion(context, ref, c),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),

          // Controles de paginación.
          if (widget.state.cobros.isNotEmpty)
            _PaginationBar(
              currentPage: widget.state.paginaActual,
              onPrev: widget.state.paginaActual > 1
                  ? () => ref
                        .read(cobrosPaginadosProvider.notifier)
                        .irAPaginaAnterior()
                  : null,
              onNext: widget.state.hayMas
                  ? () => ref
                        .read(cobrosPaginadosProvider.notifier)
                        .irAPaginaSiguiente()
                  : null,
              isCargando: widget.state.cargando,
            ),
        ],
      ),
    );
  }

  Future<void> _imprimirCobro(Cobro cobro) async {
    await ReceiptDispatcher.imprimirDesdeCobro(
      context: context,
      ref: ref,
      cobro: cobro,
    );
  }

  void _confirmarEliminacion(BuildContext context, WidgetRef ref, Cobro c) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar Cobro'),
        content: Text(
          '¿Estás seguro de eliminar este cobro de L. ${c.monto}? Esto revertirá los saldos y deudas asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(cobroViewModelProvider.notifier)
                    .eliminarCobro(c);
                ref.read(cobrosPaginadosProvider.notifier).recargar();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacionMultiple(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return;

    final seleccionados = ref.read(cobrosPaginadosProvider).seleccionados;
    if (seleccionados.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Eliminar Múltiples Cobros',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Text(
          '¿Estás seguro de eliminar ${seleccionados.length} cobro(s)? Esta es una acción destructiva de DEBUG y borrará cada registro seleccionado. Esta operación podría tardar varios segundos según la cantidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.warning, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref
                  .read(cobrosPaginadosProvider.notifier)
                  .eliminarSeleccionados(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Eliminación múltiple completada.'),
                  ),
                );
              }
            },
            label: const Text('ELIMINAR TODOS'),
          ),
        ],
      ),
    );
  }
}

// Widget reutilizable de paginación.
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;

  const _PaginationBar({
    required this.currentPage,
    required this.onPrev,
    required this.onNext,
    required this.isCargando,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isCargando)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: isCargando ? null : onPrev,
            color: onPrev != null
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
            tooltip: 'Página anterior',
          ),
          const SizedBox(width: 8),
          Text(
            'Página $currentPage',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isCargando ? null : onNext,
            color: onNext != null
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
            tooltip: 'Página siguiente',
          ),
        ],
      ),
    );
  }
}

// Chip de periodo.
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.transparent,
    );
  }
}

// Chip de estado.
String _cobroEstadoLabel(String? estado) {
  final value = (estado ?? '').toLowerCase().trim();
  switch (value) {
    case 'cobrado':
      return 'Cobrado';
    case 'cobrado_saldo':
      return 'Cobrado con saldo';
    case 'abono_parcial':
      return 'Abono parcial';
    case 'abono_deuda':
      return 'Abono a deuda';
    case 'adelantado':
      return 'Adelantado';
    case 'pendiente':
      return 'Pendiente';
    case 'anulado':
      return 'Anulado';
    case 'cancelado':
      return 'Cancelado';
    default:
      if (value.isEmpty) return 'Pendiente';
      final words = value.replaceAll('_', ' ').split(' ');
      return words
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

Color _cobroEstadoColor(BuildContext context, String? estado) {
  final semantic = context.semanticColors;
  final value = (estado ?? '').toLowerCase().trim();
  switch (value) {
    case 'cobrado':
    case 'cobrado_saldo':
    case 'adelantado':
      return semantic.success;
    case 'abono_parcial':
    case 'abono_deuda':
      return semantic.warning;
    case 'anulado':
    case 'cancelado':
      return Theme.of(context).colorScheme.outline;
    case 'pendiente':
    default:
      return semantic.danger;
  }
}

class _EstadoChip extends StatelessWidget {
  final String? estado;

  const _EstadoChip({this.estado});

  @override
  Widget build(BuildContext context) {
    final chipColor = _cobroEstadoColor(context, estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _cobroEstadoLabel(estado),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
