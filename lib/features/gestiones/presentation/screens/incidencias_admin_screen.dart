import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  int _paginaActual = 1;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String? _sortColumn;
  bool _sortAsc = true;
  IncidenciaUI? _incidenciaSeleccionada;
  final FocusNode _tableFocusNode = FocusNode();

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim().toLowerCase();
        _paginaActual = 1;
        _incidenciaSeleccionada = null;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  DateTime _soloFecha(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool get _tieneFiltroFecha => _fechaDesde != null || _fechaHasta != null;

  Future<void> _seleccionarFechaDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaDesde ?? _fechaHasta ?? DateTime.now(),
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
      final desde = _soloFecha(picked);
      setState(() {
        _fechaDesde = desde;
        if (_fechaHasta != null && _fechaHasta!.isBefore(desde)) {
          _fechaHasta = desde;
        }
        _paginaActual = 1;
        _incidenciaSeleccionada = null;
      });
    }
  }

  Future<void> _seleccionarFechaHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaHasta ?? _fechaDesde ?? DateTime.now(),
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
      final hasta = _soloFecha(picked);
      setState(() {
        _fechaHasta = hasta;
        if (_fechaDesde != null && _fechaDesde!.isAfter(hasta)) {
          _fechaDesde = hasta;
        }
        _paginaActual = 1;
        _incidenciaSeleccionada = null;
      });
    }
  }

  void _seleccionarDiaRapido(DateTime date) {
    final fecha = _soloFecha(date);
    setState(() {
      _fechaDesde = fecha;
      _fechaHasta = fecha;
      _paginaActual = 1;
      _incidenciaSeleccionada = null;
    });
  }

  void _limpiarFiltroFechas() {
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
      _paginaActual = 1;
      _incidenciaSeleccionada = null;
    });
  }

  void _recargarIncidencias() {
    setState(() {
      _paginaActual = 1;
      _incidenciaSeleccionada = null;
    });
    ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
  }

  void _restablecerFiltrosVisuales() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _paginaActual = 1;
      _sortColumn = null;
      _sortAsc = true;
      _incidenciaSeleccionada = null;
      _fechaDesde = null;
      _fechaHasta = null;
    });
    ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
  }

  List<IncidenciaUI> _filtrarPorRangoFecha(List<IncidenciaUI> incidencias) {
    if (!_tieneFiltroFecha) return incidencias;

    var desde = _fechaDesde ?? _fechaHasta!;
    var hasta = _fechaHasta ?? _fechaDesde!;
    if (hasta.isBefore(desde)) {
      final tmp = desde;
      desde = hasta;
      hasta = tmp;
    }

    final inicio = _soloFecha(desde);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);

    return incidencias.where((inc) {
      final ts = inc.gestion.timestamp;
      if (ts == null) return false;
      return !ts.isBefore(inicio) && !ts.isAfter(fin);
    }).toList();
  }

  void _moverSeleccion(int delta, List<IncidenciaUI> incidenciasActuales) {
    if (incidenciasActuales.isEmpty) return;

    if (_incidenciaSeleccionada == null) {
      if (delta > 0) {
        setState(() => _incidenciaSeleccionada = incidenciasActuales.first);
      }
      return;
    }

    final currentIndex = incidenciasActuales.indexWhere(
      (inc) => _mismaIncidencia(inc, _incidenciaSeleccionada!),
    );
    if (currentIndex == -1) {
      setState(() => _incidenciaSeleccionada = incidenciasActuales.first);
      return;
    }

    final nextIndex = currentIndex + delta;
    if (nextIndex >= 0 && nextIndex < incidenciasActuales.length) {
      setState(() => _incidenciaSeleccionada = incidenciasActuales[nextIndex]);
    }
  }

  bool _mismaIncidencia(IncidenciaUI a, IncidenciaUI b) {
    final aId = a.gestion.id;
    final bId = b.gestion.id;
    if (aId != null && bId != null) {
      return aId == bId;
    }
    return a.localNombre == b.localNombre &&
        a.cobradorNombre == b.cobradorNombre &&
        a.gestion.timestamp == b.gestion.timestamp;
  }

  void _onIncidenciaTapped(
    BuildContext context,
    IncidenciaUI incidencia,
    bool isWide,
  ) {
    if (isWide) {
      setState(() {
        if (_incidenciaSeleccionada != null &&
            _mismaIncidencia(_incidenciaSeleccionada!, incidencia)) {
          _incidenciaSeleccionada = null;
        } else {
          _incidenciaSeleccionada = incidencia;
        }
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          child: _IncidenciaDetallePanel(
            incidencia: incidencia,
            tipoIncidenciaLabel: _tipoIncidenciaLabel,
            onEdit: () {
              Navigator.of(ctx).pop();
              _abrirFormularioIncidencia(incidencia: incidencia);
            },
            onDelete: () {
              Navigator.of(ctx).pop();
              _confirmarEliminar(incidencia);
            },
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
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
    final incidenciasPorFecha = _filtrarPorRangoFecha(incidenciasBase);
    final incidenciasFiltradas = _filtrarPorBusqueda(
      incidenciasPorFecha,
      _searchQuery,
    );

    final incidenciasSorted = _applySort(incidenciasFiltradas);

    final totalPaginas = incidenciasSorted.isEmpty
        ? 1
        : (incidenciasSorted.length / _pageSize).ceil();
    final paginaActual = _paginaActual.clamp(1, totalPaginas);
    final inicio = (paginaActual - 1) * _pageSize;
    final fin = (inicio + _pageSize > incidenciasSorted.length)
        ? incidenciasSorted.length
        : inicio + _pageSize;
    final incidenciasPagina = incidenciasSorted.isEmpty
        ? const <IncidenciaUI>[]
        : incidenciasSorted.sublist(inicio, fin);

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
                _IncidenciasHeader(
                  paginaActual: paginaActual,
                  totalRegistros: incidenciasFiltradas.length,
                  searchController: _searchCtrl,
                  onSearch: _onSearchChanged,
                  fechaDesde: _fechaDesde,
                  fechaHasta: _fechaHasta,
                  onSelectFechaDesde: _seleccionarFechaDesde,
                  onSelectFechaHasta: _seleccionarFechaHasta,
                  onSelectAyer: () => _seleccionarDiaRapido(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ),
                  onSelectHoy: () => _seleccionarDiaRapido(DateTime.now()),
                  onSelectManana: () => _seleccionarDiaRapido(
                    DateTime.now().add(const Duration(days: 1)),
                  ),
                  onClearFechas: _limpiarFiltroFechas,
                  onReload: _recargarIncidencias,
                  onResetFilters: _restablecerFiltrosVisuales,
                  onCreateIncidencia: () => _abrirFormularioIncidencia(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Focus(
                    focusNode: _tableFocusNode,
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          _moverSeleccion(1, incidenciasPagina);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          _moverSeleccion(-1, incidenciasPagina);
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
                        Expanded(
                          flex: 13,
                          child: Column(
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    if (state.isLoading &&
                                        incidenciasBase.isEmpty) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (state.hasError &&
                                        incidenciasBase.isEmpty) {
                                      final err = state.asError?.error;
                                      return Center(
                                        child: Text(
                                          'Error: $err',
                                          style: TextStyle(
                                            color:
                                                context.semanticColors.danger,
                                          ),
                                        ),
                                      );
                                    }

                                    if (incidenciasFiltradas.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              size: 48,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.24),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchQuery.isEmpty &&
                                                      !_tieneFiltroFecha
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

                                    final seleccion = _incidenciaSeleccionada;
                                    final selectedId = seleccion?.gestion.id;

                                    return _IncidenciasTable(
                                      incidencias: incidenciasPagina,
                                      tipoIncidenciaLabel: _tipoIncidenciaLabel,
                                      sortColumn: _sortColumn,
                                      sortAsc: _sortAsc,
                                      selectedIncidenciaId: selectedId,
                                      onSort: _toggleSort,
                                      onSelect: (inc) => _onIncidenciaTapped(
                                        context,
                                        inc,
                                        isWide,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (!isWide && incidenciasFiltradas.isNotEmpty)
                                _PaginationBar(
                                  currentPage: paginaActual,
                                  totalPages: totalPaginas,
                                  onPrev: paginaActual > 1
                                      ? () => setState(() {
                                          _paginaActual = paginaActual - 1;
                                          _incidenciaSeleccionada = null;
                                        })
                                      : null,
                                  onNext: paginaActual < totalPaginas
                                      ? () => setState(() {
                                          _paginaActual = paginaActual + 1;
                                          _incidenciaSeleccionada = null;
                                        })
                                      : null,
                                  isCargando: state.isLoading,
                                ),
                            ],
                          ),
                        ),
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
                                  child: _incidenciaSeleccionada != null
                                      ? _IncidenciaDetallePanel(
                                          incidencia: _incidenciaSeleccionada!,
                                          tipoIncidenciaLabel:
                                              _tipoIncidenciaLabel,
                                          onEdit: () =>
                                              _abrirFormularioIncidencia(
                                                incidencia:
                                                    _incidenciaSeleccionada!,
                                              ),
                                          onDelete: () => _confirmarEliminar(
                                            _incidenciaSeleccionada!,
                                          ),
                                          onClose: () => setState(
                                            () =>
                                                _incidenciaSeleccionada = null,
                                          ),
                                          showActions: false,
                                        )
                                      : const _PanelDetalleIncidenciaVacio(),
                                ),
                                if (incidenciasFiltradas.isNotEmpty)
                                  _IncidenciaPanelFooter(
                                    currentPage: paginaActual,
                                    totalPages: totalPaginas,
                                    onPrev: paginaActual > 1
                                        ? () => setState(() {
                                            _paginaActual = paginaActual - 1;
                                            _incidenciaSeleccionada = null;
                                          })
                                        : null,
                                    onNext: paginaActual < totalPaginas
                                        ? () => setState(() {
                                            _paginaActual = paginaActual + 1;
                                            _incidenciaSeleccionada = null;
                                          })
                                        : null,
                                    isCargando: state.isLoading,
                                    onEdit: _incidenciaSeleccionada == null
                                        ? null
                                        : () => _abrirFormularioIncidencia(
                                            incidencia:
                                                _incidenciaSeleccionada!,
                                          ),
                                    onDelete: _incidenciaSeleccionada == null
                                        ? null
                                        : () => _confirmarEliminar(
                                            _incidenciaSeleccionada!,
                                          ),
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

class _IncidenciasHeader extends StatelessWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final VoidCallback onSelectFechaDesde;
  final VoidCallback onSelectFechaHasta;
  final VoidCallback onSelectAyer;
  final VoidCallback onSelectHoy;
  final VoidCallback onSelectManana;
  final VoidCallback onClearFechas;
  final VoidCallback onReload;
  final VoidCallback onResetFilters;
  final VoidCallback onCreateIncidencia;

  const _IncidenciasHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.onSelectFechaDesde,
    required this.onSelectFechaHasta,
    required this.onSelectAyer,
    required this.onSelectHoy,
    required this.onSelectManana,
    required this.onClearFechas,
    required this.onReload,
    required this.onResetFilters,
    required this.onCreateIncidencia,
  });

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final ayer = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final hoy = DateTime(now.year, now.month, now.day);
    final manana = hoy.add(const Duration(days: 1));
    final hayFiltroFecha = fechaDesde != null || fechaHasta != null;

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

            Widget dateFiltersDesktop() {
              return Row(
                children: [
                  _IncidenciasQuickDateButton(
                    label: 'Ayer',
                    selected:
                        _isSameDay(fechaDesde, ayer) &&
                        _isSameDay(fechaHasta, ayer),
                    onTap: onSelectAyer,
                  ),
                  const SizedBox(width: 8),
                  _IncidenciasQuickDateButton(
                    label: 'Hoy',
                    selected:
                        _isSameDay(fechaDesde, hoy) &&
                        _isSameDay(fechaHasta, hoy),
                    onTap: onSelectHoy,
                  ),
                  const SizedBox(width: 8),
                  _IncidenciasQuickDateButton(
                    label: 'Manana',
                    selected:
                        _isSameDay(fechaDesde, manana) &&
                        _isSameDay(fechaHasta, manana),
                    onTap: onSelectManana,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _IncidenciasDateFilterButton(
                      label: 'Desde',
                      fecha: fechaDesde,
                      icon: Icons.calendar_today_rounded,
                      onPressed: onSelectFechaDesde,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _IncidenciasDateFilterButton(
                      label: 'Hasta',
                      fecha: fechaHasta,
                      icon: Icons.date_range_rounded,
                      onPressed: onSelectFechaHasta,
                    ),
                  ),
                  if (hayFiltroFecha) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: onClearFechas,
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 16,
                        ),
                        label: const Text('Limpiar'),
                      ),
                    ),
                  ],
                ],
              );
            }

            Widget dateFiltersMobile() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _IncidenciasQuickDateButton(
                          label: 'Ayer',
                          selected:
                              _isSameDay(fechaDesde, ayer) &&
                              _isSameDay(fechaHasta, ayer),
                          onTap: onSelectAyer,
                        ),
                        const SizedBox(width: 8),
                        _IncidenciasQuickDateButton(
                          label: 'Hoy',
                          selected:
                              _isSameDay(fechaDesde, hoy) &&
                              _isSameDay(fechaHasta, hoy),
                          onTap: onSelectHoy,
                        ),
                        const SizedBox(width: 8),
                        _IncidenciasQuickDateButton(
                          label: 'Manana',
                          selected:
                              _isSameDay(fechaDesde, manana) &&
                              _isSameDay(fechaHasta, manana),
                          onTap: onSelectManana,
                        ),
                        if (hayFiltroFecha) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: onClearFechas,
                              icon: const Icon(
                                Icons.filter_alt_off_rounded,
                                size: 16,
                              ),
                              label: const Text('Limpiar'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _IncidenciasDateFilterButton(
                          label: 'Desde',
                          fecha: fechaDesde,
                          icon: Icons.calendar_today_rounded,
                          onPressed: onSelectFechaDesde,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _IncidenciasDateFilterButton(
                          label: 'Hasta',
                          fecha: fechaHasta,
                          icon: Icons.date_range_rounded,
                          onPressed: onSelectFechaHasta,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

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
                ],
              );
            }

            Widget filtersTablet() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IncidenciasSearchInput(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isTablet || isMobile)
                    dateFiltersMobile()
                  else
                    dateFiltersDesktop(),
                  const SizedBox(height: 8),
                  isTablet || isMobile ? filtersTablet() : filtersDesktop(),
                ],
              ),
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

class _IncidenciasQuickDateButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IncidenciasQuickDateButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        foregroundColor: selected
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _IncidenciasDateFilterButton extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final IconData icon;
  final VoidCallback onPressed;

  const _IncidenciasDateFilterButton({
    required this.label,
    required this.fecha,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final text = fecha != null
        ? '$label: ${DateFormatter.formatDate(fecha)}'
        : '$label: --/--/----';

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _IncidenciasTable extends StatelessWidget {
  final List<IncidenciaUI> incidencias;
  final String? sortColumn;
  final bool sortAsc;
  final String? selectedIncidenciaId;
  final String Function(String?) tipoIncidenciaLabel;
  final ValueChanged<String> onSort;
  final ValueChanged<IncidenciaUI> onSelect;

  const _IncidenciasTable({
    required this.incidencias,
    required this.sortColumn,
    required this.sortAsc,
    required this.selectedIncidenciaId,
    required this.tipoIncidenciaLabel,
    required this.onSort,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const sidePadding = 16.0;
        final availableWidth = constraints.maxWidth;
        final minTableWidth = availableWidth < 900 ? 900.0 : availableWidth;

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
                      label: SortableColumn(
                        label: 'Tipo',
                        isActive: sortColumn == 'Tipo',
                        ascending: sortAsc,
                        onTap: () => onSort('Tipo'),
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
                  ],
                  rows: incidencias.map((inc) {
                    final nombre = inc.localNombre.trim().isEmpty
                        ? '-'
                        : inc.localNombre.trim();

                    return DataRow(
                      selected: selectedIncidenciaId == inc.gestion.id,
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return colorScheme.primary.withValues(alpha: 0.15);
                        }
                        return null;
                      }),
                      onSelectChanged: (_) => onSelect(inc),
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
                          _TypeChip(
                            text: tipoIncidenciaLabel(
                              inc.gestion.tipoIncidencia,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormatter.formatDateTime(inc.gestion.timestamp),
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

class _IncidenciaDetallePanel extends StatelessWidget {
  final IncidenciaUI incidencia;
  final String Function(String?) tipoIncidenciaLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final bool showActions;

  const _IncidenciaDetallePanel({
    required this.incidencia,
    required this.tipoIncidenciaLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final comentario = (incidencia.gestion.comentario ?? '').trim();

    return Container(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    incidencia.localNombre,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                  tooltip: 'Cerrar detalle',
                ),
              ],
            ),
            const Divider(height: 16),
            _IncidenciaDetailRow(
              icon: Icons.vpn_key_rounded,
              label: 'Clave / Codigo',
              value:
                  'Clave: ${incidencia.localClave} | Cod: ${incidencia.localCodigo}',
            ),
            _IncidenciaDetailRow(
              icon: Icons.assignment_late_rounded,
              label: 'Tipo',
              value: tipoIncidenciaLabel(incidencia.gestion.tipoIncidencia),
            ),
            _IncidenciaDetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Cobrador',
              value: incidencia.cobradorNombre,
            ),
            _IncidenciaDetailRow(
              icon: Icons.schedule_rounded,
              label: 'Fecha',
              value: DateFormatter.formatDateTime(incidencia.gestion.timestamp),
            ),
            const SizedBox(height: 12),
            Text(
              'Comentario',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Text(comentario.isEmpty ? '-' : comentario),
            ),
            if (showActions) ...[
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDelete,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.semanticColors.danger,
                        foregroundColor: context.semanticColors.onDanger,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncidenciaDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _IncidenciaDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelDetalleIncidenciaVacio extends StatelessWidget {
  const _PanelDetalleIncidenciaVacio();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona una incidencia de la tabla\npara ver su informacion completa.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

class _IncidenciaPanelFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _IncidenciaPanelFooter({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
    required this.isCargando,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (onEdit != null) ...[
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
            const SizedBox(width: 8),
          ],
          if (onDelete != null) ...[
            FilledButton.icon(
              onPressed: onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: context.semanticColors.danger,
                foregroundColor: context.semanticColors.onDanger,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Eliminar'),
            ),
            const SizedBox(width: 12),
          ],
          const Spacer(),
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
