import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../domain/entities/local.dart';

const _kPageSize = 20;

class DeudoresScreen extends ConsumerStatefulWidget {
  const DeudoresScreen({super.key});

  @override
  ConsumerState<DeudoresScreen> createState() => _DeudoresScreenState();
}

class _DeudoresScreenState extends ConsumerState<DeudoresScreen> {
  String _searchQuery = '';
  String _searchColumn = 'Local';
  int _currentPage = 0;

  static const _columnas = ['Local', 'Representante', 'Teléfono'];

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
    final localesAsync = ref.watch(localesProvider);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de filtros siempre visible
            Row(
              children: [
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
                            (col) =>
                                DropdownMenuItem(value: col, child: Text(col)),
                          )
                          .toList(),
                      onChanged: _setColumn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: localesAsync.when(
                data: (list) {
                  final q = _searchQuery.toLowerCase();
                  final withDeuda = list.where((l) {
                    final tieneDeuda = (l.deudaAcumulada ?? 0) > 0;
                    if (!tieneDeuda) return false;
                    if (q.isEmpty) return true;
                    switch (_searchColumn) {
                      case 'Local':
                        return (l.nombreSocial ?? '').toLowerCase().contains(q);
                      case 'Representante':
                        return (l.representante ?? '').toLowerCase().contains(
                          q,
                        );
                      case 'Teléfono':
                        return (l.telefonoRepresentante ?? '')
                            .toLowerCase()
                            .contains(q);
                      default:
                        return true;
                    }
                  }).toList();
                  withDeuda.sort(
                    (a, b) => (b.deudaAcumulada ?? 0).compareTo(
                      a.deudaAcumulada ?? 0,
                    ),
                  );

                  final totalPages = (withDeuda.length / _kPageSize)
                      .ceil()
                      .clamp(1, 99999);
                  final page = _currentPage.clamp(0, totalPages - 1);
                  final paginated = withDeuda.sublist(
                    page * _kPageSize,
                    (page * _kPageSize + _kPageSize).clamp(0, withDeuda.length),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con botón exportar – tiene acceso a la lista completa
                      _Header(todos: withDeuda),
                      const SizedBox(height: 16),
                      if (withDeuda.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 48,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '¡No hay locales con deuda! Todo está al día.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Expanded(child: _DeudoresTable(locales: paginated)),
                        const SizedBox(height: 8),
                        _PaginationBar(
                          currentPage: page,
                          totalPages: totalPages,
                          totalItems: withDeuda.length,
                          pageSize: _kPageSize,
                          onPrev: page > 0
                              ? () => setState(() => _currentPage = page - 1)
                              : null,
                          onNext: page < totalPages - 1
                              ? () => setState(() => _currentPage = page + 1)
                              : null,
                        ),
                      ],
                    ],
                  );
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

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends ConsumerWidget {
  final List<Local> todos;
  const _Header({required this.todos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mercados = ref.watch(mercadosProvider).value ?? [];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Locales con Deuda',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Listado de locales con pagos pendientes acumulados',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Exportar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEE5A6F),
            foregroundColor: Colors.white,
          ),
          onPressed: todos.isEmpty
              ? null
              : () async {
                  final bytes =
                      await ReportePdfGenerator.generarReporteDeudores(
                        locales: todos,
                        mercados: mercados,
                      );
                  if (kIsWeb) {
                    await descargarPdfWeb(bytes, 'Reporte_Deudores.pdf');
                  } else {
                    await Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name: 'Reporte_Deudores',
                    );
                  }
                },
        ),
      ],
    );
  }
}

// ── Tabla ─────────────────────────────────────────────────────────────────────
class _DeudoresTable extends StatelessWidget {
  final List<Local> locales;

  const _DeudoresTable({required this.locales});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Colors.white.withOpacity(0.05),
            ),
            columns: const [
              DataColumn(label: Text('Local')),
              DataColumn(label: Text('Representante')),
              DataColumn(label: Text('Teléfono')),
              DataColumn(label: Text('Cuota Diaria')),
              DataColumn(label: Text('Deuda Acumulada')),
              DataColumn(label: Text('Balance Neto')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: locales.map((l) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.nombreSocial ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          l.id ?? '-',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(l.representante ?? '-')),
                  DataCell(
                    Text(
                      l.telefonoRepresentante ?? '-',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  DataCell(Text(DateFormatter.formatCurrency(l.cuotaDiaria))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormatter.formatCurrency(l.deudaAcumulada),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      DateFormatter.formatCurrency(l.balanceNeto),
                      style: TextStyle(
                        color: l.balanceNeto >= 0
                            ? const Color(0xFF00D9A6)
                            : const Color(0xFFEE5A6F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 20),
                          onPressed: () => context.push(
                            '/locales/${l.id}/historial',
                            extra: l,
                          ),
                          tooltip: 'Ver Historial',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Paginación ────────────────────────────────────────────────────────────────
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
