import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../usuarios/domain/entities/usuario.dart';

class RutasAdminScreen extends ConsumerStatefulWidget {
  const RutasAdminScreen({super.key});

  @override
  ConsumerState<RutasAdminScreen> createState() => _RutasAdminScreenState();
}

class _RutasAdminScreenState extends ConsumerState<RutasAdminScreen> {
  String? _selectedMercadoId;
  String? _selectedCobradorId;
  List<String> _rutaActual = []; // Lista de IDs de locales en orden

  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final List<Mercado> mercados =
        ref.watch(mercadosProvider).value ?? <Mercado>[];
    final List<Local> localesData = ref.watch(localesProvider).value ?? [];
    final List<Usuario> usuariosData = ref.watch(usuariosProvider).value ?? [];

    final cobradores = usuariosData
        .where((u) => u.esCobrador && u.mercadoId == _selectedMercadoId)
        .toList();

    final localesDelMercado = localesData
        .where(
          (l) =>
              l.mercadoId == _selectedMercadoId &&
              l.latitud != null &&
              l.longitud != null,
        )
        .toList();

    final mapLocales = {for (var l in localesDelMercado) l.id!: l};

    final selectedMercado = _buscarMercadoPorId(mercados, _selectedMercadoId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          if (isMobile) {
            return Stack(
              children: [
                _buildMap(
                  context,
                  selectedMercado,
                  localesDelMercado,
                  mapLocales,
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.15,
                  maxChildSize: 0.9,
                  snap: true,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: _buildSidebar(
                              context,
                              mercados,
                              cobradores,
                              mapLocales,
                              isMobile: true,
                              scrollController: scrollController,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          }

          // DESKTOP LAYOUT
          return Row(
            children: [
              SizedBox(
                width: 380,
                child: _buildSidebar(context, mercados, cobradores, mapLocales),
              ),
              Expanded(
                child: _buildMap(
                  context,
                  selectedMercado,
                  localesDelMercado,
                  mapLocales,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    List<Mercado> mercados,
    List<Usuario> cobradores,
    Map<String, Local> mapLocales, {
    bool isMobile = false,
    ScrollController? scrollController,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Shared widgets: header controls (mercado, cobrador, ruta header)
    List<Widget> buildHeaderControls() {
      return [
        Text(
          'Diseno de Rutas',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: isMobile ? 18 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '1. Mercado',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedMercadoId,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: mercados
              .map(
                (m) => DropdownMenuItem(
                  value: m.id as String,
                  child: Text(m.nombre ?? '', overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedMercadoId = val;
              _selectedCobradorId = null;
              _rutaActual = [];
            });
            _centrarMapaEnMercado(_buscarMercadoPorId(mercados, val));
          },
        ),
        const SizedBox(height: 10),
        Text(
          '2. Cobrador',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedCobradorId,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          hint: const Text('Elija un cobrador'),
          items: cobradores
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.nombre ?? '', overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            final cobrador = cobradores.firstWhere((c) => c.id == val);
            setState(() {
              _selectedCobradorId = val;
              _rutaActual = List<String>.from(cobrador.rutaAsignada ?? []);
            });
          },
        ),
        const SizedBox(height: 12),
        Divider(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3. Ordenar Ruta',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Arrastre para ordenar',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (isMobile && _rutaActual.isNotEmpty)
              IconButton.filledTonal(
                onPressed: _guardarRuta,
                icon: const Icon(Icons.save, size: 18),
                tooltip: 'Guardar',
              ),
          ],
        ),
        const SizedBox(height: 8),
      ];
    }

    // Builds the route items list
    List<Widget> buildRouteItems() {
      if (_rutaActual.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Seleccione mercado y cobrador',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ),
            ),
          ),
        ];
      }
      return _rutaActual.where((id) => mapLocales.containsKey(id)).map((locId) {
        final loc = mapLocales[locId]!;
        final index = _rutaActual.indexOf(locId);
        return Card(
          key: ValueKey(locId),
          color: colorScheme.primary.withValues(alpha: 0.05),
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              maxRadius: 12,
              backgroundColor: colorScheme.primary,
              child: Text(
                '${index + 1}',
                style: TextStyle(fontSize: 10, color: colorScheme.onPrimary),
              ),
            ),
            title: Text(
              loc.nombreSocial ?? 'Local',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              Icons.drag_handle,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        );
      }).toList();
    }

    // MOBILE layout: everything scrollable
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _rutaActual.isEmpty
            ? ListView(
                controller: scrollController,
                children: [...buildHeaderControls(), ...buildRouteItems()],
              )
            : Column(
                children: [
                  // Controls at top (non-scrollable)
                  ...buildHeaderControls(),
                  // Reorderable list fills remaining space
                  Expanded(
                    child: ReorderableListView(
                      scrollController: scrollController,
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _rutaActual.removeAt(oldIndex);
                          _rutaActual.insert(newIndex, item);
                        });
                      },
                      children: _rutaActual
                          .where((id) => mapLocales.containsKey(id))
                          .map((locId) {
                            final loc = mapLocales[locId]!;
                            final index = _rutaActual.indexOf(locId);
                            return ReorderableDragStartListener(
                              key: ValueKey(locId),
                              index: index,
                              child: Card(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.05,
                                ),
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    maxRadius: 12,
                                    backgroundColor: colorScheme.primary,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    loc.nombreSocial ?? 'Local',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.drag_handle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
      );
    }

    // DESKTOP layout: fixed sidebar with Expanded list
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...buildHeaderControls(),
          Expanded(
            child: _rutaActual.isEmpty
                ? Center(
                    child: Text(
                      'Seleccione mercado y cobrador',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  )
                : ReorderableListView(
                    scrollController: scrollController,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _rutaActual.removeAt(oldIndex);
                        _rutaActual.insert(newIndex, item);
                      });
                    },
                    children: _rutaActual
                        .where((id) => mapLocales.containsKey(id))
                        .map((locId) {
                          final loc = mapLocales[locId]!;
                          final index = _rutaActual.indexOf(locId);
                          return ReorderableDragStartListener(
                            key: ValueKey(locId),
                            index: index,
                            child: Card(
                              color: colorScheme.primary.withValues(
                                alpha: 0.05,
                              ),
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  maxRadius: 12,
                                  backgroundColor: colorScheme.primary,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  loc.nombreSocial ?? 'Local',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.drag_handle,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar Ruta Asignada'),
            onPressed: _selectedCobradorId == null ? null : _guardarRuta,
          ),
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    Mercado? selectedMercado,
    List<Local> localesDelMercado,
    Map<String, Local> mapLocales,
  ) {
    final mercadoPerimetroPoints = _toPolygonPoints(selectedMercado?.perimetro);
    final centroMercado = _centroMercadoPorPerimetro(selectedMercado);
    final localPolygons = localesDelMercado
        .map((l) {
          final points = _toPolygonPoints(l.perimetro);
          if (points.isEmpty) return null;
          return Polygon(
            points: points,
            color: context.semanticColors.success.withValues(alpha: 0.2),
            borderColor: context.semanticColors.success.withValues(alpha: 0.5),
            borderStrokeWidth: 2,
          );
        })
        .whereType<Polygon>()
        .toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centroMercado ?? const LatLng(14.628434, -90.522713),
            initialZoom: centroMercado != null ? 16.0 : 15.0,
            onMapReady: () {
              if (centroMercado != null) {
                _moverMapa(centroMercado, zoom: 16.0);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.municipalidad.app',
              tileProvider: NetworkTileProvider(
                // En web, evitar abortos de requests en vuelo para que el
                // debugger no se detenga dentro de package:http/browser_client.
                abortObsoleteRequests: !kIsWeb,
                silenceExceptions: kIsWeb,
              ),
            ),
            if (mercadoPerimetroPoints.isNotEmpty)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: mercadoPerimetroPoints,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    borderColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.88),
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            if (localPolygons.isNotEmpty) PolygonLayer(polygons: localPolygons),
            PolylineLayer(
              polylines: [
                if (_rutaActual.any((id) => mapLocales.containsKey(id)))
                  Polyline(
                    points: _rutaActual
                        .where((id) => mapLocales.containsKey(id))
                        .map((id) {
                          final loc = mapLocales[id]!;
                          return LatLng(loc.latitud!, loc.longitud!);
                        })
                        .toList(),
                    strokeWidth: 4.0,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.7),
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                ..._rutaActual.where((id) => mapLocales.containsKey(id)).map((
                  id,
                ) {
                  final loc = mapLocales[id]!;
                  final index = _rutaActual.indexOf(id);
                  return Marker(
                    width: 30,
                    height: 30,
                    point: LatLng(loc.latitud!, loc.longitud!),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: context.semanticColors.danger,
                          size: 30,
                        ),
                        Positioned(
                          top: 2,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: context.semanticColors.onDanger,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ...mercadoPerimetroPoints.map((point) {
                  return Marker(
                    width: 12,
                    height: 12,
                    point: point,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        if (_selectedMercadoId != null && mercadoPerimetroPoints.isNotEmpty)
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.polyline_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Perimetro del mercado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_selectedMercadoId == null)
          Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            child: Center(
              child: Text(
                'Seleccione un Mercado',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (_selectedMercadoId != null && mercadoPerimetroPoints.isEmpty)
          Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'El mercado seleccionado no tiene perimetro. Agregue el perimetro en la vista de Mercados para disenar rutas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<LatLng> _toPolygonPoints(List<Map<String, double>>? perimetro) {
    if (perimetro == null || perimetro.isEmpty) return const [];

    final points = perimetro
        .map((p) {
          final lat = p['lat'];
          final lng = p['lng'];
          if (lat == null || lng == null) return null;
          if (!lat.isFinite || !lng.isFinite) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();

    return points;
  }

  LatLng? _centroMercadoPorPerimetro(Mercado? mercado) {
    final puntos = _toPolygonPoints(mercado?.perimetro);
    if (puntos.isEmpty) return null;
    double sumLat = 0;
    double sumLng = 0;
    for (final point in puntos) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    return LatLng(sumLat / puntos.length, sumLng / puntos.length);
  }

  void _centrarMapaEnMercado(Mercado? mercado) {
    final center = _centroMercadoPorPerimetro(mercado);
    if (center == null) return;
    _moverMapa(center, zoom: 16.0);
  }

  Mercado? _buscarMercadoPorId(List<Mercado> mercados, String? mercadoId) {
    if (mercadoId == null) return null;
    for (final mercado in mercados) {
      if (mercado.id == mercadoId) return mercado;
    }
    return null;
  }

  void _moverMapa(LatLng point, {double zoom = 16.0}) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // Evita romper la UI si el mapa aun no esta listo.
    }
  }

  Future<void> _guardarRuta() async {
    if (_selectedCobradorId == null) return;
    try {
      final ds = ref.read(authDatasourceProvider);
      await ds.actualizarRutaUsuario(_selectedCobradorId!, _rutaActual);
      ref.invalidate(usuariosProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ruta guardada exitosamente',
              style: TextStyle(color: context.semanticColors.onSuccess),
            ),
            backgroundColor: context.semanticColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: $e',
              style: TextStyle(color: context.semanticColors.onDanger),
            ),
            backgroundColor: context.semanticColors.danger,
          ),
        );
      }
    }
  }
}
