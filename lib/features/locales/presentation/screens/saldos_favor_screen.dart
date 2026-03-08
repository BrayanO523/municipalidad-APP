import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../domain/entities/local.dart';

const _kPageSize = 20;

class SaldosFavorScreen extends ConsumerStatefulWidget {
  const SaldosFavorScreen({super.key});

  @override
  ConsumerState<SaldosFavorScreen> createState() => _SaldosFavorScreenState();
}

class _SaldosFavorScreenState extends ConsumerState<SaldosFavorScreen> {
  String _searchQuery = '';
  String _searchColumn = 'Local';
  int _currentPage = 0;

  static const _columnas = ['Local', 'Mercado', 'Representante', 'Teléfono'];

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
    final mercados = ref.watch(mercadosProvider).value ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header y filtros
            Row(
              children: [
                Container(
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _searchColumn,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
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
                  final withSaldo = list.where((l) {
                    final tieneSaldo = (l.saldoAFavor ?? 0) > 0;
                    if (!tieneSaldo) return false;
                    if (q.isEmpty) return true;
                    switch (_searchColumn) {
                      case 'Local':
                        return (l.nombreSocial ?? '').toLowerCase().contains(q);
                      case 'Mercado':
                        final mercadoName =
                            mercados
                                .cast<Mercado>()
                                .firstWhere(
                                  (m) => m.id == l.mercadoId,
                                  orElse: () => const Mercado(nombre: ''),
                                )
                                .nombre ??
                            '';
                        return mercadoName.toLowerCase().contains(q);
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
                  withSaldo.sort(
                    (a, b) =>
                        (b.saldoAFavor ?? 0).compareTo(a.saldoAFavor ?? 0),
                  );

                  final totalPages = (withSaldo.length / _kPageSize)
                      .ceil()
                      .clamp(1, 99999);
                  final page = _currentPage.clamp(0, totalPages - 1);
                  final paginated = withSaldo.sublist(
                    page * _kPageSize,
                    (page * _kPageSize + _kPageSize).clamp(0, withSaldo.length),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(todos: withSaldo),
                      const SizedBox(height: 16),
                      if (withSaldo.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.query_stats_rounded,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay locales con saldo a favor actualmente',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: _SaldosTable(
                            locales: paginated,
                            mercados: mercados,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PaginationBar(
                          currentPage: page,
                          totalPages: totalPages,
                          totalItems: withSaldo.length,
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

// ── Header con botón Exportar PDF ────────────────────────────────────────────────────────────
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
                'Saldos a Favor',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Listado de locales con crédito prepagado disponible',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Exportar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D9A6),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: todos.isEmpty
              ? null
              : () async {
                  final bytes =
                      await ReportePdfGenerator.generarReporteSaldosFavor(
                        locales: todos,
                        mercados: mercados,
                      );
                  if (kIsWeb) {
                    await descargarPdfWeb(bytes, 'Reporte_SaldosAFavor.pdf');
                  } else {
                    await Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name: 'Reporte_SaldosAFavor',
                    );
                  }
                },
        ),
      ],
    );
  }
}

// ── Tabla ─────────────────────────────────────────────────────────────────────
class _SaldosTable extends StatelessWidget {
  final List<Local> locales;
  final List<Mercado> mercados;

  _SaldosTable({required this.locales, required this.mercados});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            ),
            columns: const [
              DataColumn(label: Text('Local')),
              DataColumn(label: Text('Mercado')),
              DataColumn(label: Text('Representante')),
              DataColumn(label: Text('Teléfono')),
              DataColumn(label: Text('Saldo a Favor')),
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
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      mercados
                              .cast<Mercado>()
                              .firstWhere(
                                (m) => m.id == l.mercadoId,
                                orElse: () => const Mercado(nombre: '-'),
                              )
                              .nombre ??
                          '-',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  DataCell(Text(l.representante ?? '-')),
                  DataCell(
                    Text(
                      l.telefonoRepresentante ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormatter.formatCurrency(l.saldoAFavor),
                        style: const TextStyle(
                          color: Colors.greenAccent,
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
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 20),
                      onPressed: () =>
                          context.push('/locales/${l.id}/historial', extra: l),
                      tooltip: 'Ver Historial',
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
          color: onPrev != null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página anterior',
        ),
        const SizedBox(width: 8),
        Text(
          '$start–$end de $totalItems',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(
          '(Pág. ${currentPage + 1}/$totalPages)',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
          color: onNext != null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página siguiente',
        ),
      ],
    );
  }
}