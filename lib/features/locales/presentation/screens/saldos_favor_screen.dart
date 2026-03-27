import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/reporte_pdf_generator.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../usuarios/domain/entities/usuario.dart';
import '../../domain/entities/local.dart';
import '../../../../core/widgets/usuario_filter.dart';
import '../viewmodels/locales_paginados_notifier.dart';
import '../widgets/local_detalle_panel.dart';
import '../../../../core/widgets/sortable_column.dart';

class SaldosFavorScreen extends ConsumerStatefulWidget {
  const SaldosFavorScreen({super.key});

  @override
  ConsumerState<SaldosFavorScreen> createState() => _SaldosFavorScreenState();
}

class _SaldosFavorScreenState extends ConsumerState<SaldosFavorScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Local? _localSeleccionado;
  final FocusNode _tableFocusNode = FocusNode();

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      ref.read(localesPaginadosProvider.notifier).aplicarBusqueda(value);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = ref.read(localesPaginadosProvider);
      final notifier = ref.read(localesPaginadosProvider.notifier);

      // 1) Forzar filtro de saldos a favor
      if (state.filtroDeuda != LocalFiltroDeuda.soloSaldosAFavor) {
        await notifier.cambiarFiltroDeuda(LocalFiltroDeuda.soloSaldosAFavor);
      } else if (state.locales.isEmpty) {
        // Si ya estaba en el filtro correcto pero no hay datos cargados, recargar.
        await notifier.recargar();
      }

      // 2) Limpiar búsqueda heredada de otras pantallas para no quedar en blanco
      if ((state.busqueda ?? '').isNotEmpty) {
        await notifier.aplicarBusqueda('');
      }
      if (mounted) {
        _searchCtrl.text = '';
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  void _moverSeleccion(int delta, List<Local> localesActuales) {
    if (localesActuales.isEmpty) return;
    if (_localSeleccionado == null) {
      if (delta > 0) {
        setState(() => _localSeleccionado = localesActuales.first);
      }
      return;
    }
    final currentIndex = localesActuales.indexWhere(
      (l) => l.id == _localSeleccionado!.id,
    );
    if (currentIndex == -1) {
      setState(() => _localSeleccionado = localesActuales.first);
      return;
    }
    final nextIndex = currentIndex + delta;
    if (nextIndex >= 0 && nextIndex < localesActuales.length) {
      setState(() => _localSeleccionado = localesActuales[nextIndex]);
    }
  }

  Future<void> _restablecerFiltrosVisuales(
    LocalesPaginadosNotifier notifier,
    LocalesPaginadosState state,
  ) async {
    _searchCtrl.clear();
    if ((state.busqueda ?? '').isNotEmpty) {
      await notifier.aplicarBusqueda('');
    }
    if (state.usuarioFiltradoId != null) {
      await notifier.seleccionarUsuario(null);
    }
    if (state.filtroDeuda != LocalFiltroDeuda.soloSaldosAFavor) {
      await notifier.cambiarFiltroDeuda(LocalFiltroDeuda.soloSaldosAFavor);
    }
  }

  void _onLocalTapped(BuildContext context, Local local, bool isWide) {
    if (isWide) {
      setState(() {
        _localSeleccionado = _localSeleccionado?.id == local.id ? null : local;
      });
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            child: LocalDetallePanel(
              local: local,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localesPaginadosProvider);
    final notifier = ref.read(localesPaginadosProvider.notifier);
    final mercados = ref.watch(mercadosProvider).value ?? [];
    final list = state.locales;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 700;
          final isWide = outerConstraints.maxWidth > 900;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SaldosFavorHeader(
                  paginaActual: state.paginaActual,
                  totalRegistros: list.length,
                  searchController: _searchCtrl,
                  onSearch: _onSearchChanged,
                  selectedUsuarioId: state.usuarioFiltradoId,
                  onUsuarioChanged: (u) => notifier.seleccionarUsuario(u?.id),
                  onReload: notifier.recargar,
                  onResetFilters: () =>
                      _restablecerFiltrosVisuales(notifier, state),
                  todosPagina: list,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Focus(
                    focusNode: _tableFocusNode,
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          _moverSeleccion(1, list);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          _moverSeleccion(-1, list);
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Columna izquierda: tabla + paginación
                            Expanded(
                              flex: 13,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        if (state.cargando && list.isEmpty) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        if (state.errorMsg != null &&
                                            list.isEmpty) {
                                          return Center(
                                            child: Text(
                                              'Error: ${state.errorMsg}',
                                              style: TextStyle(
                                                color: context
                                                    .semanticColors
                                                    .danger,
                                              ),
                                            ),
                                          );
                                        }
                                        if (list.isEmpty) {
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                  'No hay locales con saldo a favor',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.54,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return _SaldosTable(
                                          locales: list,
                                          mercados: mercados,
                                          selectedLocalId:
                                              _localSeleccionado?.id,
                                          onSelect: (l) => _onLocalTapped(
                                            context,
                                            l,
                                            isWide,
                                          ),
                                          sortColumn: state.sortColumn,
                                          sortAsc: state.sortAsc,
                                          onSort: notifier.cambiarOrdenamiento,
                                        );
                                      },
                                    ),
                                  ),
                                  if (!isWide && state.totalPaginas > 0)
                                    _PaginationBar(
                                      currentPage: state.paginaActual,
                                      totalPages: state.totalPaginas,
                                      onPrev: state.paginaActual > 1
                                          ? () => notifier.irAPaginaAnterior()
                                          : null,
                                      onNext:
                                          state.paginaActual <
                                              state.totalPaginas
                                          ? () => notifier.irAPaginaSiguiente()
                                          : null,
                                      isCargando: state.cargando,
                                    ),
                                ],
                              ),
                            ),
                            // Panel lateral de detalles (solo en desktop)
                            if (isWide) ...[
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
                                      child: _localSeleccionado != null
                                          ? LocalDetallePanel(
                                              local: _localSeleccionado!,
                                              onClose: () => setState(
                                                () => _localSeleccionado = null,
                                              ),
                                            )
                                          : const PanelDetalleVacio(),
                                    ),
                                    if (state.totalPaginas > 0)
                                      _PaginationBar(
                                        currentPage: state.paginaActual,
                                        totalPages: state.totalPaginas,
                                        onPrev: state.paginaActual > 1
                                            ? () => notifier.irAPaginaAnterior()
                                            : null,
                                        onNext:
                                            state.paginaActual <
                                                state.totalPaginas
                                            ? () =>
                                                  notifier.irAPaginaSiguiente()
                                            : null,
                                        isCargando: state.cargando,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

// Header estilo web (igual patron mercados/correlativos)
class _SaldosFavorHeader extends ConsumerWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final String? selectedUsuarioId;
  final ValueChanged<Usuario?> onUsuarioChanged;
  final VoidCallback onReload;
  final VoidCallback onResetFilters;
  final List<Local> todosPagina;

  const _SaldosFavorHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.selectedUsuarioId,
    required this.onUsuarioChanged,
    required this.onReload,
    required this.onResetFilters,
    required this.todosPagina,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final mercados = ref.watch(mercadosProvider).value ?? [];
    final esCobrador =
        ref.watch(currentUsuarioProvider).value?.esCobrador ?? true;

    Future<void> exportarPdf() async {
      try {
        final municipalidadNombre = ref
            .read(municipalidadActualProvider)
            ?.nombre;
        final bytes = await ReportePdfGenerator.generarReporteSaldosFavor(
          locales: todosPagina,
          mercados: mercados,
          municipalidadNombre: municipalidadNombre,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'Reporte_SaldosAFavor.pdf',
        );
      } catch (e, st) {
        debugPrint('Error al exportar PDF: $e\n$st');
      }
    }

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
                      onPressed: onReload,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Recargar'),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: compactStyle,
                      onPressed: onResetFilters,
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
                        backgroundColor: context.semanticColors.success,
                        foregroundColor: context.semanticColors.onSuccess,
                      ),
                      onPressed: todosPagina.isEmpty ? null : exportarPdf,
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
                    Icons.account_balance_wallet_rounded,
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
                        'Saldos a favor',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                      ),
                      Text(
                        'Pagina $paginaActual - $totalRegistros registros',
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

            Widget filtersDesktop() {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _SaldosSearchInput(
                      controller: searchController,
                      onChanged: onSearch,
                    ),
                  ),
                  if (!esCobrador) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 270,
                      child: UsuarioFilter(
                        selectedUsuarioId: selectedUsuarioId,
                        onUsuarioChanged: onUsuarioChanged,
                      ),
                    ),
                  ],
                ],
              );
            }

            Widget filtersTablet() {
              return Column(
                children: [
                  _SaldosSearchInput(
                    controller: searchController,
                    onChanged: onSearch,
                  ),
                  if (!esCobrador) ...[
                    const SizedBox(height: 8),
                    UsuarioFilter(
                      selectedUsuarioId: selectedUsuarioId,
                      onUsuarioChanged: onUsuarioChanged,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.semanticColors.success.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.semanticColors.success.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Text(
                        'Solo saldos a favor',
                        style: TextStyle(
                          color: context.semanticColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
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
              child: isTablet || isMobile ? filtersTablet() : filtersDesktop(),
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
}

class _SaldosSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SaldosSearchInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Buscar local',
        hintText: 'Local, cobrador, boleta/código, representante...',
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

class _SaldosTable extends StatelessWidget {
  final List<Local> locales;
  final List<Mercado> mercados;
  final String? selectedLocalId;
  final ValueChanged<Local> onSelect;
  final String? sortColumn;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  const _SaldosTable({
    required this.locales,
    required this.mercados,
    required this.onSelect,
    this.selectedLocalId,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          colorScheme.primary.withAlpha(13),
        ),
        horizontalMargin: 16,
        columnSpacing: 24,
        showCheckboxColumn: false,
        columns: [
          DataColumn(
            label: SortableColumn(
              label: 'Local',
              isActive: sortColumn == 'Local',
              ascending: sortAsc,
              onTap: () => onSort('Local'),
            ),
          ),
          DataColumn(
            numeric: true,
            label: SortableColumn(
              label: 'Saldo a favor',
              isActive: sortColumn == 'Saldo',
              ascending: sortAsc,
              onTap: () => onSort('Saldo'),
            ),
          ),
          DataColumn(
            numeric: true,
            label: SortableColumn(
              label: 'Balance neto',
              isActive: sortColumn == 'Balance',
              ascending: sortAsc,
              onTap: () => onSort('Balance'),
            ),
          ),
        ],
        rows: locales.map((l) {
          final nombre =
              (l.nombreSocial == null || l.nombreSocial!.trim().isEmpty)
              ? '-'
              : l.nombreSocial!.trim();

          return DataRow(
            selected: selectedLocalId == l.id,
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary.withValues(alpha: 0.15);
              }
              return null;
            }),
            onSelectChanged: (_) => onSelect(l),
            cells: [
              DataCell(
                SizedBox(
                  width: 220,
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                _MoneyChip(
                  value: (l.saldoAFavor ?? 0).toDouble(),
                  isPositive: true,
                ),
              ),
              DataCell(
                _MoneyChip(
                  value: l.balanceNeto.toDouble(),
                  isPositive: l.balanceNeto >= 0,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  final double value;
  final bool isPositive;

  const _MoneyChip({required this.value, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final color = isPositive ? semantic.success : semantic.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        DateFormatter.formatCurrency(value),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
            tooltip: 'Pagina anterior',
          ),
          const SizedBox(width: 8),
          Text(
            'Pagina $currentPage de $totalPages',
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
            tooltip: 'Pagina siguiente',
          ),
        ],
      ),
    );
  }
}
