import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';

class CobradorMapScreen extends ConsumerStatefulWidget {
  const CobradorMapScreen({super.key});

  @override
  ConsumerState<CobradorMapScreen> createState() => _CobradorMapScreenState();
}

class _CobradorMapScreenState extends ConsumerState<CobradorMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Get current position once
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });
    _mapController.move(_currentPosition!, 15.0);

    // Listen to changes
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentPosition = LatLng(position.latitude, position.longitude);
              if (_followUser) {
                _mapController.move(
                  _currentPosition!,
                  _mapController.camera.zoom,
                );
              }
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final usuario = ref.watch(currentUsuarioProvider).value;
    final List<Local> localesData = ref.watch(localesProvider).value ?? [];

    // Obtener datos del mercado asignado
    final mercadosData = ref.watch(mercadosProvider).value ?? [];
    final mercado = mercadosData.cast<Mercado?>().firstWhere(
      (m) => m?.id == usuario?.mercadoId,
      orElse: () => null,
    );

    // Filtrar locales del cobrador (mismo mercado y con coordenadas)
    final localesRuta = localesData
        .where(
          (l) =>
              l.mercadoId == usuario?.mercadoId &&
              l.latitud != null &&
              l.longitud != null,
        )
        .toList();

    // Ordenar segun rutaAsignada
    if (usuario != null &&
        usuario.rutaAsignada != null &&
        usuario.rutaAsignada!.isNotEmpty) {
      final orden = usuario.rutaAsignada!;
      localesRuta.sort((a, b) {
        int indexA = orden.indexOf(a.id ?? '');
        int indexB = orden.indexOf(b.id ?? '');
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    }

    // Construcción de la ruta dinámica
    final List<LatLng> rutaAproximacion = [];
    if (_currentPosition != null && mercado?.latitud != null) {
      rutaAproximacion.add(_currentPosition!);
      rutaAproximacion.add(LatLng(mercado!.latitud!, mercado.longitud!));
    }

    final List<LatLng> rutaCobro = [];
    if (mercado?.latitud != null) {
      rutaCobro.add(LatLng(mercado!.latitud!, mercado.longitud!));
    }
    rutaCobro.addAll(localesRuta.map((l) => LatLng(l.latitud!, l.longitud!)));

    return Scaffold(
      appBar: AppBar(
        title: Text(mercado?.nombre ?? 'Mi Ruta'),
        actions: [
          IconButton(
            icon: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () => setState(() => _followUser = !_followUser),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              _currentPosition ?? const LatLng(14.628434, -90.522713),
          initialZoom: 15.0,
          onPositionChanged: (pos, hasGesture) {
            if (hasGesture && _followUser) {
              setState(() => _followUser = false);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.municipalidad.app',
          ),

          // Línea de Aproximación (Naranja) - GPS a Mercado
          if (rutaAproximacion.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: rutaAproximacion,
                  strokeWidth: 4.0,
                  color: semantic.warning.withValues(alpha: 0.8),
                  // isDotted no parece ser compatible con Polyline directamente en algunas versiones
                  // por lo que lo removemos si causa error o usamos pattern si está disponible
                ),
              ],
            ),

          // Línea de Ruta de Cobro (Azul) - Mercado a Locales
          if (rutaCobro.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: rutaCobro,
                  strokeWidth: 5.0,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
              ],
            ),

          // Marcadores
          MarkerLayer(
            markers: [
              // Marcador del Mercado
              if (mercado?.latitud != null)
                Marker(
                  width: 45,
                  height: 45,
                  point: LatLng(mercado!.latitud!, mercado.longitud!),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: semantic.success,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 4,
                              color: colorScheme.shadow.withValues(alpha: 0.26),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.store_rounded,
                          color: semantic.onSuccess,
                          size: 20,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: semantic.success,
                        size: 12,
                      ),
                    ],
                  ),
                ),

              // Marcadores de locales
              ...localesRuta.asMap().entries.map((entry) {
                final idx = entry.key;
                final loc = entry.value;
                return Marker(
                  width: 32,
                  height: 32,
                  point: LatLng(loc.latitud!, loc.longitud!),
                  child: Container(
                    decoration: BoxDecoration(
                      color: semantic.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: semantic.onDanger, width: 2),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: colorScheme.shadow.withValues(alpha: 0.26),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: semantic.onDanger,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Marcador de posicion actual
              if (_currentPosition != null)
                Marker(
                  width: 40,
                  height: 40,
                  point: _currentPosition!,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(Icons.circle, color: colorScheme.primary, size: 16),
                      Icon(
                        Icons.circle_outlined,
                        color: colorScheme.onPrimary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            setState(() => _followUser = true);
            _mapController.move(_currentPosition!, 17.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
