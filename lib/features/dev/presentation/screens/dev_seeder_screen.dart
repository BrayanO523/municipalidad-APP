import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';

/// Pantalla de desarrollo para generar cobros pendientes de prueba (FIFO testing).
/// Solo disponible en modo debug.
class DevSeederScreen extends ConsumerStatefulWidget {
  const DevSeederScreen({super.key});

  @override
  ConsumerState<DevSeederScreen> createState() => _DevSeederScreenState();
}

class _DevSeederScreenState extends ConsumerState<DevSeederScreen> {
  int _diasDeDeuda = 10;
  double _cuotaDiaria = 50.0;
  String? _localIdSeleccionado;
  String? _localNombre;
  bool _cargando = false;
  String _log = '';

  // Buscador de locales
  final _searchController = TextEditingController();
  final _diasController = TextEditingController(text: '10');
  String _busqueda = '';

  @override
  void dispose() {
    _searchController.dispose();
    _diasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localesAsync = ref.watch(localesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF12131A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1B27),
        title: const Text('Seeder FIFO (Dev)', style: TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Advertencia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esto creará cobros PENDIENTES en Firestore. Solo para pruebas.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Selector de local con buscador
            const Text(
              'Seleccionar Local:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            // Campo de búsqueda — filtra en memoria, sin lecturas extra
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar local por nombre...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1B27),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            localesAsync.when(
              data: (locales) {
                // Filtrar en memoria sin ninguna lectura adicional de Firestore
                final filtrados = _busqueda.isEmpty
                    ? locales
                    : locales
                          .where(
                            (l) => (l.nombreSocial ?? '')
                                .toLowerCase()
                                .contains(_busqueda),
                          )
                          .toList();

                if (filtrados.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  );
                }

                return Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1B27),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final l = filtrados[index];
                      final isSelected = _localIdSeleccionado == l.id;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedColor: const Color(0xFF6C63FF),
                        selectedTileColor: const Color(
                          0xFF6C63FF,
                        ).withValues(alpha: 0.15),
                        title: Text(
                          l.nombreSocial ?? 'Sin nombre',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF6C63FF)
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          DateFormatter.formatCurrency(l.cuotaDiaria),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => setState(() {
                          _localIdSeleccionado = l.id;
                          _localNombre = l.nombreSocial;
                          _cuotaDiaria = (l.cuotaDiaria ?? 50).toDouble();
                        }),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) =>
                  Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 20),

            // Días de deuda — campo editable
            Row(
              children: [
                const Text(
                  'Días de deuda: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _diasController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1B27),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                      ),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0 && parsed <= 365) {
                        setState(() => _diasDeDeuda = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Cuota: ${DateFormatter.formatCurrency(_cuotaDiaria)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Resumen
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se crearán $_diasDeDeuda cobros pendientes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Deuda total: ${DateFormatter.formatCurrency(_diasDeDeuda * _cuotaDiaria)}',
                    style: const TextStyle(
                      color: Color(0xFFEE5A6F),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Fechas: hace $_diasDeDeuda días hasta ayer',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _cargando || _localIdSeleccionado == null
                    ? null
                    : () => _generarDatos(),
                icon: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  _cargando ? 'Generando...' : 'Generar Datos de Prueba',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Log
            if (_log.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0F18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarDatos() async {
    if (_localIdSeleccionado == null) return;
    setState(() {
      _cargando = true;
      _log = '';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final now = DateTime.now();
      final localId = _localIdSeleccionado!;

      // Obtener datos del local para mercadoId y municipalidadId
      final localDoc = await firestore.collection('locales').doc(localId).get();
      final localData = localDoc.data() ?? {};
      final mercadoId = localData['mercadoId'] as String? ?? '';
      final muniId = localData['municipalidadId'] as String? ?? '';

      _addLog('Local: $_localNombre ($localId)');
      _addLog('Mercado: $mercadoId | Muni: $muniId');
      _addLog('Generando $_diasDeDeuda cobros pendientes...\n');

      for (int i = _diasDeDeuda; i >= 1; i--) {
        final fecha = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        final docId = 'TEST-$localId-${fecha.millisecondsSinceEpoch}';

        final data = <String, dynamic>{
          'cobradorId': 'SEEDER_DEV',
          'actualizadoEn': Timestamp.fromDate(now),
          'actualizadoPor': 'SEEDER_DEV',
          'creadoEn': Timestamp.fromDate(now),
          'creadoPor': 'SEEDER_DEV',
          'cuotaDiaria': _cuotaDiaria,
          'estado': 'pendiente',
          'fecha': Timestamp.fromDate(fecha),
          'localId': localId,
          'mercadoId': mercadoId,
          'municipalidadId': muniId,
          'monto': 0,
          'observaciones': 'Cobro pendiente generado por Seeder Dev',
          'saldoPendiente': _cuotaDiaria,
          'telefonoRepresentante': localData['telefonoRepresentante'],
        };

        batch.set(firestore.collection('cobros').doc(docId), data);
        final fechaStr =
            '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
        _addLog(
          '  + $fechaStr  ${DateFormatter.formatCurrency(_cuotaDiaria)}  [$docId]',
        );
      }

      // Actualizar deudaAcumulada del local
      final deudaTotal = _diasDeDeuda * _cuotaDiaria;
      final deudaExistente =
          (localData['deudaAcumulada'] as num?)?.toDouble() ?? 0;
      batch.update(firestore.collection('locales').doc(localId), {
        'deudaAcumulada': deudaExistente + deudaTotal,
      });

      await batch.commit();

      _addLog('\n--- COMPLETADO ---');
      _addLog('$_diasDeDeuda cobros pendientes creados');
      _addLog('Deuda sumada: ${DateFormatter.formatCurrency(deudaTotal)}');
      _addLog(
        'Deuda total local: ${DateFormatter.formatCurrency(deudaExistente + deudaTotal)}',
      );
      _addLog('\nAhora ve a cobrar ese local para probar FIFO');
    } catch (e) {
      _addLog('\n--- ERROR ---\n$e');
    }

    setState(() => _cargando = false);
  }

  void _addLog(String line) {
    setState(() => _log += '$line\n');
  }
}
