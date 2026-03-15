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
import '../../../../core/widgets/usuario_filter.dart';
import '../viewmodels/locales_paginados_notifier.dart';


class DeudoresScreen extends ConsumerStatefulWidget {
  const DeudoresScreen({super.key});

  @override
  ConsumerState<DeudoresScreen> createState() => _DeudoresScreenState();
}

class _DeudoresScreenState extends ConsumerState<DeudoresScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localesPaginadosProvider);
    final notifier = ref.read(localesPaginadosProvider.notifier);
    final mercados = ref.watch(mercadosProvider).value ?? [];

    // Al iniciar, aseguramos que el filtro sea solo deudores
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.filtroDeuda != LocalFiltroDeuda.soloDeudores) {
        notifier.cambiarFiltroDeuda(LocalFiltroDeuda.soloDeudores);
      }
    });

    final list = state.locales;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 700;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de filtros siempre visible
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
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
                      const SizedBox(height: 8),
                      Text(
                        'Filtro: Solo Deudores',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 300,
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
                      const SizedBox(width: 16),
                      // Filtro por Cobrador (Admin/Gestión)
                      if (!(ref.watch(currentUsuarioProvider).value?.esCobrador ?? true))
                        SizedBox(
                          width: 250,
                          child: UsuarioFilter(
                            selectedUsuarioId: state.usuarioFiltradoId,
                            onUsuarioChanged: (u) {
                              notifier.seleccionarUsuario(u?.id);
                            },
                          ),
                        ),
                      const Spacer(),
                      Text(
                        'Filtro: Solo Deudores',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.redAccent,
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
                    const Expanded(child: Center(child: CircularProgressIndicator()))
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
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '¡No hay locales con deuda! Todo está al día.',
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
                            child: _DeudoresTable(
                              locales: list,
                              mercados: mercados,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _PaginationBar(
                            currentPage: state.paginaActual - 1,
                            totalPages: state.hayMas ? state.paginaActual + 1 : state.paginaActual,
                            totalItems: list.length, // Con paginación real, esto es parcial
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
        );
        },
      ),
    );
  }
}

// â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Exportar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEE5A6F),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
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

// â”€â”€ Tabla â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DeudoresTable extends StatefulWidget {
  final List<Local> locales;
  final List<Mercado> mercados;

  const _DeudoresTable({required this.locales, required this.mercados});

  @override
  State<_DeudoresTable> createState() => _DeudoresTableState();
}

class _DeudoresTableState extends State<_DeudoresTable> {
  final ScrollController _scrollHorizontal = ScrollController();
  final ScrollController _scrollVertical = ScrollController();

  @override
  void dispose() {
    _scrollHorizontal.dispose();
    _scrollVertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Scrollbar(
        controller: _scrollHorizontal,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollHorizontal,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            controller: _scrollVertical,
            scrollDirection: Axis.vertical,
            child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            columns: const [
              DataColumn(label: Text('Local')),
              DataColumn(label: Text('Mercado')),
              DataColumn(label: Text('Representante')),
              DataColumn(label: Text('Teléfono')),
              DataColumn(label: Text('Cuota Diaria')),
              DataColumn(label: Text('Deuda Acumulada')),
              DataColumn(label: Text('Balance Neto')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: widget.locales.map((l) {
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
                      widget.mercados
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
