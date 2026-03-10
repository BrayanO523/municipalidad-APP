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

    // Filtrar cobradores y locales por mercado seleccionado
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

    // Map locales por ID para facil acceso
    final mapLocales = {for (var l in localesDelMercado) l.id!: l};

    final selectedMercado = mercados.isEmpty || _selectedMercadoId == null
        ? null
        : mercados.firstWhere((m) => m.id == _selectedMercadoId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // PANEL LATERAL (Filtros y Lista Ordenable)
          Container(
            width: 380,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Diseño de Rutas',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Select Mercado
                Text(
                  '1. Seleccionar Mercado',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedMercadoId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                  ),
                  items: mercados
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            m.nombre ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                const SizedBox(height: 16),

                // Select Cobrador
                Text(
                  '2. Seleccionar Cobrador',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCobradorId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                  ),
                  hint: const Text('Elija un cobrador'),
                  items: cobradores
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.nombre ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final cobrador = cobradores.firstWhere((c) => c.id == val);
                    setState(() {
                      _selectedCobradorId = val;
                      _rutaActual = List<String>.from(
                        cobrador.rutaAsignada ?? [],
                      );
                    });
                  },
                ),
                const SizedBox(height: 24),
                Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 16),

                // Reorderable list
                Text(
                  '3. Ordenar Ruta de Cobro',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Arrastre para ordenar',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

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
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _rutaActual.removeAt(oldIndex);
                              _rutaActual.insert(newIndex, item);
                            });
                          },
                          children: _rutaActual.map((locId) {
                            final loc = mapLocales[locId]!;
                            final index = _rutaActual.indexOf(locId);
                            return ReorderableDragStartListener(
                              key: ValueKey(locId),
                              index: index,
                              child: Card(
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    maxRadius: 14,
                                    backgroundColor: Colors.blueAccent,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    loc.nombreSocial ?? 'Local',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.drag_handle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
          ),

          // MAPA
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(
                      14.628434,
                      -90.522713,
                    ), // Guatemala centro (ejemplo)
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

                    // Perímetros de los locales
                    PolygonLayer(
                      polygons: localesDelMercado
                          .where(
                            (l) =>
                                l.perimetro != null && l.perimetro!.isNotEmpty,
                          )
                          .map((l) {
                            return Polygon(
                              points: l.perimetro!
                                  .map((p) => LatLng(p['lat']!, p['lng']!))
                                  .toList(),
                              color: Colors.greenAccent.withValues(alpha: 0.2),
                              borderColor: Colors.greenAccent.withValues(
                                alpha: 0.5,
                              ),
                              borderStrokeWidth: 2,
                            );
                          })
                          .toList(),
                    ),
                    PolylineLayer(
                      polylines: [
                        if (_rutaActual.isNotEmpty)
                          Polyline(
                            points: _rutaActual.map((id) {
                              final loc = mapLocales[id]!;
                              return LatLng(loc.latitud!, loc.longitud!);
                            }).toList(),
                            strokeWidth: 4.0,
                            color: Colors.blueAccent.withValues(alpha: 0.7),
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: _rutaActual.map((id) {
                        final loc = mapLocales[id]!;
                        final index = _rutaActual.indexOf(id);
                        return Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(loc.latitud!, loc.longitud!),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 40,
                              ),
                              Positioned(
                                top: 5,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (_selectedMercadoId == null)
                  Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.7),
                    child: Center(
                      child: Text(
                        'Seleccione un Mercado para ver los locales',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
