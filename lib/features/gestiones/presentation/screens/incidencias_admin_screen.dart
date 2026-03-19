import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/sortable_column.dart';
import '../../domain/entities/gestion.dart';
import '../viewmodels/incidencias_admin_notifier.dart';

class IncidenciasAdminScreen extends ConsumerStatefulWidget {
  const IncidenciasAdminScreen({super.key});

  @override
  ConsumerState<IncidenciasAdminScreen> createState() =>
      _IncidenciasAdminScreenState();
}

class _IncidenciasAdminScreenState
    extends ConsumerState<IncidenciasAdminScreen> {
  static const int _pageSize = 20;

  DateTime? _fechaFiltro;
  int _paginaActual = 1;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String? _sortColumn;
  bool _sortAsc = true;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim().toLowerCase();
        _paginaActual = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaFiltro = picked;
        _paginaActual = 1;
      });
      ref.read(incidenciasAdminProvider.notifier).filtrarPorFecha(picked);
    }
  }

  void _limpiarFiltroFecha() {
    setState(() {
      _fechaFiltro = null;
      _paginaActual = 1;
    });
    ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
  }

  void _recargarIncidencias() {
    setState(() => _paginaActual = 1);
    if (_fechaFiltro != null) {
      ref
          .read(incidenciasAdminProvider.notifier)
          .filtrarPorFecha(_fechaFiltro!);
    } else {
      ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
    }
  }

  void _restablecerFiltrosVisuales() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _paginaActual = 1;
      _sortColumn = null;
      _sortAsc = true;
    });
    if (_fechaFiltro != null) {
      _limpiarFiltroFecha();
      return;
    }
    ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
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

  List<IncidenciaUI> _applySort(List<IncidenciaUI> lista) {
    if (_sortColumn == null) return lista;
    final sorted = List<IncidenciaUI>.from(lista);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'Local':
          cmp = a.localNombre.toLowerCase().compareTo(
            b.localNombre.toLowerCase(),
          );
        case 'Clave':
          cmp = a.localClave.toLowerCase().compareTo(
            b.localClave.toLowerCase(),
          );
        case 'Tipo':
          cmp = _tipoIncidenciaLabel(a.gestion.tipoIncidencia)
              .toLowerCase()
              .compareTo(
                _tipoIncidenciaLabel(b.gestion.tipoIncidencia).toLowerCase(),
              );
        case 'Comentario':
          cmp = (a.gestion.comentario ?? '').toLowerCase().compareTo(
            (b.gestion.comentario ?? '').toLowerCase(),
          );
        case 'Cobrador':
          cmp = a.cobradorNombre.toLowerCase().compareTo(
            b.cobradorNombre.toLowerCase(),
          );
        case 'Fecha':
          cmp = (a.gestion.timestamp ?? DateTime(2000)).compareTo(
            b.gestion.timestamp ?? DateTime(2000),
          );
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  List<IncidenciaUI> _filtrarPorBusqueda(
    List<IncidenciaUI> incidencias,
    String query,
  ) {
    if (query.isEmpty) return incidencias;
    return incidencias.where((inc) {
      final comentario = (inc.gestion.comentario ?? '').toLowerCase();
      final tipo = _tipoIncidenciaLabel(
        inc.gestion.tipoIncidencia,
      ).toLowerCase();
      return inc.localNombre.toLowerCase().contains(query) ||
          inc.localClave.toLowerCase().contains(query) ||
          inc.localCodigo.toLowerCase().contains(query) ||
          inc.cobradorNombre.toLowerCase().contains(query) ||
          comentario.contains(query) ||
          tipo.contains(query);
    }).toList();
  }

  String _tipoIncidenciaLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    return TipoIncidencia.fromFirestore(raw).label;
  }

  Future<void> _confirmarEliminar(IncidenciaUI incidencia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar incidencia'),
        content: Text(
          'Se eliminara la incidencia de ${incidencia.localNombre}. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    final incidenciaId = incidencia.gestion.id;
    if (incidenciaId == null || incidenciaId.isEmpty) return;

    try {
      await ref
          .read(incidenciasAdminProvider.notifier)
          .eliminarIncidencia(incidenciaId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incidencia eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Future<void> _abrirFormularioIncidencia({IncidenciaUI? incidencia}) async {
    final usuarioActual = ref.read(currentUsuarioProvider).value;
    final municipalidadId = usuarioActual?.municipalidadId;

    if (municipalidadId == null || municipalidadId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontro municipalidad para crear incidencia.'),
        ),
      );
      return;
    }

    final localDs = ref.read(localDatasourceProvider);
    final authDs = ref.read(authDatasourceProvider);

    final localesRaw = await localDs.listarTodos();
    final usuariosRaw = await authDs.listarTodos(
      municipalidadId: municipalidadId,
    );
    if (!mounted) return;

    final locales =
        localesRaw
            .where((l) => l.id != null && l.municipalidadId == municipalidadId)
            .toList()
          ..sort(
            (a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''),
          );
    final cobradores =
        usuariosRaw.where((u) => u.id != null && u.esCobrador).toList()
          ..sort((a, b) => (a.nombre ?? '').compareTo(b.nombre ?? ''));

    if (locales.isEmpty || cobradores.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se requieren locales y cobradores para registrar incidencias.',
          ),
        ),
      );
      return;
    }

    String? localId = incidencia?.gestion.localId;
    String? cobradorId = incidencia?.gestion.cobradorId;
    String tipoIncidencia =
        incidencia?.gestion.tipoIncidencia ??
        TipoIncidencia.otro.firestoreValue;
    final comentarioCtrl = TextEditingController(
      text: incidencia?.gestion.comentario ?? '',
    );

    if (!locales.any((l) => l.id == localId)) {
      localId = locales.first.id;
    }
    if (!cobradores.any((u) => u.id == cobradorId)) {
      cobradorId = cobradores.first.id;
    }

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(
            incidencia == null ? 'Crear incidencia' : 'Editar incidencia',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: localId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Local',
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                    items: locales
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l.id,
                            child: Text(
                              '${l.nombreSocial ?? 'Sin nombre'} | Cod: ${l.codigo ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() => localId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cobradorId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cobrador',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    items: cobradores
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(u.nombre ?? u.email ?? 'Sin nombre'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => cobradorId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tipoIncidencia,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de incidencia',
                      prefixIcon: Icon(Icons.assignment_late_rounded),
                    ),
                    items: TipoIncidencia.values
                        .map(
                          (tipo) => DropdownMenuItem<String>(
                            value: tipo.firestoreValue,
                            child: Text(tipo.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(
                      () => tipoIncidencia = value ?? tipoIncidencia,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comentarioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentario',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(incidencia == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar != true || localId == null || cobradorId == null) return;

    final localSeleccionado = locales.firstWhere((l) => l.id == localId);
    final mercadoId = localSeleccionado.mercadoId;
    final notifier = ref.read(incidenciasAdminProvider.notifier);

    try {
      if (incidencia == null) {
        await notifier.crearIncidencia(
          localId: localId!,
          cobradorId: cobradorId!,
          tipoIncidencia: tipoIncidencia,
          comentario: comentarioCtrl.text.trim(),
          municipalidadId: municipalidadId,
          mercadoId: mercadoId,
        );
      } else {
        final incidenciaId = incidencia.gestion.id;
        if (incidenciaId == null || incidenciaId.isEmpty) {
          throw Exception('Incidencia sin id.');
        }
        await notifier.editarIncidencia(
          id: incidenciaId,
          localId: localId!,
          cobradorId: cobradorId!,
          tipoIncidencia: tipoIncidencia,
          comentario: comentarioCtrl.text.trim(),
          municipalidadId: municipalidadId,
          mercadoId: mercadoId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            incidencia == null
                ? 'Incidencia creada correctamente.'
                : 'Incidencia actualizada correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar incidencia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incidenciasAdminProvider);
    final incidenciasBase = state.maybeWhen(
      data: (value) => value,
      orElse: () => const <IncidenciaUI>[],
    );
    final incidenciasFiltradas = _filtrarPorBusqueda(
      incidenciasBase,
      _searchQuery,
    );

    final incidenciasSorted = _applySort(incidenciasFiltradas);

    final totalPaginas =
        incidenciasSorted.isEmpty
            ? 1
            : (incidenciasSorted.length / _pageSize).ceil();
    final paginaActual = _paginaActual.clamp(1, totalPaginas);
    final inicio = (paginaActual - 1) * _pageSize;
    final fin =
        (inicio + _pageSize > incidenciasSorted.length)
            ? incidenciasSorted.length
            : inicio + _pageSize;
    final incidenciasPagina =
        incidenciasSorted.isEmpty
            ? const <IncidenciaUI>[]
            : incidenciasSorted.sublist(inicio, fin);

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
                _IncidenciasHeader(
                  paginaActual: paginaActual,
                  totalRegistros: incidenciasFiltradas.length,
                  searchController: _searchCtrl,
                  onSearch: _onSearchChanged,
                  fechaFiltro: _fechaFiltro,
                  onSelectFecha: _seleccionarFecha,
                  onClearFecha: _limpiarFiltroFecha,
                  onReload: _recargarIncidencias,
                  onResetFilters: _restablecerFiltrosVisuales,
                  onCreateIncidencia: () => _abrirFormularioIncidencia(),
                ),
                const SizedBox(height: 12),
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
                    child: Column(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (state.isLoading && incidenciasBase.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (state.hasError && incidenciasBase.isEmpty) {
                                final err = state.asError?.error;
                                return Center(
                                  child: Text(
                                    'Error: $err',
                                    style: TextStyle(
                                      color: context.semanticColors.danger,
                                    ),
                                  ),
                                );
                              }

                              if (incidenciasFiltradas.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.24),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isEmpty &&
                                                _fechaFiltro == null
                                            ? 'No hay incidencias reportadas'
                                            : 'No hay resultados con los filtros actuales',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.54),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return _IncidenciasTable(
                                incidencias: incidenciasPagina,
                                tipoIncidenciaLabel: _tipoIncidenciaLabel,
                                sortColumn: _sortColumn,
                                sortAsc: _sortAsc,
                                onSort: _toggleSort,
                                onEdit: (inc) =>
                                    _abrirFormularioIncidencia(incidencia: inc),
                                onDelete: _confirmarEliminar,
                              );
                            },
                          ),
                        ),
                        if (incidenciasFiltradas.isNotEmpty)
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
                            isCargando: state.isLoading,
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
}

class _IncidenciasHeader extends StatelessWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final DateTime? fechaFiltro;
  final VoidCallback onSelectFecha;
  final VoidCallback onClearFecha;
  final VoidCallback onReload;
  final VoidCallback onResetFilters;
  final VoidCallback onCreateIncidencia;

  const _IncidenciasHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.fechaFiltro,
    required this.onSelectFecha,
    required this.onClearFecha,
    required this.onReload,
    required this.onResetFilters,
    required this.onCreateIncidencia,
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
                      onPressed: onSelectFecha,
                      icon: const Icon(Icons.calendar_month_rounded, size: 15),
                      label: const Text('Fecha'),
                    ),
                  ),
                  if (fechaFiltro != null)
                    SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        style: compactStyle,
                        onPressed: onClearFecha,
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 15,
                        ),
                        label: const Text('Limpiar fecha'),
                      ),
                    ),
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
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      onPressed: onCreateIncidencia,
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Nueva incidencia'),
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
                    color: colorScheme.errorContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_late_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incidencias reportadas',
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
                    child: _IncidenciasSearchInput(
                      controller: searchController,
                      onChanged: onSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FechaFilterBadge(fechaFiltro: fechaFiltro),
                ],
              );
            }

            Widget filtersTablet() {
              return Column(
                children: [
                  _IncidenciasSearchInput(
                    controller: searchController,
                    onChanged: onSearch,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _FechaFilterBadge(fechaFiltro: fechaFiltro),
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

class _IncidenciasSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _IncidenciasSearchInput({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Buscar incidencia',
        hintText: 'Local, clave, codigo, tipo, comentario, cobrador...',
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

class _FechaFilterBadge extends StatelessWidget {
  final DateTime? fechaFiltro;

  const _FechaFilterBadge({required this.fechaFiltro});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final activo = fechaFiltro != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (activo ? semantic.info : semantic.warning).withValues(
          alpha: 0.14,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (activo ? semantic.info : semantic.warning).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Text(
        activo
            ? 'Fecha: ${DateFormatter.formatDate(fechaFiltro)}'
            : 'Sin filtro de fecha',
        style: TextStyle(
          color: activo ? semantic.info : semantic.warning,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _IncidenciasTable extends StatelessWidget {
  final List<IncidenciaUI> incidencias;
  final String Function(String?) tipoIncidenciaLabel;
  final String? sortColumn;
  final bool sortAsc;
  final ValueChanged<String> onSort;
  final ValueChanged<IncidenciaUI> onEdit;
  final ValueChanged<IncidenciaUI> onDelete;

  const _IncidenciasTable({
    required this.incidencias,
    required this.tipoIncidenciaLabel,
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
        final minTableWidth = availableWidth < 1500 ? 1500.0 : availableWidth;

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
                        label: 'Local',
                        isActive: sortColumn == 'Local',
                        ascending: sortAsc,
                        onTap: () => onSort('Local'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Clave / Codigo',
                        isActive: sortColumn == 'Clave',
                        ascending: sortAsc,
                        onTap: () => onSort('Clave'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Tipo',
                        isActive: sortColumn == 'Tipo',
                        ascending: sortAsc,
                        onTap: () => onSort('Tipo'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Comentario',
                        isActive: sortColumn == 'Comentario',
                        ascending: sortAsc,
                        onTap: () => onSort('Comentario'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Cobrador',
                        isActive: sortColumn == 'Cobrador',
                        ascending: sortAsc,
                        onTap: () => onSort('Cobrador'),
                      ),
                    ),
                    DataColumn(
                      label: SortableColumn(
                        label: 'Fecha',
                        isActive: sortColumn == 'Fecha',
                        ascending: sortAsc,
                        onTap: () => onSort('Fecha'),
                      ),
                    ),
                    const DataColumn(label: Text('Acciones')),
                  ],
                  rows: incidencias.map((inc) {
                    final nombre = inc.localNombre.trim().isEmpty
                        ? '-'
                        : inc.localNombre.trim();
                    final initial = nombre == '-'
                        ? 'L'
                        : nombre.substring(0, 1).toUpperCase();
                    final comentario = (inc.gestion.comentario ?? '').trim();

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
                              SizedBox(
                                width: 220,
                                child: Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text(
                              'Clave: ${inc.localClave} | Cod: ${inc.localCodigo}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          _TypeChip(
                            text: tipoIncidenciaLabel(
                              inc.gestion.tipoIncidencia,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 360,
                            child: Tooltip(
                              message: comentario.isEmpty ? '-' : comentario,
                              child: Text(
                                comentario.isEmpty ? '-' : comentario,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text(
                              inc.cobradorNombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormatter.formatDateTime(inc.gestion.timestamp),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => onEdit(inc),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: context.semanticColors.danger,
                                ),
                                onPressed: () => onDelete(inc),
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

class _TypeChip extends StatelessWidget {
  final String text;

  const _TypeChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: semantic.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: semantic.warning.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: semantic.warning,
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
