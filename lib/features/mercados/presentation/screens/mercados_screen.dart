import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
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
    });
    await ref.read(mercadosPaginadosProvider.notifier).restablecerFiltros();
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

  Future<void> _abrirFiltrosBottomSheet({
    required BuildContext context,
    required MercadosPaginadosNotifier notifier,
    required MercadosPaginadosState state,
  }) async {
    var ordenarAsc = state.ordenarNombreAsc;
    var estadoFilter = state.estadoFilter;

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
              await notifier.aplicarFiltros(
                searchQuery: _searchCtrl.text,
                searchColumn: _searchColumn,
                ordenarNombreAsc: ordenarAsc,
                estadoFilter: estadoFilter,
              );
              if (mounted) {
                setState(() => _estadoFilter = estadoFilter);
              }
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            }

            Future<void> resetAndClose() async {
              _debounce?.cancel();
              _searchCtrl.clear();
              if (mounted) {
                setState(() {
                  _searchColumn = 'Todos';
                  _estadoFilter = 'Todos';
                });
              }
              await notifier.restablecerFiltros();
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
                                colorScheme.secondaryContainer.withValues(
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
                                  Icons.tune_rounded,
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
                                      'Filtros de Mercados',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'Ajusta el orden para revisar mas rapido.',
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
                                    Icons.toggle_on_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estado',
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
                                    child: _StatusModeChip(
                                      label: 'Todos',
                                      selected: estadoFilter == 'Todos',
                                      onTap: () => setSheetState(
                                        () => estadoFilter = 'Todos',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Activo',
                                      selected: estadoFilter == 'Activo',
                                      onTap: () => setSheetState(
                                        () => estadoFilter = 'Activo',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatusModeChip(
                                      label: 'Inactivo',
                                      selected: estadoFilter == 'Inactivo',
                                      onTap: () => setSheetState(
                                        () => estadoFilter = 'Inactivo',
                                      ),
                                    ),
                                  ),
                                ],
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
                  onReload: notifier.recargar,
                  onOpenFilters: () => _abrirFiltrosBottomSheet(
                    context: context,
                    notifier: notifier,
                    state: state,
                  ),
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
                              return _MercadosTable(
                                mercados: state.mercados,
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
                            isCargando: state.cargando,
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

  void _confirmDelete(BuildContext context, Mercado mercado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Mercado'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el mercado "${mercado.nombre}"?',
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
  final VoidCallback onReload;
  final VoidCallback onOpenFilters;
  final VoidCallback onResetFilters;

  const _MercadosHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.onAdd,
    required this.selectedColumn,
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
        DropdownMenuItem(value: 'Ubicacion', child: Text('Ubicacion')),
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

class _StatusModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusModeChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _MercadosTable extends StatelessWidget {
  final List<Mercado> mercados;
  final ValueChanged<Mercado> onEdit;
  final ValueChanged<Mercado> onDelete;

  const _MercadosTable({
    required this.mercados,
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
                  columns: const [
                    DataColumn(label: Text('Mercado')),
                    DataColumn(label: Text('Ubicacion')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Fecha creacion')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: mercados.map((m) {
                    final nombre =
                        (m.nombre == null || m.nombre!.trim().isEmpty)
                        ? '-'
                        : m.nombre!.trim();
                    final initial = nombre == '-'
                        ? 'M'
                        : nombre.substring(0, 1).toUpperCase();

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
                                  initial,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(nombre),
                            ],
                          ),
                        ),
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
