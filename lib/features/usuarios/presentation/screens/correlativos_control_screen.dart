import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/usuario.dart';
import '../viewmodels/usuarios_paginados_notifier.dart';

class CorrelativosControlScreen extends ConsumerStatefulWidget {
  const CorrelativosControlScreen({super.key});

  @override
  ConsumerState<CorrelativosControlScreen> createState() =>
      _CorrelativosControlScreenState();
}

class _CorrelativosControlScreenState
    extends ConsumerState<CorrelativosControlScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchColumn = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(usuariosPaginadosProvider.notifier);
      final state = ref.read(usuariosPaginadosProvider);
      if (state.usuarios.isEmpty && !state.cargando) {
        notifier.cargarPagina(reiniciar: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(usuariosPaginadosProvider.notifier)
          .aplicarFiltros(searchQuery: value, searchColumn: _searchColumn);
    });
  }

  Future<void> _limpiarFiltros() async {
    _debounce?.cancel();
    setState(() {
      _searchColumn = 'Todos';
      _searchCtrl.clear();
    });
    await ref.read(usuariosPaginadosProvider.notifier).restablecerFiltros();
  }

  Future<void> _abrirFiltrosBottomSheet({
    required BuildContext context,
    required UsuariosPaginadosNotifier notifier,
    required UsuariosPaginadosState state,
  }) async {
    var ordenarAsc = state.ordenarNombreAsc;

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
              await notifier.aplicarFiltros(ordenarNombreAsc: ordenarAsc);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            }

            Future<void> resetAndClose() async {
              await notifier.aplicarFiltros(ordenarNombreAsc: true);
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
                                colorScheme.tertiaryContainer.withValues(
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
                                  Icons.filter_alt_rounded,
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
                                      'Filtros de Correlativos',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'Ordena la lista para priorizar revisión.',
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
                                    'Orden alfabetico',
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
                                      selected: ordenarAsc,
                                      onTap: () => setSheetState(
                                        () => ordenarAsc = true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OrderModeChip(
                                      label: 'Z - A',
                                      selected: !ordenarAsc,
                                      onTap: () => setSheetState(
                                        () => ordenarAsc = false,
                                      ),
                                    ),
                                  ),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usuariosPaginadosProvider);
    final notifier = ref.read(usuariosPaginadosProvider.notifier);
    final usuarios = state.usuarios.where((u) => u.esCobrador).toList();
    final isMobile = MediaQuery.sizeOf(context).width <= 760;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: isMobile
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
            : const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CorrelativosHeader(
              paginaActual: state.paginaActual,
              totalRegistros: state.totalRegistros,
              searchController: _searchCtrl,
              selectedColumn: _searchColumn,
              onSearch: _onSearchChanged,
              onColumnChanged: (value) {
                if (value == null) return;
                setState(() => _searchColumn = value);
                ref
                    .read(usuariosPaginadosProvider.notifier)
                    .aplicarFiltros(
                      searchQuery: _searchCtrl.text,
                      searchColumn: value,
                    );
              },
              onReload: notifier.recargar,
              onOpenFilters: () => _abrirFiltrosBottomSheet(
                context: context,
                notifier: notifier,
                state: state,
              ),
              onResetFilters: () => _limpiarFiltros(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _CorrelativosContent(
                state: state,
                usuarios: usuarios,
                onPrev: state.paginaActual > 1
                    ? notifier.irAPaginaAnterior
                    : null,
                onNext: state.paginaActual < state.totalPaginas
                    ? notifier.irAPaginaSiguiente
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrelativosHeader extends StatelessWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final String selectedColumn;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onColumnChanged;
  final VoidCallback onReload;
  final VoidCallback onOpenFilters;
  final VoidCallback onResetFilters;

  const _CorrelativosHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.selectedColumn,
    required this.onSearch,
    required this.onColumnChanged,
    required this.onReload,
    required this.onOpenFilters,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                      onPressed: onOpenFilters,
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: const Text('Filtros'),
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
                    Icons.tag_rounded,
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
                        'Control de correlativos',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                      ),
                      Text(
                        'Página $paginaActual - $totalRegistros registros',
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
                  SizedBox(
                    width: 220,
                    child: _SearchColumnDropdown(
                      value: selectedColumn,
                      onChanged: onColumnChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SearchInput(
                      controller: searchController,
                      onChanged: onSearch,
                    ),
                  ),
                ],
              );
            }

            Widget filtersTablet() {
              return Column(
                children: [
                  _SearchColumnDropdown(
                    value: selectedColumn,
                    onChanged: onColumnChanged,
                  ),
                  const SizedBox(height: 8),
                  _SearchInput(
                    controller: searchController,
                    onChanged: onSearch,
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

class _SearchColumnDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _SearchColumnDropdown({required this.value, required this.onChanged});

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
        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
        DropdownMenuItem(value: 'Nombre', child: Text('Nombre')),
        DropdownMenuItem(value: 'Codigo', child: Text('Código')),
        DropdownMenuItem(value: 'Anio', child: Text('Año')),
        DropdownMenuItem(
          value: 'Ultimo correlativo',
          child: Text('Último correlativo'),
        ),
        DropdownMenuItem(value: 'Estado', child: Text('Estado')),
      ],
      onChanged: onChanged,
    );
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Buscar cobrador',
        hintText: 'Nombre, código, año, correlativo o estado...',
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

class _CorrelativosContent extends StatelessWidget {
  final UsuariosPaginadosState state;
  final List<Usuario> usuarios;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _CorrelativosContent({
    required this.state,
    required this.usuarios,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.cargando && usuarios.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMsg != null && usuarios.isEmpty) {
                  return Center(
                    child: Text(
                      'Error: ${state.errorMsg}',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  );
                }
                if (usuarios.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay cobradores registrados',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  );
                }
                return _CorrelativosTable(usuarios: usuarios);
              },
            ),
          ),
          if (state.totalRegistros > 0)
            _PaginationBar(
              currentPage: state.paginaActual,
              totalPages: state.totalPaginas,
              onPrev: onPrev,
              onNext: onNext,
              isCargando: state.cargando,
            ),
        ],
      ),
    );
  }
}

class _CorrelativosTable extends StatelessWidget {
  final List<Usuario> usuarios;

  const _CorrelativosTable({required this.usuarios});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const sidePadding = 16.0;
        final availableWidth = constraints.maxWidth;
        final minTableWidth = availableWidth < 980 ? 980.0 : availableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minTableWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                sidePadding,
                8,
                sidePadding,
                8,
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    colorScheme.primary.withAlpha(13),
                  ),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Cobrador')),
                    DataColumn(label: Text('Código (Prefijo)')),
                    DataColumn(label: Text('Año')),
                    DataColumn(label: Text('Último Correlativo')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: usuarios.map((u) {
                    final ultimoC = u.ultimoCorrelativo ?? 0;
                    final codigo = u.codigoCobrador ?? 'SIN ASIGNAR';
                    final anio = u.anioCorrelativo ?? DateTime.now().year;

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: colorScheme.primary.withAlpha(
                                  26,
                                ),
                                child: Text(
                                  u.nombre?.substring(0, 1).toUpperCase() ??
                                      'U',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(u.nombre ?? ''),
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              codigo,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(anio.toString())),
                        DataCell(
                          Text(
                            ultimoC.toString().padLeft(4, '0'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(_StatusBadge(ultimoC: ultimoC)),
                        DataCell(
                          OutlinedButton.icon(
                            icon: const Icon(Icons.list_alt_rounded, size: 16),
                            label: const Text('Ver'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              foregroundColor: colorScheme.primary,
                            ),
                            onPressed: () {
                              context.pushNamed(
                                'cobrador-cobros-admin',
                                extra: u,
                              );
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
        );
      },
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
            'Página $currentPage de $totalPages',
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

class _StatusBadge extends StatelessWidget {
  final int ultimoC;
  const _StatusBadge({required this.ultimoC});

  @override
  Widget build(BuildContext context) {
    final isActivo = ultimoC > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActivo
            ? Colors.green.withAlpha(26)
            : Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActivo
              ? Colors.green.withAlpha(77)
              : Colors.orange.withAlpha(77),
        ),
      ),
      child: Text(
        isActivo ? 'Activo' : 'Sin cobros',
        style: TextStyle(
          color: isActivo ? Colors.green : Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
