import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
// Removed provider import
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../../core/widgets/custom_date_range_picker.dart';
import '../../../../core/widgets/scrollable_table.dart';
import '../../../../core/widgets/usuario_filter.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../usuarios/domain/entities/usuario.dart';
import '../viewmodels/cobro_viewmodel.dart';
import '../viewmodels/cobros_paginados_notifier.dart';

// ── Constante de paginación ──────────────────────────────────────────────────
const _kPageSize = 20;

class CobrosScreen extends ConsumerWidget {
  const CobrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                _CobrosHeader(cobros: state.cobros),
                const SizedBox(height: 20),
                Expanded(
                  child:
                      state.cargando && state.cobros.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : state.errorMsg != null
                          ? Center(
                            child: Text(
                              state.errorMsg!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          )
                          : state.cobros.isEmpty
                          ? Center(
                            child: Text(
                              'No hay cobros registrados aun',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                              ),
                            ),
                          )
                          : _CobrosFullTable(state: state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Header con chips de período (igual al Dashboard) ─────────────────────────
enum _CobrosPeriod { hoy, semana, mes, anio, personalizado }

class _CobrosHeader extends ConsumerStatefulWidget {
  final List<Cobro> cobros;
  const _CobrosHeader({required this.cobros});
  @override
  ConsumerState<_CobrosHeader> createState() => _CobrosHeaderState();
}

class _CobrosHeaderState extends ConsumerState<_CobrosHeader> {
  _CobrosPeriod _periodo = _CobrosPeriod.hoy;

  @override
  void initState() {
    super.initState();
    // Arrancar con el rango de hoy
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _aplicar(_CobrosPeriod.hoy),
    );
  }

  void _aplicar(_CobrosPeriod p) async {
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
        rango = DateTimeRange(start: DateTime(hoy.year, hoy.month, 1), end: hoy);
        break;
      case _CobrosPeriod.anio:
        rango = DateTimeRange(start: DateTime(hoy.year, 1, 1), end: hoy);
        break;
      case _CobrosPeriod.personalizado:
        final actual = ref.read(cobrosPaginadosProvider).rangoFechas;
        final result = await showDialog<DateTimeRange>(
          context: context,
          builder:
              (_) => CustomDateRangePicker(
                initialRange: actual ?? DateTimeRange(start: hoy, end: hoy),
              ),
        );
        if (result != null) {
          setState(() => _periodo = _CobrosPeriod.personalizado);
          ref
              .read(cobrosPaginadosProvider.notifier)
              .aplicarFiltros(rango: result);
        }
        return;
    }

    setState(() => _periodo = p);
    ref.read(cobrosPaginadosProvider.notifier).aplicarFiltros(
      rango: rango,
      cobradorId: ref.read(cobrosPaginadosProvider).cobradorId,
    );
  }

  void _cambiarCobrador(String? id) {
    ref.read(cobrosPaginadosProvider.notifier).aplicarFiltros(
      rango: ref.read(cobrosPaginadosProvider).rangoFechas,
      cobradorId: id,
    );
  }

  String _getDescripcion(WidgetRef ref) {
    final state = ref.watch(cobrosPaginadosProvider);
    final rango = state.rangoFechas;
    switch (_periodo) {
      case _CobrosPeriod.hoy:
        return 'Solo cobros del día de hoy';
      case _CobrosPeriod.semana:
        return 'Últimos 7 días de actividad';
      case _CobrosPeriod.mes:
        final now = DateTime.now();
        return 'Desde el 1 de ${DateFormatter.getMonthName(now)} hasta hoy';
      case _CobrosPeriod.anio:
        return 'Desde el 1 de enero de ${DateTime.now().year} hasta hoy';
      case _CobrosPeriod.personalizado:
        if (rango != null) {
          return 'Del ${DateFormatter.formatDate(rango.start)} al ${DateFormatter.formatDate(rango.end)}';
        }
        return 'Rango personalizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descripcion = _getDescripcion(ref);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cobros',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descripcion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
                  _PeriodChip(
                    label: 'Año',
                    selected: _periodo == _CobrosPeriod.anio,
                    onSelected: () => _aplicar(_CobrosPeriod.anio),
                  ),
                  _PeriodChip(
                    label: 'Personalizado',
                    selected: _periodo == _CobrosPeriod.personalizado,
                    onSelected: () => _aplicar(_CobrosPeriod.personalizado),
                  ),
                  const SizedBox(width: 8),
                  UsuarioFilter(
                    selectedUsuarioId: ref.watch(cobrosPaginadosProvider).cobradorId,
                    onUsuarioChanged: (u) => _cambiarCobrador(u?.id),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Exportar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    onPressed: widget.cobros.isEmpty ? null : _exportPdf,
                  ),
                ],
              ),
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            // Título + descripción
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cobros',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
            // Chips de período
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                _PeriodChip(
                  label: 'Año',
                  selected: _periodo == _CobrosPeriod.anio,
                  onSelected: () => _aplicar(_CobrosPeriod.anio),
                ),
                _PeriodChip(
                  label: 'Personalizado',
                  selected: _periodo == _CobrosPeriod.personalizado,
                  onSelected: () => _aplicar(_CobrosPeriod.personalizado),
                ),
                const SizedBox(width: 12),
                UsuarioFilter(
                  selectedUsuarioId: ref.watch(cobrosPaginadosProvider).cobradorId,
                  onUsuarioChanged: (u) => _cambiarCobrador(u?.id),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Exportar PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: widget.cobros.isEmpty ? null : _exportPdf,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    final descripcion = _getDescripcion(ref);
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

// ── Tabla con filtros por columna y paginación ───────────────────────────────
class _CobrosFullTable extends ConsumerStatefulWidget {
  final CobrosPaginadosState state;
  const _CobrosFullTable({required this.state});

  @override
  ConsumerState<_CobrosFullTable> createState() => _CobrosFullTableState();
}

class _CobrosFullTableState extends ConsumerState<_CobrosFullTable> {
  String _searchQuery = '';
  String _searchColumn = 'Local';

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

  @override
  Widget build(BuildContext context) {
    // Escuchar activamente los datos maestros para que la tabla reaccione
    final locales = ref.watch(localesProvider).value ?? [];
    final mercados = ref.watch(mercadosProvider).value ?? [];
    final usuarios = ref.watch(usuariosProvider).value ?? [];

    final q = _searchQuery.toLowerCase();
    final filtered =
        q.isEmpty
            ? widget.state.cobros
            : widget.state.cobros.where((c) {
              switch (_searchColumn) {
                case 'Local':
                  return nombreLocal(c.localId, locales).toLowerCase().contains(q);
                case 'Mercado':
                  return nombreMercado(c.mercadoId, mercados).toLowerCase().contains(q);
                case 'Estado':
                  return (c.estado ?? '').toLowerCase().contains(q);
                case 'Cobrador':
                  return nombreCobrador(c.cobradorId, usuarios).toLowerCase().contains(q);
                case 'Teléfono':
                  return (c.telefonoRepresentante ?? '')
                      .toLowerCase()
                      .contains(q);
                case 'Observaciones':
                  return (c.observaciones ?? '').toLowerCase().contains(q);
                default:
                  return true;
              }
            }).toList();

    return Column(
      children: [
        // ── Barra de filtros ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMini = constraints.maxWidth < 450;
              return Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: isMini ? 'Buscar...' : 'Buscar cobros...',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _searchColumn,
                    underline: const SizedBox(),
                    items:
                        [
                          'Local',
                          'Mercado',
                          'Estado',
                          'Cobrador',
                          'Teléfono',
                          'Observaciones',
                        ].map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                    onChanged: (v) => setState(() => _searchColumn = v!),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Tabla / Cards ─────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, tableConstraints) {
              final isMobileView = tableConstraints.maxWidth < 600;

              if (isMobileView) {
                // ── Vista de tarjetas para móvil ──
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            
                            // Formatear periodos si existen
                            String? periodoAbonadoStr;
                            if (c.montoAbonadoDeuda != null && c.montoAbonadoDeuda! > 0) {
                              periodoAbonadoStr = DateRangeFormatter.formatearRangoAbonado(c.fecha, c.montoAbonadoDeuda!.toDouble(), c.cuotaDiaria?.toDouble());
                            }
                            
                            String? periodoFavorStr;
                            if (c.nuevoSaldoFavor != null && c.nuevoSaldoFavor! > 0) {
                              final dias = (c.nuevoSaldoFavor! / (c.cuotaDiaria ?? 1)).floor();
                              final inicioFavor = c.fecha?.add(const Duration(days: 1)) ?? DateTime.now();
                              periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
                            }

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Fila 1: Local + Monto
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nombreLocal(c.localId, locales),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'L. ${c.estado == 'pendiente' ? (c.saldoPendiente ?? 0).toStringAsFixed(2) : c.monto?.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: c.estado == 'pendiente' 
                                                ? Theme.of(context).colorScheme.error 
                                                : Theme.of(context).colorScheme.primary,
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
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    
                                    if (periodoAbonadoStr != null || periodoFavorStr != null) ...[
                                      const SizedBox(height: 6),
                                      if (periodoAbonadoStr != null)
                                        Text(
                                          'Abono: $periodoAbonadoStr',
                                          style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
                                        ),
                                      if (periodoFavorStr != null)
                                        Text(
                                          'A favor: $periodoFavorStr',
                                          style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                                        ),
                                    ],

                                    const SizedBox(height: 8),
                                    // Fila 3: Fecha + Estado + Boleta + Acciones
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormatter.formatDateTime(c.fecha),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _EstadoChip(estado: c.estado),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            c.numeroBoletaFmt,
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        SizedBox(
                                          width: 32, height: 32,
                                          child: IconButton(
                                            icon: const Icon(Icons.print_rounded, size: 16),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _imprimirCobro(context, ref, c),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 32, height: 32,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 16),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _confirmarEliminacion(context, ref, c),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                );
              }

              // ── Vista de tabla para desktop ──
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
                    columns: const [
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Mercado')),
                      DataColumn(label: Text('Local')),
                      DataColumn(label: Text('Monto')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Cobrador')),
                      DataColumn(label: Text('Boleta')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows:
                        filtered.map((c) {
                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormatter.formatDateTime(c.fecha))),
                              DataCell(Text(nombreMercado(c.mercadoId, mercados))),
                              DataCell(Text(nombreLocal(c.localId, locales))),
                              DataCell(
                                Text(
                                  'L. ${c.estado == 'pendiente' ? (c.saldoPendiente ?? 0).toStringAsFixed(2) : c.monto?.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.estado == 'pendiente' 
                                        ? Theme.of(context).colorScheme.error 
                                        : null,
                                  ),
                                ),
                              ),
                              DataCell(_EstadoChip(estado: c.estado)),
                              DataCell(Text(nombreCobrador(c.cobradorId, usuarios))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    c.numeroBoletaFmt,
                                    style: const TextStyle(
                                      color: Colors.blue,
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
                                      onPressed: () => _imprimirCobro(context, ref, c),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_forever_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      tooltip: 'Eliminar cobro',
                                      onPressed:
                                          () =>
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

        // ── Controles de paginación ───────────────────────────────────────
        const SizedBox(height: 8),
        _PaginationBar(
          currentPage: widget.state.paginaActual - 1,
          totalItems: widget.state.cobros.length,
          pageSize: _kPageSize,
          onPrev:
              widget.state.paginaActual > 1
                  ? () =>
                      ref
                          .read(cobrosPaginadosProvider.notifier)
                          .irAPaginaAnterior()
                  : null,
          onNext:
              widget.state.hayMas
                  ? () =>
                      ref
                          .read(cobrosPaginadosProvider.notifier)
                          .irAPaginaSiguiente()
                  : null,
          isCargando: widget.state.cargando,
        ),
      ],
    );
  }

  void _imprimirCobro(BuildContext context, WidgetRef ref, Cobro c) async {
    final printer = ref.read(printerServiceProvider);
    
    final locales = ref.read(localesProvider).value ?? [];
    final mercados = ref.read(mercadosProvider).value ?? [];
    final usuarios = ref.read(usuariosProvider).value ?? [];

    final local = locales.where((l) => l.id == c.localId).firstOrNull;

    try {
      final municipalidad = ref.read(municipalidadActualProvider);
      await printer.printReceipt(
        empresa: municipalidad?.nombre ?? 'Municipalidad',
        mercado: nombreMercado(c.mercadoId, mercados),
        local: nombreLocal(c.localId, locales),
        monto: (c.monto ?? 0).toDouble(),
        fecha: c.fecha ?? DateTime.now(),
        numeroBoleta: '${c.numeroBoleta ?? c.correlativo ?? '0'}',
        anioCorrelativo: c.anioCorrelativo ?? DateTime.now().year,
        cobrador: nombreCobrador(c.cobradorId, usuarios),
        saldoPendiente: (c.saldoPendiente ?? 0).toDouble(),
        deudaAnterior: (c.deudaAnterior ?? 0).toDouble(),
        montoAbonadoDeuda: (c.montoAbonadoDeuda ?? 0).toDouble(),
        saldoAFavor: (c.nuevoSaldoFavor ?? 0).toDouble(),
        slogan: municipalidad?.slogan,
        clave: local?.clave,
        codigoLocal: local?.codigo,
        codigoCatastral: local?.codigoCatastral,
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
      }
    }
  }

  void _confirmarEliminacion(BuildContext context, WidgetRef ref, Cobro c) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
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
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  try {
                    await ref.read(cobroViewModelProvider.notifier).eliminarCobro(c);
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
}

// ── Widget reutilizable de paginación ────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;

  const _PaginationBar({
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
    required this.isCargando,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
          color:
              onPrev != null
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                  : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página anterior',
        ),
        const SizedBox(width: 8),
        Text(
          'Página ${currentPage + 1}',
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
          color:
              onNext != null
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                  : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página siguiente',
        ),
      ],
    );
  }
}

// ── Chip de periodo ──────────────────────────────────────────────────────────
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
        color:
            selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: Colors.transparent,
    );
  }
}

// ── Chip de estado ───────────────────────────────────────────────────────────
class _EstadoChip extends StatelessWidget {
  final String? estado;

  const _EstadoChip({this.estado});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (estado) {
      case 'cobrado':
        chipColor = const Color(0xFF00D9A6);
        break;
      case 'abono_parcial':
        chipColor = const Color(0xFFFF9F43);
        break;
      default:
        chipColor = const Color(0xFFEE5A6F);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado ?? 'pendiente',
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
