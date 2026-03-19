import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../app/theme/app_theme.dart';

enum MapPickerMode { point, polygon }

class MapPickerModal extends StatefulWidget {
  final MapPickerMode mode;
  final LatLng? initialCenter;
  final LatLng? marketCenter;
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
    this.marketCenter,
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
  LatLng? _currentPosition;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPoints != null) {
      _points.addAll(widget.initialPoints!);
    }
    _detectarUbicacionActual();
  }

  LatLng get _initialMapCenter {
    return widget.initialCenter ??
        (widget.initialPoints?.isNotEmpty == true
            ? widget.initialPoints!.first
            : widget.marketCenter ??
                  _currentPosition ??
                  const LatLng(14.582, -90.589));
  }

  bool get _shouldAutoCenterToCurrentLocation {
    final hasInitialPoints = widget.initialPoints?.isNotEmpty == true;
    final hasMarketPerimeter = widget.marketPerimeter?.isNotEmpty == true;
    return widget.initialCenter == null &&
        !hasInitialPoints &&
        widget.marketCenter == null &&
        !hasMarketPerimeter;
  }

  Future<void> _detectarUbicacionActual() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = point);

      if (_isMapReady && _shouldAutoCenterToCurrentLocation) {
        _moverMapa(point, zoom: widget.initialZoom ?? 15.0);
      }
    } catch (_) {
      // Mantener fallback actual si falla GPS/permisos.
    }
  }

  void _moverMapa(LatLng point, {double zoom = 15.0}) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // Evita romper la UI si el mapa aun no esta listo.
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
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return Dialog(
      insetPadding: EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(
                    widget.mode == MapPickerMode.polygon
                        ? Icons.polyline_rounded
                        : Icons.location_on_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.mode == MapPickerMode.polygon
                        ? 'Definir Perímetro del Mercado'
                        : 'Ubicar Local en el Mapa',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
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
                      initialCenter: _initialMapCenter,
                      initialZoom: widget.initialZoom ?? 15.0,
                      onTap: _handleTap,
                      onMapReady: () {
                        _isMapReady = true;
                        if (_currentPosition != null &&
                            _shouldAutoCenterToCurrentLocation) {
                          _moverMapa(
                            _currentPosition!,
                            zoom: widget.initialZoom ?? 15.0,
                          );
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.municipalidad.app',
                        tileProvider: NetworkTileProvider(
                          abortObsoleteRequests: !kIsWeb,
                          silenceExceptions: kIsWeb,
                        ),
                      ),

                      // Perímetro del mercado (contexto)
                      if (widget.marketPerimeter != null &&
                          widget.marketPerimeter!.isNotEmpty)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: widget.marketPerimeter!,
                              color: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderColor: colorScheme.primary.withValues(
                                alpha: 0.6,
                              ),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.2),
                              borderColor: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      if (widget.marketCenter != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: widget.marketCenter!,
                              width: 38,
                              height: 38,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: semantic.info,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: semantic.onInfo,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.storefront_rounded,
                                  color: semantic.onInfo,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Dibujo actual
                      if (widget.mode == MapPickerMode.polygon &&
                          _points.length > 1)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _points,
                              color: semantic.success.withValues(alpha: 0.2),
                              borderColor: semantic.success,
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
                            child: Icon(
                              Icons.location_on,
                              color: semantic.danger,
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
                        color: colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.mode == MapPickerMode.polygon
                            ? 'Toque el mapa para añadir vértices del perímetro'
                            : 'Toque el mapa para marcar la ubicación exacta',
                        style: TextStyle(
                          color: colorScheme.onInverseSurface,
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
              padding: EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Text(
                    widget.mode == MapPickerMode.polygon
                        ? '${_points.length} puntos definidos'
                        : _points.isEmpty
                        ? 'Ningún punto seleccionado'
                        : 'Ubicación seleccionada',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _points.clear());
                    },
                    child: Text(
                      'Limpiar',
                      style: TextStyle(color: semantic.danger),
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
