import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../viewmodels/cortes_paginados_notifier.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/corte.dart';

class CortesHistorialScreen extends ConsumerStatefulWidget {
  final bool isAdmin;

  const CortesHistorialScreen({super.key, required this.isAdmin});

  @override
  ConsumerState<CortesHistorialScreen> createState() =>
      _CortesHistorialScreenState();
}

class _CortesHistorialScreenState extends ConsumerState<CortesHistorialScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Corte> _allCortes = [];
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    final isWide = MediaQuery.sizeOf(context).width > 800;

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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Historial de Cortes' : 'Mi Historial de Cortes',
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
          child: Column(
            children: [

              // ── Barra de filtros ──
              _FiltrosFechaBar(
                filtroActivo: state.filtroActivo,
                fechaInicio: state.fechaInicio,
                fechaFin: state.fechaFin,
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
              if (_allCortes.isNotEmpty) _ResumenPeriodo(cortes: _allCortes),

              // ── Lista ──
              Expanded(child: _buildBody(state, isWide)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CortesPaginadosState state, bool isWide) {
    final theme = Theme.of(context);

    if (state.cargando && _allCortes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMsg != null && _allCortes.isEmpty) {
      return Center(child: Text('Error: ${state.errorMsg}'));
    }

    if (_allCortes.isEmpty && state.inicializado) {
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

    final grouped = _groupCortes(_allCortes);
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
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 12, vertical: 8),
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
  final FiltroFecha filtroActivo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final ValueChanged<FiltroFecha> onFiltrar;
  final void Function(DateTime desde, DateTime hasta) onFiltrarRango;

  const _FiltrosFechaBar({
    required this.filtroActivo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.onFiltrar,
    required this.onFiltrarRango,
  });

  @override
  State<_FiltrosFechaBar> createState() => _FiltrosFechaBarState();
}

class _FiltrosFechaBarState extends State<_FiltrosFechaBar> {
  DateTime? _desde;
  DateTime? _hasta;
  bool _mostrarRango = false;

  @override
  void didUpdateWidget(covariant _FiltrosFechaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filtroActivo != FiltroFecha.personalizado) {
      _mostrarRango = false;
    }
  }

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

    final chips = [
      (FiltroFecha.todos, 'Todos', Icons.all_inclusive_rounded),
      (FiltroFecha.hoy, 'Hoy', Icons.today_rounded),
      (FiltroFecha.semana, 'Esta Semana', Icons.date_range_rounded),
      (FiltroFecha.mes, 'Este Mes', Icons.calendar_month_rounded),
    ];

    final isPersonalizadoActivo =
        widget.filtroActivo == FiltroFecha.personalizado;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chips rápidos ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ...chips.map((chip) {
                  final isActive = widget.filtroActivo == chip.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      label: chip.$2,
                      icon: chip.$3,
                      isActive: isActive,
                      onTap: () {
                        setState(() => _mostrarRango = false);
                        widget.onFiltrar(chip.$1);
                      },
                    ),
                  );
                }),
                _FilterPill(
                  label:
                      isPersonalizadoActivo &&
                          widget.fechaInicio != null &&
                          widget.fechaFin != null
                      ? '${DateFormat('dd MMM').format(widget.fechaInicio!)} - ${DateFormat('dd MMM').format(widget.fechaFin!)}'
                      : 'Rango Personalizado',
                  icon: Icons.tune_rounded,
                  isActive: isPersonalizadoActivo || _mostrarRango,
                  isOutlined: true,
                  onTap: () {
                    setState(() {
                      _mostrarRango = !_mostrarRango;
                      _desde ??=
                          widget.fechaInicio ??
                          DateTime.now().subtract(const Duration(days: 7));
                      _hasta ??= widget.fechaFin ?? DateTime.now();
                    });
                  },
                ),
              ],
            ),
          ),

          // ── Panel colapsable de rango ──
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: !_mostrarRango
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Seleccionar Rango',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _DateSelector(
                                label: 'Desde',
                                fecha: _desde,
                                onTap: _seleccionarDesde,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: _DateSelector(
                                label: 'Hasta',
                                fecha: _hasta,
                                onTap: _seleccionarHasta,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (_desde != null && _hasta != null)
                                ? _aplicarRango
                                : null,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: const Text('Aplicar Rango'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                  letterSpacing: 0.3,
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withValues(alpha: 0.05) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? c.primary.withValues(alpha: 0.3)
                : c.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? c.primary : c.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: isSelected ? c.primary : c.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fecha != null
                        ? DateFormat('dd MMM yyyy', 'es_ES').format(fecha!)
                        : 'DD/MM/AAAA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? c.onSurface : c.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                          if (corte.primerBoleta != null && corte.ultimaBoleta != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 12,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  corte.primerBoleta == corte.ultimaBoleta
                                      ? 'Boleta: ${corte.primerBoleta}'
                                      : 'Boletas: ${corte.primerBoleta} - ${corte.ultimaBoleta}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
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
                if (cobrados > 0 || pendientes > 0 ||
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
                          bgColor: const Color(0xFFE67E22).withValues(alpha: 0.08),
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
