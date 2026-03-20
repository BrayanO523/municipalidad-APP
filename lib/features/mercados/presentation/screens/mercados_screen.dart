import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../../core/widgets/sortable_column.dart';
import '../../data/models/mercado_model.dart';
import '../../domain/entities/mercado.dart';
import '../widgets/map_picker_modal.dart';
import '../viewmodels/mercados_paginados_notifier.dart';

class MercadosScreen extends ConsumerStatefulWidget {
  const MercadosScreen({super.key});

  @override
  ConsumerState<MercadosScreen> createState() => _MercadosScreenState();
}

class _MercadosScreenState extends ConsumerState<MercadosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchColumn = 'Todos';
  String _estadoFilter = 'Todos';
  String? _sortColumn;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mercadosPaginadosProvider.notifier).cargarPagina();
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
          .read(mercadosPaginadosProvider.notifier)
          .aplicarFiltros(
            searchQuery: value,
            searchColumn: _searchColumn,
            estadoFilter: _estadoFilter,
          );
    });
  }

  Future<void> _limpiarFiltros() async {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searchColumn = 'Todos';
      _estadoFilter = 'Todos';
      _sortColumn = null;
      _sortAsc = true;
    });
    await ref.read(mercadosPaginadosProvider.notifier).restablecerFiltros();
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

  List<Mercado> _applySort(List<Mercado> lista) {
    if (_sortColumn == null) return lista;
    final sorted = List<Mercado>.from(lista);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'Nombre':
          cmp = (a.nombre ?? '').toLowerCase().compareTo(
            (b.nombre ?? '').toLowerCase(),
          );
        case 'Ubicacion':
          cmp = (a.ubicacion ?? '').toLowerCase().compareTo(
            (b.ubicacion ?? '').toLowerCase(),
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

  Future<LatLng?> _obtenerUbicacionActual() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mercadosPaginadosProvider);
    final notifier = ref.read(mercadosPaginadosProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

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
                _MercadosHeader(
                  paginaActual: state.paginaActual,
                  totalRegistros: state.totalRegistros,
                  searchController: _searchCtrl,
                  onSearch: _onSearchChanged,
                  onAdd: () => _showFormDialog(context),
                  selectedColumn: _searchColumn,
                  onColumnChanged: (val) {
                    if (val != null) {
                      setState(() => _searchColumn = val);
                      notifier.aplicarFiltros(
                        searchQuery: _searchCtrl.text,
                        searchColumn: val,
                        estadoFilter: _estadoFilter,
                      );
                    }
                  },
                  estadoFilter: _estadoFilter,
                  onEstadoChanged: (val) {
                    if (val != null) {
                      setState(() => _estadoFilter = val);
                      notifier.aplicarFiltros(
                        searchQuery: _searchCtrl.text,
                        searchColumn: _searchColumn,
                        estadoFilter: val,
                      );
                    }
                  },
                  onReload: notifier.recargar,
                  onResetFilters: () => _limpiarFiltros(),
                ),
                const SizedBox(height: 20),
                Expanded(
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
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (state.cargando && state.mercados.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (state.errorMsg != null &&
                                  state.mercados.isEmpty) {
                                return Center(
                                  child: Text(
                                    state.errorMsg!,
                                    style: TextStyle(
                                      color: context.semanticColors.danger,
                                    ),
                                  ),
                                );
                              }
                              if (state.mercados.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No se encontraron mercados',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.54,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final sorted = _applySort(state.mercados);
                              return _MercadosTable(
                                mercados: sorted,
                                sortColumn: _sortColumn,
                                sortAsc: _sortAsc,
                                onSort: _toggleSort,
                                onEdit: (m) =>
                                    _showFormDialog(context, mercado: m),
                                onDelete: (m) => _confirmDelete(context, m),
                              );
                            },
                          ),
                        ),
                        if (state.totalRegistros > 0)
                          _PaginationBar(
                            currentPage: state.paginaActual,
                            totalPages: state.totalPaginas,
                            isCargando: state.cargando,
                            onPrev: state.paginaActual > 1
                                ? () => ref
                                      .read(mercadosPaginadosProvider.notifier)
                                      .irAPaginaAnterior()
                                : null,
                            onNext: state.paginaActual < state.totalPaginas
                                ? () => ref
                                      .read(mercadosPaginadosProvider.notifier)
                                      .irAPaginaSiguiente()
                                : null,
                          ),
                      ],
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

  Future<void> _confirmDelete(BuildContext context, Mercado mercado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Mercado'),
        content: Text(
          '¿Estas seguro de que deseas eliminar el mercado "${mercado.nombre}"?',
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
      final ds = ref.read(mercadoDatasourceProvider);
      await ds.eliminar(mercado.id!);
      ref.read(mercadosPaginadosProvider.notifier).recargar();
    }
  }

  void _showFormDialog(BuildContext context, {Mercado? mercado}) {
    final isEditing = mercado != null;
    final nombreCtrl = TextEditingController(text: mercado?.nombre);
    final ubicacionCtrl = TextEditingController(text: mercado?.ubicacion);
    final currentAdmin = ref.read(currentUsuarioProvider).value;
    String? selectedMunicipalidadId =
        mercado?.municipalidadId ?? currentAdmin?.municipalidadId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Mercado' : 'Nuevo Mercado'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ubicacionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación Descriptiva',
                    hintText: 'Ej. Zona 1, frente al parque',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    Icons.map_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    'Perímetro del Mercado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    mercado?.perimetro != null ||
                            (mercado?.perimetro?.isNotEmpty ?? false)
                        ? 'Área definida (${mercado!.perimetro!.length} puntos)'
                        : 'Sin definir en el mapa',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.24),
                  ),
                  onTap: () async {
                    final currentLocation = await _obtenerUbicacionActual();
                    if (!context.mounted) return;

                    final List<LatLng>? result = await showDialog<List<LatLng>>(
                      context: context,
                      builder: (ctx) => MapPickerModal(
                        mode: MapPickerMode.polygon,
                        initialCenter: currentLocation,
                        initialPoints: mercado?.perimetro
                            ?.map((p) => LatLng(p['lat']!, p['lng']!))
                            .toList(),
                      ),
                    );

                    if (result != null) {
                      setDialogState(() {
                        mercado = Mercado(
                          id: mercado?.id,
                          nombre: nombreCtrl.text,
                          ubicacion: ubicacionCtrl.text,
                          perimetro: result
                              .map(
                                (p) => {'lat': p.latitude, 'lng': p.longitude},
                              )
                              .toList(),
                          latitud: result.first.latitude,
                          longitud: result.first.longitude,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMunicipalidadId == null) return;
                final ds = ref.read(mercadoDatasourceProvider);
                final now = DateTime.now();

                final docId = isEditing
                    ? mercado!.id!
                    : IdNormalizer.mercadoId(
                        currentAdmin?.municipalidadId ?? 'MUN',
                        nombreCtrl.text,
                      );

                final model = MercadoJson(
                  activo: true,
                  actualizadoEn: now,
                  actualizadoPor: 'admin',
                  creadoEn: isEditing ? mercado!.creadoEn : now,
                  creadoPor: isEditing ? mercado!.creadoPor : 'admin',
                  id: docId,
                  municipalidadId: selectedMunicipalidadId,
                  nombre: nombreCtrl.text,
                  ubicacion: ubicacionCtrl.text,
                  perimetro: mercado?.perimetro,
                  latitud: mercado?.latitud,
                  longitud: mercado?.longitud,
                );

                if (isEditing) {
                  await ds.actualizar(docId, model.toJson());
                } else {
                  await ds.crear(docId, model.toJson());
                }
                ref.read(mercadosPaginadosProvider.notifier).recargar();
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

class _MercadosHeader extends StatelessWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final String selectedColumn;
  final ValueChanged<String?> onColumnChanged;
  final String estadoFilter;
  final ValueChanged<String?> onEstadoChanged;
  final VoidCallback onReload;
  final VoidCallback onResetFilters;

  const _MercadosHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.onAdd,
    required this.selectedColumn,
    required this.onColumnChanged,
    required this.estadoFilter,
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
                    Icons.storefront_rounded,
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
                        'Mercados',
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
                      value: estadoFilter,
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
                          value: estadoFilter,
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
        DropdownMenuItem(value: 'Ubicacion', child: Text('Ubicacion')),
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
        labelText: 'Buscar mercado',
        hintText: 'Nombre, ubicacion o estado...',
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

class _MercadosTable extends StatelessWidget {
  final List<Mercado> mercados;
  final String? sortColumn;
  final bool sortAsc;
  final void Function(String) onSort;
  final ValueChanged<Mercado> onEdit;
  final ValueChanged<Mercado> onDelete;

  const _MercadosTable({
    required this.mercados,
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
                        label: 'Mercado',
                        isActive: sortColumn == 'Nombre',
                        ascending: sortAsc,
                        onTap: () => onSort('Nombre'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Ubicacion',
                        isActive: sortColumn == 'Ubicacion',
                        ascending: sortAsc,
                        onTap: () => onSort('Ubicacion'),
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
                  rows: mercados.map((m) {
                    final nombre =
                        (m.nombre == null || m.nombre!.trim().isEmpty)
                        ? '-'
                        : m.nombre!.trim();

                    return DataRow(
                      cells: [
                        DataCell(Text(nombre)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              (m.ubicacion == null ||
                                      m.ubicacion!.trim().isEmpty)
                                  ? '-'
                                  : m.ubicacion!.trim(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_ActiveChip(active: m.activo ?? false)),
                        DataCell(
                          Text(
                            m.creadoEn != null
                                ? DateFormatter.formatDate(m.creadoEn!)
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
                                onPressed: () => onEdit(m),
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
                                onPressed: () => onDelete(m),
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
