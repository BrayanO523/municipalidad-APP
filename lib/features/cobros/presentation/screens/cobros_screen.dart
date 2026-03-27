import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../core/widgets/sortable_column.dart';
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
                  selectedColumn: state.searchColumn,
                  selectedEstado: state.estadoFiltro,
                  onSearch: (value) =>
                      ref.read(cobrosPaginadosProvider.notifier).buscar(value),
                  onColumnChanged: (value) {
                    if (value != null) {
                      ref
                          .read(cobrosPaginadosProvider.notifier)
                          .cambiarColumnaBusqueda(value);
                    }
                  },
                  onEstadoChanged: (value) {
                    ref
                        .read(cobrosPaginadosProvider.notifier)
                        .cambiarFiltroEstado(value);
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
                          onSort: (col) => ref
                              .read(cobrosPaginadosProvider.notifier)
                              .cambiarOrdenamiento(col),
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

class _CobrosHeader extends ConsumerStatefulWidget {
  final List<Cobro> cobros;
  final TextEditingController searchController;
  final String selectedColumn;
  final String selectedEstado;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onColumnChanged;
  final ValueChanged<String> onEstadoChanged;

  const _CobrosHeader({
    required this.cobros,
    required this.searchController,
    required this.selectedColumn,
    required this.selectedEstado,
    required this.onSearch,
    required this.onColumnChanged,
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
    widget.onEstadoChanged('Todos');
    ref.read(cobrosPaginadosProvider.notifier).cambiarColumnaBusqueda('Local');
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

  String _getDescripcionPdf(DateTimeRange rango) {
    final inicio = DateTime(
      rango.start.year,
      rango.start.month,
      rango.start.day,
    );
    final fin = DateTime(rango.end.year, rango.end.month, rango.end.day);
    if (inicio == fin) {
      return 'Fecha del reporte: ${DateFormatter.formatDate(inicio)}';
    }
    return 'Rango del reporte: ${DateFormatter.formatDate(inicio)} al ${DateFormatter.formatDate(fin)}';
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
    final descripcion = _getDescripcionPdf(_rangoActualOHoy());
    final locales = ref.read(localesProvider).value ?? [];
    final mercados = ref.read(mercadosProvider).value ?? [];
    final municipalidadNombre = ref.read(municipalidadActualProvider)?.nombre;
    final bytes = await ReportePdfGenerator.generarReporteCobros(
      cobros: widget.cobros,
      locales: locales,
      mercados: mercados,
      periodoLabel: descripcion,
      municipalidadNombre: municipalidadNombre,
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
        DropdownMenuItem(value: 'Boleta', child: Text('Boleta')),
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

// Tabla de cobros con paginación.
class _CobrosFullTable extends ConsumerStatefulWidget {
  final CobrosPaginadosState state;
  final Function(String) onSort;

  const _CobrosFullTable({required this.state, required this.onSort});

  @override
  ConsumerState<_CobrosFullTable> createState() => _CobrosFullTableState();
}

class _CobrosFullTableState extends ConsumerState<_CobrosFullTable> {
  Cobro? _cobroSeleccionado;
  final FocusNode _tableFocusNode = FocusNode();

  @override
  void dispose() {
    _tableFocusNode.dispose();
    super.dispose();
  }

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

  bool _esMismoCobro(Cobro a, Cobro b) {
    if (a.id != null && b.id != null) return a.id == b.id;
    return a.localId == b.localId &&
        a.fecha == b.fecha &&
        a.numeroBoletaFmt == b.numeroBoletaFmt;
  }

  String? _periodoAbonadoStr(Cobro c) {
    if (c.montoAbonadoDeuda == null || c.montoAbonadoDeuda! <= 0) return null;
    final fechasSaldadas = c.fechasDeudasSaldadas;
    if (fechasSaldadas != null && fechasSaldadas.isNotEmpty) {
      final rangoReal = DateRangeFormatter.formatearRangos(fechasSaldadas);
      if (rangoReal != null && rangoReal.isNotEmpty) return rangoReal;
    }
    return DateRangeFormatter.formatearRangoAbonado(
      c.fecha,
      c.montoAbonadoDeuda!.toDouble(),
      c.cuotaDiaria?.toDouble(),
    );
  }

  String? _periodoFavorStr(Cobro c) {
    if (c.nuevoSaldoFavor == null || c.nuevoSaldoFavor! <= 0) return null;
    final dias = (c.nuevoSaldoFavor! / (c.cuotaDiaria ?? 1)).floor();
    final inicioFavor = c.fecha?.add(const Duration(days: 1)) ?? DateTime.now();
    return DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
  }

  void _moverSeleccion(int delta, List<Cobro> cobrosActuales) {
    if (cobrosActuales.isEmpty) return;

    if (_cobroSeleccionado == null) {
      if (delta > 0) {
        setState(() => _cobroSeleccionado = cobrosActuales.first);
      }
      return;
    }

    final currentIndex = cobrosActuales.indexWhere(
      (c) => _esMismoCobro(c, _cobroSeleccionado!),
    );
    if (currentIndex == -1) {
      setState(() => _cobroSeleccionado = cobrosActuales.first);
      return;
    }

    final nextIndex = currentIndex + delta;
    if (nextIndex >= 0 && nextIndex < cobrosActuales.length) {
      setState(() => _cobroSeleccionado = cobrosActuales[nextIndex]);
    }
  }

  void _onCobroTapped(
    BuildContext context,
    Cobro cobro,
    bool isWide,
    List<Local> locales,
    List<Mercado> mercados,
    List<Usuario> usuarios,
  ) {
    if (isWide) {
      setState(() {
        if (_cobroSeleccionado != null &&
            _esMismoCobro(_cobroSeleccionado!, cobro)) {
          _cobroSeleccionado = null;
        } else {
          _cobroSeleccionado = cobro;
        }
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          child: _CobroDetallePanel(
            cobro: cobro,
            localNombre: nombreLocal(cobro.localId, locales),
            mercadoNombre: nombreMercado(cobro.mercadoId, mercados),
            cobradorNombre: nombreCobrador(cobro.cobradorId, usuarios),
            periodoAbonado: _periodoAbonadoStr(cobro),
            periodoFavor: _periodoFavorStr(cobro),
            onImprimir: () {
              Navigator.of(ctx).pop();
              _imprimirCobro(cobro);
            },
            onEliminar: () {
              Navigator.of(ctx).pop();
              _confirmarEliminacion(context, ref, cobro);
            },
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar activamente los datos maestros para que la tabla reaccione
    final locales = ref.watch(localesProvider).value ?? [];
    final mercados = ref.watch(mercadosProvider).value ?? [];
    final usuarios = ref.watch(usuariosProvider).value ?? [];

    final filtered = ref
        .read(cobrosPaginadosProvider.notifier)
        .getCobrosFiltrados(locales, mercados, usuarios);

    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 900;
    final totalPaginas = widget.state.hayMas
        ? widget.state.paginaActual + 1
        : widget.state.paginaActual;
    Cobro? cobroSeleccionado;
    if (_cobroSeleccionado != null) {
      for (final c in filtered) {
        if (_esMismoCobro(c, _cobroSeleccionado!)) {
          cobroSeleccionado = c;
          break;
        }
      }
    }

    return Focus(
      focusNode: _tableFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moverSeleccion(1, filtered);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moverSeleccion(-1, filtered);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _tableFocusNode.requestFocus(),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
            ),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4),
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
                                  final periodoAbonadoStr = _periodoAbonadoStr(
                                    c,
                                  );

                                  String? periodoFavorStr;
                                  if (c.nuevoSaldoFavor != null &&
                                      c.nuevoSaldoFavor! > 0) {
                                    final dias =
                                        (c.nuevoSaldoFavor! /
                                                (c.cuotaDiaria ?? 1))
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

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _onCobroTapped(
                                      context,
                                      c,
                                      false,
                                      locales,
                                      mercados,
                                      usuarios,
                                    ),
                                    child: Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
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
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      c.estado == 'pendiente'
                                                          ? CurrencyFormatter.format(
                                                              (c.saldoPendiente ??
                                                                      0)
                                                                  .toDouble(),
                                                            )
                                                          : CurrencyFormatter.format(
                                                              (c.monto ?? 0)
                                                                  .toDouble(),
                                                            ),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                        color:
                                                            c.estado ==
                                                                'pendiente'
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .error
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),

                                                if (periodoAbonadoStr != null ||
                                                    periodoFavorStr !=
                                                        null) ...[
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
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
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
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _EstadoChip(
                                                      estado: c.estado,
                                                    ),
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
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        c.numeroBoletaFmt,
                                                        style: TextStyle(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                        padding:
                                                            EdgeInsets.zero,
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
                                                        padding:
                                                            EdgeInsets.zero,
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
                                                value: widget
                                                    .state
                                                    .seleccionados
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
                                    ),
                                  );
                                },
                              ),
                      );
                    }

                    // Vista de tabla para desktop.
                    final tableView = Container(
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
                          showCheckboxColumn: false,
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
                                        (c) => widget.state.seleccionados
                                            .contains(c.id),
                                      ),
                                  onChanged: (val) {
                                    ref
                                        .read(cobrosPaginadosProvider.notifier)
                                        .seleccionarTodos(filtered);
                                  },
                                ),
                              ),
                            DataColumn(
                              label: SortableColumn(
                                label: 'Fecha',
                                isActive: widget.state.sortColumn == 'Fecha',
                                ascending: widget.state.sortAsc,
                                onTap: () => widget.onSort('Fecha'),
                              ),
                            ),
                            DataColumn(
                              label: SortableColumn(
                                label: 'Local',
                                isActive: widget.state.sortColumn == 'Local',
                                ascending: widget.state.sortAsc,
                                onTap: () => widget.onSort('Local'),
                              ),
                            ),
                            DataColumn(
                              label: SortableColumn(
                                label: 'Monto',
                                isActive: widget.state.sortColumn == 'Monto',
                                ascending: widget.state.sortAsc,
                                onTap: () => widget.onSort('Monto'),
                              ),
                            ),
                            DataColumn(
                              label: SortableColumn(
                                label: 'Estado',
                                isActive: widget.state.sortColumn == 'Estado',
                                ascending: widget.state.sortAsc,
                                onTap: () => widget.onSort('Estado'),
                              ),
                            ),
                            DataColumn(
                              label: SortableColumn(
                                label: 'Boleta',
                                isActive: widget.state.sortColumn == 'Boleta',
                                ascending: widget.state.sortAsc,
                                onTap: () => widget.onSort('Boleta'),
                              ),
                            ),
                          ],
                          rows: filtered.map((c) {
                            final filaSeleccionada =
                                cobroSeleccionado != null &&
                                _esMismoCobro(cobroSeleccionado, c);
                            return DataRow(
                              selected: filaSeleccionada,
                              color: WidgetStateProperty.resolveWith<Color?>((
                                _,
                              ) {
                                if (filaSeleccionada) {
                                  return colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  );
                                }
                                return null;
                              }),
                              onSelectChanged: (_) => _onCobroTapped(
                                context,
                                c,
                                isWide,
                                locales,
                                mercados,
                                usuarios,
                              ),
                              cells: [
                                if (kDebugMode)
                                  DataCell(
                                    Checkbox(
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
                                DataCell(
                                  Text(DateFormatter.formatDateTime(c.fecha)),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      nombreLocal(c.localId, locales),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
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
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );

                    if (!isWide) return tableView;

                    final selectedCobro = cobroSeleccionado;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 13, child: tableView),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                        ),
                        Expanded(
                          flex: 9,
                          child: Column(
                            children: [
                              Expanded(
                                child: selectedCobro != null
                                    ? _CobroDetallePanel(
                                        cobro: selectedCobro,
                                        localNombre: nombreLocal(
                                          selectedCobro.localId,
                                          locales,
                                        ),
                                        mercadoNombre: nombreMercado(
                                          selectedCobro.mercadoId,
                                          mercados,
                                        ),
                                        cobradorNombre: nombreCobrador(
                                          selectedCobro.cobradorId,
                                          usuarios,
                                        ),
                                        periodoAbonado: _periodoAbonadoStr(
                                          selectedCobro,
                                        ),
                                        periodoFavor: _periodoFavorStr(
                                          selectedCobro,
                                        ),
                                        onImprimir: () =>
                                            _imprimirCobro(selectedCobro),
                                        onEliminar: () => _confirmarEliminacion(
                                          context,
                                          ref,
                                          selectedCobro,
                                        ),
                                        onClose: () => setState(
                                          () => _cobroSeleccionado = null,
                                        ),
                                        showActions: false,
                                      )
                                    : const _CobroDetalleVacio(),
                              ),
                              if (widget.state.cobros.isNotEmpty)
                                _CobroPanelFooter(
                                  currentPage: widget.state.paginaActual,
                                  totalPages: totalPaginas,
                                  onPrev: widget.state.paginaActual > 1
                                      ? () {
                                          setState(
                                            () => _cobroSeleccionado = null,
                                          );
                                          ref
                                              .read(
                                                cobrosPaginadosProvider
                                                    .notifier,
                                              )
                                              .irAPaginaAnterior();
                                        }
                                      : null,
                                  onNext: widget.state.hayMas
                                      ? () {
                                          setState(
                                            () => _cobroSeleccionado = null,
                                          );
                                          ref
                                              .read(
                                                cobrosPaginadosProvider
                                                    .notifier,
                                              )
                                              .irAPaginaSiguiente();
                                        }
                                      : null,
                                  isCargando: widget.state.cargando,
                                  onEditar: selectedCobro == null
                                      ? null
                                      : () => _editarCobro(
                                          context,
                                          selectedCobro,
                                        ),
                                  onEliminar: selectedCobro == null
                                      ? null
                                      : () => _confirmarEliminacion(
                                          context,
                                          ref,
                                          selectedCobro,
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // En desktop la paginación vive dentro del panel derecho.
              if (widget.state.cobros.isNotEmpty && !isWide)
                _PaginationBar(
                  currentPage: widget.state.paginaActual,
                  totalPages: totalPaginas,
                  onPrev: widget.state.paginaActual > 1
                      ? () {
                          setState(() => _cobroSeleccionado = null);
                          ref
                              .read(cobrosPaginadosProvider.notifier)
                              .irAPaginaAnterior();
                        }
                      : null,
                  onNext: widget.state.hayMas
                      ? () {
                          setState(() => _cobroSeleccionado = null);
                          ref
                              .read(cobrosPaginadosProvider.notifier)
                              .irAPaginaSiguiente();
                        }
                      : null,
                  isCargando: widget.state.cargando,
                ),
            ],
          ),
        ),
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

  Future<void> _editarCobro(BuildContext context, Cobro cobro) async {
    if (cobro.id == null) return;
    final controller = TextEditingController(text: cobro.observaciones ?? '');
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Editar observaciones'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observaciones',
            hintText: 'Ingresa el detalle del cobro',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar != true) return;

    try {
      await ref.read(cobroDatasourceProvider).actualizar(cobro.id!, {
        'observaciones': controller.text.trim(),
      });
      ref.read(cobrosPaginadosProvider.notifier).recargar();

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Observaciones actualizadas correctamente.'),
          backgroundColor: colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el cobro: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  void _confirmarEliminacion(BuildContext context, WidgetRef ref, Cobro c) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar Cobro'),
        content: Text(
          '¿Estás seguro de eliminar este cobro de ${CurrencyFormatter.format((c.monto ?? 0).toDouble())}? Esto revertirá los saldos y deudas asociados.',
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
class _CobroDetallePanel extends StatelessWidget {
  final Cobro cobro;
  final String localNombre;
  final String mercadoNombre;
  final String cobradorNombre;
  final String? periodoAbonado;
  final String? periodoFavor;
  final VoidCallback onImprimir;
  final VoidCallback onEliminar;
  final VoidCallback onClose;
  final bool showActions;

  const _CobroDetallePanel({
    required this.cobro,
    required this.localNombre,
    required this.mercadoNombre,
    required this.cobradorNombre,
    required this.periodoAbonado,
    required this.periodoFavor,
    required this.onImprimir,
    required this.onEliminar,
    required this.onClose,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final observaciones = (cobro.observaciones ?? '').trim();
    final montoPrincipal = cobro.estado == 'pendiente'
        ? (cobro.saldoPendiente ?? cobro.monto ?? 0).toDouble()
        : (cobro.monto ?? 0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 240;
        final padding = compact ? 12.0 : 24.0;

        return Container(
          color: colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localNombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded),
                      onPressed: onImprimir,
                      tooltip: 'Imprimir',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClose,
                      tooltip: 'Cerrar detalle',
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CobroDetalleRow(
                          icon: Icons.receipt_long_rounded,
                          label: 'Boleta',
                          value: cobro.numeroBoletaFmt,
                        ),
                        _CobroDetalleRow(
                          icon: Icons.schedule_rounded,
                          label: 'Fecha',
                          value: DateFormatter.formatDateTime(cobro.fecha),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.flag_rounded,
                          label: 'Estado',
                          value: _cobroEstadoLabel(cobro.estado),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.storefront_rounded,
                          label: 'Mercado',
                          value: mercadoNombre,
                        ),
                        _CobroDetalleRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Cobrador',
                          value: cobradorNombre,
                        ),
                        _CobroDetalleRow(
                          icon: Icons.attach_money_rounded,
                          label: 'Monto',
                          value: CurrencyFormatter.format(montoPrincipal),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.paid_rounded,
                          label: 'Pago a cuota',
                          value: CurrencyFormatter.format(
                            (cobro.pagoACuota ?? 0).toDouble(),
                          ),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Abono a deuda',
                          value: CurrencyFormatter.format(
                            (cobro.montoAbonadoDeuda ?? 0).toDouble(),
                          ),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.trending_down_rounded,
                          label: 'Deuda anterior',
                          value: CurrencyFormatter.format(
                            (cobro.deudaAnterior ?? 0).toDouble(),
                          ),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.warning_amber_rounded,
                          label: 'Saldo pendiente',
                          value: CurrencyFormatter.format(
                            (cobro.saldoPendiente ?? 0).toDouble(),
                          ),
                        ),
                        _CobroDetalleRow(
                          icon: Icons.savings_rounded,
                          label: 'Nuevo saldo a favor',
                          value: CurrencyFormatter.format(
                            (cobro.nuevoSaldoFavor ?? 0).toDouble(),
                          ),
                        ),
                        if (periodoAbonado != null)
                          _CobroDetalleRow(
                            icon: Icons.history_toggle_off_rounded,
                            label: 'Periodo abonado',
                            value: periodoAbonado!,
                          ),
                        if (periodoFavor != null)
                          _CobroDetalleRow(
                            icon: Icons.event_available_rounded,
                            label: 'Periodo a favor',
                            value: periodoFavor!,
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'Observaciones',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            observaciones.isEmpty ? '-' : observaciones,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showActions) ...[
                  if (!compact) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onEliminar,
                          style: FilledButton.styleFrom(
                            backgroundColor: context.semanticColors.danger,
                            foregroundColor: context.semanticColors.onDanger,
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Eliminar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CobroDetalleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CobroDetalleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CobroDetalleVacio extends StatelessWidget {
  const _CobroDetalleVacio();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona un cobro de la tabla\npara ver su informacion completa.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CobroPanelFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const _CobroPanelFooter({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
    required this.isCargando,
    this.onEditar,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (onEditar != null) ...[
            OutlinedButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
            const SizedBox(width: 8),
          ],
          if (onEliminar != null) ...[
            FilledButton.icon(
              onPressed: onEliminar,
              style: FilledButton.styleFrom(
                backgroundColor: context.semanticColors.danger,
                foregroundColor: context.semanticColors.onDanger,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Eliminar'),
            ),
            const SizedBox(width: 12),
          ],
          const Spacer(),
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
            'Página ${currentPage > totalPages ? totalPages : currentPage} de $totalPages',
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

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
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
            'Página ${currentPage > totalPages ? totalPages : currentPage} de $totalPages',
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
