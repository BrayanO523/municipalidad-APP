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
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esto creara cobros PENDIENTES en Firestore. Solo para pruebas.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Selector de local
            const Text('Seleccionar Local:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            localesAsync.when(
              data: (locales) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1B27),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1B27),
                    value: _localIdSeleccionado,
                    hint: const Text('Elige un local', style: TextStyle(color: Colors.white38)),
                    items: locales.map((l) {
                      return DropdownMenuItem(
                        value: l.id,
                        child: Text(
                          '${l.nombreSocial ?? "Sin nombre"} (L ${l.cuotaDiaria ?? 0})',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      final local = locales.firstWhere((l) => l.id == v);
                      setState(() {
                        _localIdSeleccionado = v;
                        _localNombre = local.nombreSocial;
                        _cuotaDiaria = (local.cuotaDiaria ?? 50).toDouble();
                      });
                    },
                    underline: const SizedBox.shrink(),
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 20),

            // Dias de deuda
            Row(
              children: [
                const Text('Dias de deuda: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1B27),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<int>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1B27),
                    value: _diasDeDeuda,
                    items: [3, 5, 7, 10, 15, 20, 30].map((d) {
                      return DropdownMenuItem(value: d, child: Text('$d', style: const TextStyle(color: Colors.white)));
                    }).toList(),
                    onChanged: (v) => setState(() => _diasDeDeuda = v ?? 10),
                    underline: const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Cuota: L ${_cuotaDiaria.toStringAsFixed(2)}',
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
                    'Se crearan $_diasDeDeuda cobros pendientes',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Deuda total: ${DateFormatter.formatCurrency(_diasDeDeuda * _cuotaDiaria)}',
                    style: const TextStyle(color: Color(0xFFEE5A6F), fontSize: 12),
                  ),
                  Text(
                    'Fechas: hace $_diasDeDeuda dias hasta ayer',
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch_rounded),
                label: Text(_cargando ? 'Generando...' : 'Generar Datos de Prueba'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
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
    setState(() { _cargando = true; _log = ''; });

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
        final fecha = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
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
        final fechaStr = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
        _addLog('  + $fechaStr  L ${_cuotaDiaria.toStringAsFixed(2)}  [$docId]');
      }

      // Actualizar deudaAcumulada del local
      final deudaTotal = _diasDeDeuda * _cuotaDiaria;
      final deudaExistente = (localData['deudaAcumulada'] as num?)?.toDouble() ?? 0;
      batch.update(firestore.collection('locales').doc(localId), {
        'deudaAcumulada': deudaExistente + deudaTotal,
      });

      await batch.commit();

      _addLog('\n--- COMPLETADO ---');
      _addLog('$_diasDeDeuda cobros pendientes creados');
      _addLog('Deuda sumada: ${DateFormatter.formatCurrency(deudaTotal)}');
      _addLog('Deuda total local: ${DateFormatter.formatCurrency(deudaExistente + deudaTotal)}');
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
