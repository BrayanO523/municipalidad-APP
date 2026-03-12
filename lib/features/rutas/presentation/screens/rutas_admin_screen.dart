import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../locales/domain/entities/local.dart';
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
    final mercados = ref.watch(mercadosProvider).value ?? [];
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

    final selectedMercado =
        mercados.isEmpty || _selectedMercadoId == null
            ? null
            : mercados.firstWhere((m) => m.id == _selectedMercadoId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          if (isMobile) {
            return Stack(
              children: [
                _buildMap(context, selectedMercado, localesDelMercado, mapLocales),
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
                            color: Colors.black.withValues(alpha: 0.2),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: _buildSidebar(
                              context,
                              mercados,
                              cobradores,
                              mapLocales,
                              localesData,
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
                child: _buildSidebar(
                  context,
                  mercados,
                  cobradores,
                  mapLocales,
                  localesData,
                ),
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
    List<dynamic> mercados,
    List<Usuario> cobradores,
    Map<String, Local> mapLocales,
    List<Local> localesData, {
    bool isMobile = false,
    ScrollController? scrollController,
  }) {
    return Container(
      color: isMobile ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Diseño de Rutas',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Select Mercado
          Text(
            '1. Mercado',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                _centrarMapaEnLocales(
                  localesData.where((l) => l.mercadoId == val).toList(),
                );
              });
            },
          ),
          const SizedBox(height: 12),

          // Select Cobrador
          Text(
            '2. Cobrador',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(height: 20),
          Divider(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),

          // Reorderable list header
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
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
          const SizedBox(height: 12),

          Expanded(
            child: _rutaActual.isEmpty
                ? Center(
                    child: Text(
                      'Seleccione mercado y cobrador',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
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
                          color: Colors.blueAccent.withValues(alpha: 0.05),
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.blueAccent.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              maxRadius: 12,
                              backgroundColor: Colors.blueAccent,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 10, color: Colors.white),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          if (!isMobile) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar Ruta Asignada'),
              onPressed: _selectedCobradorId == null ? null : _guardarRuta,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    dynamic selectedMercado,
    List<Local> localesDelMercado,
    Map<String, Local> mapLocales,
  ) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(14.628434, -90.522713),
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.municipalidad.app',
            ),
            if (selectedMercado?.perimetro != null)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: selectedMercado!.perimetro!
                        .map((p) => LatLng(p['lat']!, p['lng']!))
                        .toList(),
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderColor: Colors.blue.withValues(alpha: 0.2),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            PolygonLayer(
              polygons: localesDelMercado
                  .where((l) => l.perimetro != null && l.perimetro!.isNotEmpty)
                  .map((l) {
                    return Polygon(
                      points: l.perimetro!.map((p) => LatLng(p['lat']!, p['lng']!)).toList(),
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      borderColor: Colors.greenAccent.withValues(alpha: 0.5),
                      borderStrokeWidth: 2,
                    );
                  })
                  .toList(),
            ),
            PolylineLayer(
              polylines: [
                if (_rutaActual.any((id) => mapLocales.containsKey(id)))
                  Polyline(
                    points: _rutaActual
                        .where((id) => mapLocales.containsKey(id))
                        .map((id) {
                      final loc = mapLocales[id]!;
                      return LatLng(loc.latitud!, loc.longitud!);
                    }).toList(),
                    strokeWidth: 4.0,
                    color: Colors.blueAccent.withValues(alpha: 0.7),
                  ),
              ],
            ),
            MarkerLayer(
              markers: _rutaActual
                  .where((id) => mapLocales.containsKey(id))
                  .map((id) {
                    final loc = mapLocales[id]!;
                    final index = _rutaActual.indexOf(id);
                    return Marker(
                      width: 30,
                      height: 30,
                      point: LatLng(loc.latitud!, loc.longitud!),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 30),
                          Positioned(
                            top: 2,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(),
            ),
          ],
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
      ],
    );
  }

  void _centrarMapaEnLocales(List<Local> locales) {
    if (locales.isEmpty) return;

    final conCoordenadas = locales
        .where((l) => l.latitud != null && l.longitud != null)
        .toList();
    if (conCoordenadas.isEmpty) return;

    double sumLat = 0;
    double sumLng = 0;
    for (var l in conCoordenadas) {
      if (l.latitud != null && l.longitud != null) {
        sumLat += l.latitud!;
        sumLng += l.longitud!;
      }
    }

    final center = LatLng(
      sumLat / conCoordenadas.length,
      sumLng / conCoordenadas.length,
    );
    _mapController.move(center, 16.0);
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
