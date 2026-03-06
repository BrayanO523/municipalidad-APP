import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum MapPickerMode { point, polygon }

class MapPickerModal extends StatefulWidget {
  final MapPickerMode mode;
  final LatLng? initialCenter;
  final double? initialZoom;
  final List<LatLng>? initialPoints;
  final List<LatLng>?
  marketPerimeter; // Para mostrar el contexto del mercado si aplica
  final List<List<LatLng>>? existingPolygons; // Otros locales ya dibujados
  final List<LatLng>? existingPoints; // Otros locales marcados como punto

  const MapPickerModal({
    super.key,
    required this.mode,
    this.initialCenter,
    this.initialZoom,
    this.initialPoints,
    this.marketPerimeter,
    this.existingPolygons,
    this.existingPoints,
  });

  @override
  State<MapPickerModal> createState() => _MapPickerModalState();
}

class _MapPickerModalState extends State<MapPickerModal> {
  final List<LatLng> _points = [];
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPoints != null) {
      _points.addAll(widget.initialPoints!);
    }
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      if (widget.mode == MapPickerMode.point) {
        _points.clear();
        _points.add(point);
      } else {
        _points.add(point);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: const Color(0xFF1E1E2D),
              child: Row(
                children: [
                  Icon(
                    widget.mode == MapPickerMode.polygon
                        ? Icons.polyline_rounded
                        : Icons.location_on_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.mode == MapPickerMode.polygon
                        ? 'Definir Perímetro del Mercado'
                        : 'Ubicar Local en el Mapa',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Mapa
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          widget.initialCenter ??
                          (widget.initialPoints?.isNotEmpty == true
                              ? widget.initialPoints!.first
                              : const LatLng(
                                  14.582,
                                  -90.589,
                                )), // Villa Nueva aprox
                      initialZoom: widget.initialZoom ?? 15.0,
                      onTap: _handleTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.municipalidad.app',
                      ),

                      // Perímetro del mercado (contexto)
                      if (widget.marketPerimeter != null &&
                          widget.marketPerimeter!.isNotEmpty)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: widget.marketPerimeter!,
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderColor: Colors.blue.withValues(alpha: 0.6),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),

                      // Locales existentes (referencia)
                      if (widget.existingPolygons != null)
                        PolygonLayer(
                          polygons: widget.existingPolygons!.map((poly) {
                            return Polygon(
                              points: poly,
                              color: Colors.white.withValues(alpha: 0.2),
                              borderColor: Colors.white70,
                              borderStrokeWidth: 1.5,
                            );
                          }).toList(),
                        ),
                      if (widget.existingPoints != null)
                        MarkerLayer(
                          markers: widget.existingPoints!.map((p) {
                            return Marker(
                              point: p,
                              width: 12,
                              height: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black45,
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      // Dibujo actual
                      if (widget.mode == MapPickerMode.polygon &&
                          _points.length > 1)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _points,
                              color: Colors.green.withValues(alpha: 0.2),
                              borderColor: Colors.green,
                              borderStrokeWidth: 3,
                            ),
                          ],
                        ),

                      MarkerLayer(
                        markers: _points.map((p) {
                          return Marker(
                            point: p,
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 30,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // Instrucciones overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.mode == MapPickerMode.polygon
                            ? 'Toque el mapa para añadir vértices del perímetro'
                            : 'Toque el mapa para marcar la ubicación exacta',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E1E2D),
              child: Row(
                children: [
                  Text(
                    widget.mode == MapPickerMode.polygon
                        ? '${_points.length} puntos definidos'
                        : _points.isEmpty
                        ? 'Ningún punto seleccionado'
                        : 'Ubicación seleccionada',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _points.clear());
                    },
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _points.isEmpty
                        ? null
                        : () => Navigator.pop(context, _points),
                    child: const Text('Confirmar Selección'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
