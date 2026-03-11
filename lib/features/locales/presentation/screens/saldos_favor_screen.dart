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
import '../viewmodels/locales_paginados_notifier.dart';


class SaldosFavorScreen extends ConsumerStatefulWidget {
  const SaldosFavorScreen({super.key});

  @override
  ConsumerState<SaldosFavorScreen> createState() => _SaldosFavorScreenState();
}

class _SaldosFavorScreenState extends ConsumerState<SaldosFavorScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localesPaginadosProvider);
    final notifier = ref.read(localesPaginadosProvider.notifier);
    final mercados = ref.watch(mercadosProvider).value ?? [];

    // Al iniciar, aseguramos que el filtro sea solo saldos a favor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.filtroDeuda != LocalFiltroDeuda.soloSaldosAFavor) {
        notifier.cambiarFiltroDeuda(LocalFiltroDeuda.soloSaldosAFavor);
      }
    });

    final list = state.locales;

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
                SizedBox(
                  width: 350,
                  child: TextField(
                    onChanged: (val) => notifier.aplicarBusqueda(val),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre de local...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Filtro: Saldos a Favor',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF00D9A6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                children: [
                  if (state.cargando && list.isEmpty)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.errorMsg != null)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Error: ${state.errorMsg}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    )
                  else if (list.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.query_stats_rounded,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.24),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay locales con saldo a favor actualmente',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(todos: list),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _SaldosTable(
                              locales: list,
                              mercados: mercados,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _PaginationBar(
                            currentPage: state.paginaActual - 1,
                            totalPages: state.hayMas
                                ? state.paginaActual + 1
                                : state.paginaActual,
                            totalItems: list.length,
                            pageSize: 20,
                            onPrev: state.paginaActual > 1
                                ? () => notifier.irAPaginaAnterior()
                                : null,
                            onNext: state.hayMas
                                ? () => notifier.irAPaginaSiguiente()
                                : null,
                          ),
                        ],
                      ),
                    ),
                  if (state.cargando && list.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Header con botón Exportar PDF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â”€â”€ Tabla â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SaldosTable extends StatelessWidget {
  final List<Local> locales;
  final List<Mercado> mercados;

  const _SaldosTable({required this.locales, required this.mercados});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
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

// â”€â”€ Paginación â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrev,
          color: onPrev != null
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página anterior',
        ),
        const SizedBox(width: 8),
        Text(
          'Página ${currentPage + 1}',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.54),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
          color: onNext != null
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página siguiente',
        ),
      ],
    );
  }
}
