import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/printer_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_date_range_picker.dart';
import '../../domain/entities/cobro.dart';

// ── Constante de paginación ──────────────────────────────────────────────────
const _kPageSize = 20;

class CobrosScreen extends ConsumerWidget {
  const CobrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosRecientes = ref.watch(cobrosFiltradosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CobrosHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: cobrosRecientes.when(
                data: (cobros) {
                  if (cobros.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay cobros registrados aún',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return _CobrosFullTable(cobros: cobros);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header con filtro de fechas ──────────────────────────────────────────────
class _CobrosHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rango = ref.watch(fechaFiltroCobrosProvider);
    final theme = Theme.of(context);

    String dateText = 'Consulta de cobros y recaudación diaria';
    if (rango != null) {
      dateText =
          'Del ${DateFormatter.formatDate(rango.start)} al ${DateFormatter.formatDate(rango.end)}';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
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
              dateText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (rango != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                tooltip: 'Limpiar filtro',
                onPressed: () {
                  ref.read(fechaFiltroCobrosProvider.notifier).setRango(null);
                },
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Filtrar por Fecha'),
              onPressed: () async {
                final now = DateTime.now();
                final hoy = DateTime(now.year, now.month, now.day);
                final result = await showDialog<DateTimeRange>(
                  context: context,
                  builder: (_) => CustomDateRangePicker(
                    initialRange: rango ?? DateTimeRange(start: hoy, end: hoy),
                  ),
                );

                if (result != null) {
                  ref.read(fechaFiltroCobrosProvider.notifier).setRango(result);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Tabla con filtros por columna y paginación ───────────────────────────────
class _CobrosFullTable extends ConsumerStatefulWidget {
  final List<Cobro> cobros;

  const _CobrosFullTable({required this.cobros});

  @override
  ConsumerState<_CobrosFullTable> createState() => _CobrosFullTableState();
}

class _CobrosFullTableState extends ConsumerState<_CobrosFullTable> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _searchColumn = 'Local';
  int _currentPage = 0;

  static const List<String> _columnas = [
    'Local',
    'Estado',
    'Cobrador',
    'Teléfono',
    'Observaciones',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Cuando cambia filtro, siempre volver a la página 0
  void _setSearch(String q) => setState(() {
    _searchQuery = q;
    _currentPage = 0;
  });

  void _setColumn(String? col) => setState(() {
    if (col != null) _searchColumn = col;
    _currentPage = 0;
  });

  @override
  Widget build(BuildContext context) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final locales = ref.watch(localesProvider).value ?? [];

    String nombreCobrador(String? id) {
      if (id == null || id.isEmpty) return '-';
      try {
        return usuarios.firstWhere((u) => u.id == id).nombre ?? id;
      } catch (_) {
        return id;
      }
    }

    String nombreLocal(String? id) {
      if (id == null || id.isEmpty) return '-';
      try {
        return locales.firstWhere((l) => l.id == id).nombreSocial ?? id;
      } catch (_) {
        return id;
      }
    }

    // Filtrado según columna seleccionada
    final q = _searchQuery.toLowerCase();
    final filtered = q.isEmpty
        ? widget.cobros
        : widget.cobros.where((c) {
            switch (_searchColumn) {
              case 'Local':
                return nombreLocal(c.localId).toLowerCase().contains(q);
              case 'Estado':
                return (c.estado ?? '').toLowerCase().contains(q);
              case 'Cobrador':
                return nombreCobrador(c.cobradorId).toLowerCase().contains(q);
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

    // Paginación
    final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 99999);
    final start = _currentPage * _kPageSize;
    final end = (start + _kPageSize).clamp(0, filtered.length);
    final paginated = filtered.sublist(start, end);

    return Column(
      children: [
        // ── Barra de filtros ──────────────────────────────────────────────
        Row(
          children: [
            // Selector de columna
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _searchColumn,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white54,
                  ),
                  isDense: true,
                  dropdownColor: const Color(0xFF1E2235),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _columnas
                      .map(
                        (col) => DropdownMenuItem(value: col, child: Text(col)),
                      )
                      .toList(),
                  onChanged: _setColumn,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Campo de búsqueda
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: _setSearch,
                decoration: InputDecoration(
                  hintText: 'Buscar por $_searchColumn...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Contador de resultados
            Text(
              '${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Tabla ─────────────────────────────────────────────────────────
        Expanded(
          child: Card(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.white.withOpacity(0.05),
                    ),
                    columns: const [
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Local')),
                      DataColumn(label: Text('Teléfono')),
                      DataColumn(label: Text('Monto')),
                      DataColumn(label: Text('Pago a Cuota')),
                      DataColumn(label: Text('Cuota Diaria')),
                      DataColumn(label: Text('Saldo Pendiente')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Cobrador')),
                      DataColumn(label: Text('Observaciones')),
                      DataColumn(label: Text('Ticket')),
                    ],
                    rows: paginated.map((c) {
                      return DataRow(
                        cells: [
                          DataCell(Text(DateFormatter.formatDateTime(c.fecha))),
                          DataCell(
                            Text(
                              nombreLocal(c.localId),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              c.telefonoRepresentante ?? '-',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          DataCell(Text(DateFormatter.formatCurrency(c.monto))),
                          DataCell(
                            Text(DateFormatter.formatCurrency(c.pagoACuota)),
                          ),
                          DataCell(
                            Text(DateFormatter.formatCurrency(c.cuotaDiaria)),
                          ),
                          DataCell(
                            Text(
                              DateFormatter.formatCurrency(c.saldoPendiente),
                            ),
                          ),
                          DataCell(_EstadoChip(estado: c.estado)),
                          DataCell(
                            Text(
                              nombreCobrador(c.cobradorId),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(Text(c.observaciones ?? '-')),
                          DataCell(
                            IconButton(
                              icon: const Icon(
                                Icons.print,
                                color: Colors.white70,
                              ),
                              tooltip: 'Reimprimir boleta',
                              onPressed: () async {
                                final printer = ref.read(
                                  printerServiceProvider,
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Re-imprimiendo ticket N°${c.correlativo ?? "-"}...',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );

                                final double montoSeguro =
                                    c.monto?.toDouble() ?? 0.0;
                                final double saldoPendienteRaw =
                                    c.saldoPendiente?.toDouble() ?? 0.0;
                                final double saldoPendienteSeguro =
                                    saldoPendienteRaw > 0
                                    ? saldoPendienteRaw
                                    : 0.0;

                                final impreso = await printer.printReceipt(
                                  empresa: 'MUNICIPALIDAD',
                                  local: nombreLocal(c.localId),
                                  monto: montoSeguro,
                                  fecha: c.fecha ?? DateTime.now(),
                                  saldoPendiente: saldoPendienteSeguro,
                                  saldoAFavor: c.nuevoSaldoFavor?.toDouble(),
                                  deudaAnterior: c.deudaAnterior?.toDouble(),
                                  montoAbonadoDeuda: c.montoAbonadoDeuda
                                      ?.toDouble(),
                                  cobrador: nombreCobrador(c.cobradorId),
                                  correlativo: c.correlativo,
                                  anioCorrelativo: c.anioCorrelativo,
                                );

                                if (!impreso && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Comprobante no impreso. Revisa conexión de la impresora.',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Controles de paginación ───────────────────────────────────────
        const SizedBox(height: 8),
        _PaginationBar(
          currentPage: _currentPage,
          totalPages: totalPages,
          totalItems: filtered.length,
          pageSize: _kPageSize,
          onPrev: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          onNext: _currentPage < totalPages - 1
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }
}

// ── Widget reutilizable de paginación ────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : currentPage * pageSize + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrev,
          color: onPrev != null ? Colors.white70 : Colors.white24,
          tooltip: 'Página anterior',
        ),
        const SizedBox(width: 8),
        Text(
          '$start–$end de $totalItems',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(
          '(Pág. ${currentPage + 1}/$totalPages)',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
          color: onNext != null ? Colors.white70 : Colors.white24,
          tooltip: 'Página siguiente',
        ),
      ],
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
