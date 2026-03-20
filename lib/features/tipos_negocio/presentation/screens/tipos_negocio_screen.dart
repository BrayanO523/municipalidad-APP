import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../../core/widgets/sortable_column.dart';
import '../../data/models/tipo_negocio_model.dart';
import '../../domain/entities/tipo_negocio.dart';

class TiposNegocioScreen extends ConsumerStatefulWidget {
  const TiposNegocioScreen({super.key});

  @override
  ConsumerState<TiposNegocioScreen> createState() => _TiposNegocioScreenState();
}

class _TiposNegocioScreenState extends ConsumerState<TiposNegocioScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _searchColumn = 'Todos';
  String _estadoFiltro = 'Todos';
  int _paginaActual = 1;
  String? _sortColumn;
  bool _sortAsc = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => setState(() {
        _searchQuery = value;
        _paginaActual = 1;
      }),
    );
  }

  Future<void> _limpiarFiltros() async {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _searchColumn = 'Todos';
      _estadoFiltro = 'Todos';
      _paginaActual = 1;
      _sortColumn = null;
      _sortAsc = true;
    });
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        if (_sortAsc) {
          _sortAsc = false;
        } else {
          _sortColumn = null;
          _sortAsc = true;
        }
      } else {
        _sortColumn = column;
        _sortAsc = true;
      }
    });
  }

  List<TipoNegocio> _applySort(List<TipoNegocio> lista) {
    if (_sortColumn == null) return lista;
    final sorted = List<TipoNegocio>.from(lista);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'Nombre':
          cmp = (a.nombre ?? '').toLowerCase().compareTo(
            (b.nombre ?? '').toLowerCase(),
          );
        case 'Descripcion':
          cmp = (a.descripcion ?? '').toLowerCase().compareTo(
            (b.descripcion ?? '').toLowerCase(),
          );
        case 'Estado':
          final aVal = (a.activo ?? false) ? 1 : 0;
          final bVal = (b.activo ?? false) ? 1 : 0;
          cmp = aVal.compareTo(bVal);
        case 'Fecha':
          cmp = (a.creadoEn ?? DateTime(0)).compareTo(
            b.creadoEn ?? DateTime(0),
          );
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final tiposNegocio = ref.watch(tiposNegocioProvider);
    final totalRegistros = tiposNegocio.asData?.value.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 700;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TiposHeader(
                  paginaActual: _paginaActual,
                  totalRegistros: totalRegistros,
                  searchController: _searchCtrl,
                  onSearch: _onSearchChanged,
                  onAdd: () => _showFormDialog(context),
                  selectedColumn: _searchColumn,
                  onColumnChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _searchColumn = val;
                        _paginaActual = 1;
                      });
                    }
                  },
                  estadoFiltro: _estadoFiltro,
                  onEstadoChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _estadoFiltro = val;
                        _paginaActual = 1;
                      });
                    }
                  },
                  onReload: () {
                    setState(() => _paginaActual = 1);
                    ref.invalidate(tiposNegocioProvider);
                  },
                  onResetFilters: _limpiarFiltros,
                ),
                const SizedBox(height: 20),
                Expanded(
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
                    child: tiposNegocio.when(
                      data: (list) {
                        final query = _searchQuery.trim().toLowerCase();
                        var filtered = list.where((t) {
                          if (_estadoFiltro == 'Activo' && t.activo != true) {
                            return false;
                          }
                          if (_estadoFiltro == 'Inactivo' && t.activo == true) {
                            return false;
                          }
                          if (query.isEmpty) return true;
                          if (_searchColumn == 'Nombre') {
                            return (t.nombre ?? '').toLowerCase().contains(
                              query,
                            );
                          }
                          if (_searchColumn == 'Descripcion') {
                            return (t.descripcion ?? '').toLowerCase().contains(
                              query,
                            );
                          }
                          return (t.nombre ?? '').toLowerCase().contains(
                                query,
                              ) ||
                              (t.descripcion ?? '').toLowerCase().contains(
                                query,
                              );
                        }).toList();

                        filtered = _applySort(filtered);

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              'No se encontraron tipos de negocio',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                              ),
                            ),
                          );
                        }
                        final totalPaginas = (filtered.length / _pageSize)
                            .ceil();
                        final paginaActual = _paginaActual.clamp(
                          1,
                          totalPaginas,
                        );
                        final inicio = (paginaActual - 1) * _pageSize;
                        final fin = (inicio + _pageSize).clamp(
                          0,
                          filtered.length,
                        );
                        final tiposPagina = filtered.sublist(inicio, fin);

                        return Column(
                          children: [
                            Expanded(
                              child: _TiposTable(
                                tipos: tiposPagina,
                                sortColumn: _sortColumn,
                                sortAsc: _sortAsc,
                                onSort: _toggleSort,
                                onEdit: (t) =>
                                    _showFormDialog(context, tipo: t),
                                onDelete: (t) => _confirmDelete(context, t),
                              ),
                            ),
                            _PaginationBar(
                              currentPage: paginaActual,
                              totalPages: totalPaginas,
                              onPrev: paginaActual > 1
                                  ? () => setState(
                                      () => _paginaActual = paginaActual - 1,
                                    )
                                  : null,
                              onNext: paginaActual < totalPaginas
                                  ? () => setState(
                                      () => _paginaActual = paginaActual + 1,
                                    )
                                  : null,
                              isCargando: false,
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          'Error: $e',
                          style: TextStyle(
                            color: context.semanticColors.danger,
                          ),
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

  void _confirmDelete(BuildContext context, TipoNegocio tipo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Tipo de Negocio'),
        content: Text(
          'Estas seguro de que deseas eliminar el tipo de negocio "${tipo.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.semanticColors.danger,
              foregroundColor: context.semanticColors.onDanger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ds = ref.read(tipoNegocioDatasourceProvider);
      await ds.eliminar(tipo.id!);
      if (mounted) setState(() => _paginaActual = 1);
      ref.invalidate(tiposNegocioProvider);
    }
  }

  void _showFormDialog(BuildContext context, {TipoNegocio? tipo}) {
    final isEditing = tipo != null;
    final nombreCtrl = TextEditingController(text: tipo?.nombre);
    final descripcionCtrl = TextEditingController(text: tipo?.descripcion);
    var activo = tipo?.activo ?? true;
    final currentAdmin = ref.read(currentUsuarioProvider).value;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isEditing ? 'Editar Tipo de Negocio' : 'Nuevo Tipo de Negocio',
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: activo,
                  onChanged: (v) => setDialogState(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final ds = ref.read(tipoNegocioDatasourceProvider);
                final docId = isEditing
                    ? tipo.id!
                    : IdNormalizer.tipoNegocioId(nombre);
                final model = TipoNegocioJson(
                  id: docId,
                  nombre: nombre,
                  descripcion: descripcionCtrl.text.trim(),
                  activo: activo,
                  creadoEn: tipo?.creadoEn ?? DateTime.now(),
                  creadoPor: currentAdmin?.id,
                );
                if (isEditing) {
                  await ds.actualizar(docId, model.toJson());
                } else {
                  await ds.crear(docId, model.toJson());
                }
                if (mounted) {
                  setState(() => _paginaActual = 1);
                }
                ref.invalidate(tiposNegocioProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Actualizar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TiposHeader extends StatelessWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final String selectedColumn;
  final ValueChanged<String?> onColumnChanged;
  final String estadoFiltro;
  final ValueChanged<String?> onEstadoChanged;
  final VoidCallback onReload;
  final VoidCallback onResetFilters;

  const _TiposHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.onAdd,
    required this.selectedColumn,
    required this.onColumnChanged,
    required this.estadoFiltro,
    required this.onEstadoChanged,
    required this.onReload,
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
                      ),
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Agregar'),
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
                    Icons.category_rounded,
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
                        'Tipos de negocio',
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
                  SizedBox(
                    width: 200,
                    child: _SearchColumnDropdown(
                      value: selectedColumn,
                      onChanged: onColumnChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: _EstadoDropdown(
                      value: estadoFiltro,
                      onChanged: onEstadoChanged,
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
                  Row(
                    children: [
                      Expanded(
                        child: _SearchColumnDropdown(
                          value: selectedColumn,
                          onChanged: onColumnChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _EstadoDropdown(
                          value: estadoFiltro,
                          onChanged: onEstadoChanged,
                        ),
                      ),
                    ],
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
        DropdownMenuItem(value: 'Descripcion', child: Text('Descripcion')),
      ],
      onChanged: onChanged,
    );
  }
}

class _EstadoDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _EstadoDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.arrow_drop_down_rounded),
      decoration: InputDecoration(
        labelText: 'Estado',
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
        DropdownMenuItem(value: 'Activo', child: Text('Activo')),
        DropdownMenuItem(value: 'Inactivo', child: Text('Inactivo')),
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
        labelText: 'Buscar tipo',
        hintText: 'Nombre o descripcion...',
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

class _TiposTable extends StatelessWidget {
  final List<TipoNegocio> tipos;
  final String? sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final ValueChanged<TipoNegocio> onEdit;
  final ValueChanged<TipoNegocio> onDelete;

  const _TiposTable({
    required this.tipos,
    required this.sortColumn,
    required this.sortAsc,
    required this.onSort,
    required this.onEdit,
    required this.onDelete,
  });

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
                  columns: [
                    DataColumn(
                      label: SortableColumn(
                        label: 'Tipo de negocio',
                        isActive: sortColumn == 'Nombre',
                        ascending: sortAsc,
                        onTap: () => onSort('Nombre'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Descripcion',
                        isActive: sortColumn == 'Descripcion',
                        ascending: sortAsc,
                        onTap: () => onSort('Descripcion'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Estado',
                        isActive: sortColumn == 'Estado',
                        ascending: sortAsc,
                        onTap: () => onSort('Estado'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Fecha creacion',
                        isActive: sortColumn == 'Fecha',
                        ascending: sortAsc,
                        onTap: () => onSort('Fecha'),
                      ),
                    ),
                    const DataColumn(label: Text('Acciones')),
                  ],
                  rows: tipos.map((t) {
                    final nombre =
                        (t.nombre == null || t.nombre!.trim().isEmpty)
                        ? '-'
                        : t.nombre!.trim();

                    return DataRow(
                      cells: [
                        DataCell(Text(nombre)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              (t.descripcion == null ||
                                      t.descripcion!.trim().isEmpty)
                                  ? '-'
                                  : t.descripcion!.trim(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_ActiveChip(active: t.activo ?? false)),
                        DataCell(
                          Text(
                            t.creadoEn != null
                                ? DateFormatter.formatDate(t.creadoEn!)
                                : '-',
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Editar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  foregroundColor: colorScheme.primary,
                                ),
                                onPressed: () => onEdit(t),
                              ),
                              OutlinedButton.icon(
                                icon: Icon(
                                  Icons.delete_rounded,
                                  size: 16,
                                  color: context.semanticColors.danger,
                                ),
                                label: Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: context.semanticColors.danger,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  side: BorderSide(
                                    color: context.semanticColors.danger
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                onPressed: () => onDelete(t),
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

class _ActiveChip extends StatelessWidget {
  final bool active;

  const _ActiveChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? semantic.success : colorScheme.outline).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (active ? semantic.success : colorScheme.outline).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Text(
        active ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: active ? semantic.success : colorScheme.outline,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
