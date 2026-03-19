import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../app/di/providers.dart';
import '../viewmodels/cortes_paginados_notifier.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/corte.dart';
import '../../../usuarios/domain/entities/usuario.dart';

class CortesHistorialScreen extends ConsumerStatefulWidget {
  final bool isAdmin;

  const CortesHistorialScreen({super.key, required this.isAdmin});

  @override
  ConsumerState<CortesHistorialScreen> createState() =>
      _CortesHistorialScreenState();
}

class _CortesHistorialScreenState extends ConsumerState<CortesHistorialScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final List<Corte> _allCortes = [];
  bool _initialLoaded = false;
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _ordenarNombreAsc = true;
  String? _codigoCobradorFiltro;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _searchQuery = value.trim()),
    );
  }

  List<Corte> _filtrarCortes(List<Corte> input) {
    final query = _normalizarTexto(_searchQuery);
    Iterable<Corte> result = input;

    if (query.isNotEmpty) {
      result = result.where((c) {
        final haystack = _normalizarTexto(
          '${c.cobradorNombre} ${c.cobradorId} ${c.mercadoNombre ?? ''} '
          '${c.id} ${c.primerBoleta ?? ''} ${c.ultimaBoleta ?? ''}',
        );
        return haystack.contains(query);
      });
    }

    final codigoFiltro = _normalizarTexto(_codigoCobradorFiltro);
    if (codigoFiltro.isNotEmpty) {
      result = result.where((c) => _coincideCodigoBoleta(c, codigoFiltro));
    }

    final list = result.toList();
    list.sort((a, b) {
      final cmp = _normalizarTexto(
        a.cobradorNombre,
      ).compareTo(_normalizarTexto(b.cobradorNombre));
      return _ordenarNombreAsc ? cmp : -cmp;
    });
    return list;
  }

  bool _coincideCodigoBoleta(Corte c, String codigoFiltro) {
    bool match(String? boleta) {
      final b = _normalizarTexto(boleta);
      if (b.isEmpty) return false;
      return b.startsWith(codigoFiltro) ||
          b.contains('$codigoFiltro-') ||
          b.contains('/$codigoFiltro') ||
          b.contains(codigoFiltro);
    }

    return match(c.primerBoleta) || match(c.ultimaBoleta);
  }

  String _normalizarTexto(String? value) {
    var text = (value ?? '').toLowerCase().trim();
    if (text.isEmpty) return '';
    const map = {
      '\u00E1': 'a',
      '\u00E0': 'a',
      '\u00E4': 'a',
      '\u00E2': 'a',
      '\u00E9': 'e',
      '\u00E8': 'e',
      '\u00EB': 'e',
      '\u00EA': 'e',
      '\u00ED': 'i',
      '\u00EC': 'i',
      '\u00EF': 'i',
      '\u00EE': 'i',
      '\u00F3': 'o',
      '\u00F2': 'o',
      '\u00F6': 'o',
      '\u00F4': 'o',
      '\u00FA': 'u',
      '\u00F9': 'u',
      '\u00FC': 'u',
      '\u00FB': 'u',
      '\u00F1': 'n',
    };
    map.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }

  Future<void> _abrirFiltrosBottomSheet() async {
    var ordenarAscTemp = _ordenarNombreAsc;
    String? codigoTemp = _codigoCobradorFiltro;

    final usuarios = ref.read(usuariosProvider).value ?? const <Usuario>[];
    final codigosCobrador =
        usuarios
            .where((u) => u.esCobrador)
            .map((u) => (u.codigoCobrador ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final colorScheme = Theme.of(sheetCtx).colorScheme;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void applyAndClose() {
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              setState(() {
                _ordenarNombreAsc = ordenarAscTemp;
                _codigoCobradorFiltro =
                    (codigoTemp == null || codigoTemp!.isEmpty)
                    ? null
                    : codigoTemp;
              });
            }

            void resetAndClose() {
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              setState(() {
                _ordenarNombreAsc = true;
                _codigoCobradorFiltro = null;
              });
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
                                      'Filtros de historial',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'Orden y codigo de cobrador para boletas.',
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
                                    'Orden alfabetico (cobrador)',
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
                                    child: _BottomSheetFilterChip(
                                      label: 'A - Z',
                                      selected: ordenarAscTemp,
                                      onTap: () => setSheetState(
                                        () => ordenarAscTemp = true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _BottomSheetFilterChip(
                                      label: 'Z - A',
                                      selected: !ordenarAscTemp,
                                      onTap: () => setSheetState(
                                        () => ordenarAscTemp = false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: codigoTemp,
                          decoration: InputDecoration(
                            labelText: 'Codigo de cobrador (boletas)',
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(
                              12,
                              10,
                              12,
                              10,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...codigosCobrador.map(
                              (codigo) => DropdownMenuItem<String?>(
                                value: codigo,
                                child: Text(codigo),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setSheetState(() => codigoTemp = value),
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = widget.isAdmin
          ? cortesAdminPaginadosProvider
          : cortesCobradorPaginadosProvider;
      final state = ref.read(provider);
      if (!state.cargando && state.hayMas) {
        ref.read(provider.notifier).irAPaginaSiguiente();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.isAdmin
        ? cortesAdminPaginadosProvider
        : cortesCobradorPaginadosProvider;
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = viewportWidth >= 1200 ? 24.0 : 16.0;

    // Carga inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.inicializado && !state.cargando && state.errorMsg == null) {
        notifier.cargarPagina();
      }
    });

    // Acumular cortes conforme se cargan nuevas páginas
    if (state.inicializado && state.cortes.isNotEmpty) {
      if (state.paginaActual == 1) {
        _allCortes.clear();
      }
      for (final c in state.cortes) {
        if (!_allCortes.any((existing) => existing.id == c.id)) {
          _allCortes.add(c);
        }
      }
      if (!_initialLoaded) _initialLoaded = true;
    } else if (state.inicializado &&
        state.cortes.isEmpty &&
        state.paginaActual == 1) {
      _allCortes.clear();
    }
    final cortesFiltrados = _filtrarCortes(_allCortes);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Historial de Cortes' : 'Mi Historial de Cortes',
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          0,
        ),
        child: Column(
          children: [
            // ── Barra de filtros ──
            _FiltrosFechaBar(
              isAdmin: widget.isAdmin,
              totalRegistros: cortesFiltrados.length,
              searchController: _searchCtrl,
              onSearchChanged: _onSearchChanged,
              filtroActivo: state.filtroActivo,
              fechaInicio: state.fechaInicio,
              fechaFin: state.fechaFin,
              onRecargar: () {
                _allCortes.clear();
                notifier.recargar();
              },
              onRestablecer: () {
                _allCortes.clear();
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
                notifier.filtrarTodos();
              },
              onOpenFilters: _abrirFiltrosBottomSheet,
              onFiltrar: (filtro) {
                _allCortes.clear();
                switch (filtro) {
                  case FiltroFecha.hoy:
                    notifier.filtrarHoy();
                    break;
                  case FiltroFecha.semana:
                    notifier.filtrarSemana();
                    break;
                  case FiltroFecha.mes:
                    notifier.filtrarMes();
                    break;
                  case FiltroFecha.todos:
                    notifier.filtrarTodos();
                    break;
                  case FiltroFecha.personalizado:
                    break;
                }
              },
              onFiltrarRango: (desde, hasta) {
                _allCortes.clear();
                notifier.filtrarRango(desde, hasta);
              },
            ),

            // ── Resumen rápido ──
            if (cortesFiltrados.isNotEmpty)
              _ResumenPeriodo(cortes: cortesFiltrados),

            // ── Lista ──
            Expanded(child: _buildBody(state, cortesFiltrados)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CortesPaginadosState state, List<Corte> cortesFiltrados) {
    final theme = Theme.of(context);

    if (state.cargando && _allCortes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMsg != null && _allCortes.isEmpty) {
      return Center(child: Text('Error: ${state.errorMsg}'));
    }

    if (cortesFiltrados.isEmpty && state.inicializado) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay cortes en este periodo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Prueba con otro rango de fechas',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupCortes(cortesFiltrados);
    final sortedKeys = _getSortedKeys(grouped);

    final List<_ListItem> flatItems = [];
    for (final dateKey in sortedKeys) {
      flatItems.add(_ListItem.header(dateKey));
      for (final corte in grouped[dateKey]!) {
        flatItems.add(_ListItem.corte(corte));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      itemCount: flatItems.length + (state.cargando ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= flatItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = flatItems[index];

        if (item.isHeader) {
          return _DateHeader(dateKey: item.dateKey!);
        }

        final corte = item.corte!;
        return _CorteTileDetallado(
          corte: corte,
          isAdmin: widget.isAdmin,
          onTap: () {
            context.push(
              widget.isAdmin ? '/corte-detalle' : '/cobrador/corte-detalle',
              extra: corte,
            );
          },
        );
      },
    );
  }

  Map<String, List<Corte>> _groupCortes(List<Corte> cortes) {
    final grouped = <String, List<Corte>>{};
    for (var corte in cortes) {
      final dateKey = DateFormat('yyyy-MM-dd').format(corte.fechaCorte);
      grouped.putIfAbsent(dateKey, () => []).add(corte);
    }
    return grouped;
  }

  List<String> _getSortedKeys(Map<String, List<Corte>> grouped) {
    return grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Date Header
// ──────────────────────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String dateKey;
  const _DateHeader({required this.dateKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat(
                    'EEEE, d MMMM yyyy',
                    'es_ES',
                  ).format(DateTime.parse(dateKey)).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Barra de filtros rápidos + rango personalizado (Desde / Hasta)
// ──────────────────────────────────────────────────────────────────────────────
class _FiltrosFechaBar extends StatefulWidget {
  final bool isAdmin;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final FiltroFecha filtroActivo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final VoidCallback onRecargar;
  final VoidCallback onRestablecer;
  final VoidCallback onOpenFilters;
  final ValueChanged<FiltroFecha> onFiltrar;
  final void Function(DateTime desde, DateTime hasta) onFiltrarRango;

  const _FiltrosFechaBar({
    required this.isAdmin,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearchChanged,
    required this.filtroActivo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.onRecargar,
    required this.onRestablecer,
    required this.onOpenFilters,
    required this.onFiltrar,
    required this.onFiltrarRango,
  });

  @override
  State<_FiltrosFechaBar> createState() => _FiltrosFechaBarState();
}

class _FiltrosFechaBarState extends State<_FiltrosFechaBar> {
  DateTime? _desde;
  DateTime? _hasta;

  Future<void> _seleccionarDesde() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2024),
      lastDate: now,
      helpText: 'Seleccionar Fecha Inicial',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() {
        _desde = picked;
        if (_hasta != null && _hasta!.isBefore(picked)) {
          _hasta = picked;
        }
      });
      _aplicarRango();
    }
  }

  Future<void> _seleccionarHasta() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta ?? now,
      firstDate: _desde ?? DateTime(2024),
      lastDate: now,
      helpText: 'Seleccionar Fecha Final',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _hasta = picked);
      _aplicarRango();
    }
  }

  void _aplicarRango() {
    if (_desde != null && _hasta != null) {
      widget.onFiltrarRango(_desde!, _hasta!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 760;

    final chips = [
      (FiltroFecha.todos, 'Todos', Icons.all_inclusive_rounded),
      (FiltroFecha.hoy, 'Hoy', Icons.today_rounded),
      (FiltroFecha.semana, 'Esta Semana', Icons.date_range_rounded),
      (FiltroFecha.mes, 'Este Mes', Icons.calendar_month_rounded),
    ];

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
              onPressed: widget.onRecargar,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Recargar'),
            ),
          ),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              style: compactStyle,
              onPressed: widget.onOpenFilters,
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: const Text('Filtros'),
            ),
          ),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              style: compactStyle,
              onPressed: () {
                setState(() {
                  _desde = null;
                  _hasta = null;
                });
                widget.onRestablecer();
              },
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
            Icons.history_rounded,
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
                widget.isAdmin
                    ? 'Historial de cortes'
                    : 'Mi historial de cortes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                '${widget.totalRegistros} registros cargados',
                style: theme.textTheme.bodySmall?.copyWith(
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
        children: [
          TextField(
            controller: widget.searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Buscar en historial',
              hintText: 'Cobrador, boleta, mercado o ID...',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideFilters = constraints.maxWidth >= 980;

              if (isWideFilters) {
                return Row(
                  children: [
                    for (final chip in chips) ...[
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: _FilterPill(
                            label: chip.$2,
                            icon: chip.$3,
                            isActive: widget.filtroActivo == chip.$1,
                            onTap: () => widget.onFiltrar(chip.$1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: _DateSelector(
                          label: 'Desde',
                          fecha: _desde ?? widget.fechaInicio,
                          onTap: _seleccionarDesde,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: _DateSelector(
                          label: 'Hasta',
                          fecha: _hasta ?? widget.fechaFin,
                          onTap: _seleccionarHasta,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...chips.map((chip) {
                    final isActive = widget.filtroActivo == chip.$1;
                    return SizedBox(
                      height: 40,
                      child: _FilterPill(
                        label: chip.$2,
                        icon: chip.$3,
                        isActive: isActive,
                        onTap: () => widget.onFiltrar(chip.$1),
                      ),
                    );
                  }),
                  SizedBox(
                    width: isMobile ? 150 : 175,
                    height: 40,
                    child: _DateSelector(
                      label: 'Desde',
                      fecha: _desde ?? widget.fechaInicio,
                      onTap: _seleccionarDesde,
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? 150 : 175,
                    height: 40,
                    child: _DateSelector(
                      label: 'Hasta',
                      fecha: _hasta ?? widget.fechaFin,
                      onTap: _seleccionarHasta,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return Container(
      decoration: context.webHeaderDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              headerLeft,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actions(compact: true),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: headerLeft),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: actions(compact: false),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            filtersGroup,
          ],
        ),
      ),
    );
  }
}

// ── Pill de Filtro ──
class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isOutlined;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    Color textColor;
    Color iconColor;
    Border? border;

    if (isActive) {
      bgColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
      iconColor = colorScheme.primary;
      if (isOutlined) {
        border = Border.all(color: colorScheme.primary, width: 1.5);
      }
    } else {
      bgColor = colorScheme.surfaceContainerHigh;
      textColor = colorScheme.onSurfaceVariant;
      iconColor = colorScheme.onSurfaceVariant;
      if (isOutlined) {
        bgColor = colorScheme.surface;
        border = Border.all(color: colorScheme.outlineVariant, width: 1);
      }
    }

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: isActive && !isOutlined ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Selector de Fecha ──
class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  const _DateSelector({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final bool isSelected = fecha != null;
    final fechaTxt = fecha != null
        ? DateFormat('dd/MM/yyyy', 'es_ES').format(fecha!)
        : 'DD/MM/AAAA';

    return Material(
      color: isSelected ? c.primary.withValues(alpha: 0.1) : c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? c.primary.withValues(alpha: 0.45)
                  : c.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: isSelected ? c.primary : c.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$label: $fechaTxt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? c.onSurface : c.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Resumen del periodo
// ──────────────────────────────────────────────────────────────────────────────
class _ResumenPeriodo extends StatelessWidget {
  final List<Corte> cortes;
  const _ResumenPeriodo({required this.cortes});

  @override
  Widget build(BuildContext context) {
    final total = cortes.fold<double>(0, (s, c) => s + c.totalCobrado);
    final totalCobros = cortes.fold<int>(0, (s, c) => s + c.cantidadRegistros);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: Icons.attach_money_rounded,
            value: CurrencyFormatter.format(total),
            label: 'Recaudado',
            color: theme.colorScheme.primary,
          ),
          Container(
            width: 1,
            height: 36,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          _SummaryItem(
            icon: Icons.receipt_outlined,
            value: '${cortes.length}',
            label: 'Cortes',
            color: theme.colorScheme.onPrimaryContainer,
          ),
          Container(
            width: 1,
            height: 36,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          _SummaryItem(
            icon: Icons.diversity_3_rounded,
            value: '$totalCobros',
            label: 'Movimientos',
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Tile detallado para cada corte
// ──────────────────────────────────────────────────────────────────────────────
class _CorteTileDetallado extends StatelessWidget {
  final Corte corte;
  final bool isAdmin;
  final VoidCallback onTap;

  const _CorteTileDetallado({
    required this.corte,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cobrados = corte.cantidadCobrados ?? 0;
    final pendientes = corte.cantidadPendientes ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primera fila: avatar + info + total
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        corte.esCorteMercado
                            ? Icons.store_rounded
                            : Icons.person_rounded,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            corte.esCorteMercado
                                ? (corte.mercadoNombre ?? 'Corte de Mercado')
                                : corte.cobradorNombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('hh:mm a').format(corte.fechaCorte)} • '
                            '${corte.cantidadRegistros} movimientos',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          if (corte.primerBoleta != null &&
                              corte.ultimaBoleta != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 12,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  corte.primerBoleta == corte.ultimaBoleta
                                      ? 'Boleta: ${corte.primerBoleta}'
                                      : 'Boletas: ${corte.primerBoleta} - ${corte.ultimaBoleta}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(corte.totalCobrado),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Segunda fila: chips de estado + mercado
                if (cobrados > 0 ||
                    pendientes > 0 ||
                    (corte.gestionesInfo ?? []).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isAdmin && corte.mercadoNombre != null)
                        _InfoChip(
                          icon: Icons.storefront_rounded,
                          label: corte.mercadoNombre!,
                          color: theme.colorScheme.onSurfaceVariant,
                          bgColor: theme.colorScheme.surfaceContainerHigh,
                        ),
                      _InfoChip(
                        icon: Icons.check_circle,
                        label: '$cobrados',
                        color: AppColors.success,
                        bgColor: AppColors.success.withValues(alpha: 0.08),
                      ),
                      _InfoChip(
                        icon: Icons.schedule,
                        label: '$pendientes',
                        color: AppColors.warning,
                        bgColor: AppColors.warning.withValues(alpha: 0.08),
                      ),
                      if ((corte.gestionesInfo ?? []).isNotEmpty)
                        _InfoChip(
                          icon: Icons.assignment_late_rounded,
                          label: '${corte.gestionesInfo!.length}',
                          color: const Color(0xFFE67E22),
                          bgColor: const Color(
                            0xFFE67E22,
                          ).withValues(alpha: 0.08),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper para construir una lista plana con headers y cortes
class _ListItem {
  final bool isHeader;
  final String? dateKey;
  final Corte? corte;

  _ListItem.header(this.dateKey) : isHeader = true, corte = null;

  _ListItem.corte(this.corte) : isHeader = false, dateKey = null;
}

class _BottomSheetFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomSheetFilterChip({
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
          mainAxisSize: MainAxisSize.min,
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

class _BottomSheetDateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _BottomSheetDateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.45)
                : colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label: ${date != null ? DateFormat('dd/MM/yyyy').format(date!) : 'DD/MM/AAAA'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
