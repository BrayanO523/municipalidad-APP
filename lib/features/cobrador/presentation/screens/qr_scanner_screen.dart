import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/printer_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../locales/domain/entities/local.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  Local? _localEncontrado;
  bool _yaEscaneado = false;
  bool _buscando = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_yaEscaneado || _buscando) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final qrData = barcode.rawValue!;
    setState(() {
      _yaEscaneado = true;
      _buscando = true;
      _error = null;
    });

    await _controller.stop();

    try {
      final ds = ref.read(localDatasourceProvider);
      final local = await ds.obtenerPorId(qrData);
      if (local == null) {
        setState(() {
          _error = 'Local no encontrado: $qrData';
          _buscando = false;
        });
      } else {
        setState(() {
          _localEncontrado = local;
          _buscando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de búsqueda: $e';
        _buscando = false;
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _yaEscaneado = false;
      _localEncontrado = null;
      _error = null;
      _buscando = false;
    });
    _controller.start();
  }

  Future<void> _registrarCobro(Local local) async {
    final montoCtrl = TextEditingController(
      text: local.cuotaDiaria?.toString() ?? '',
    );
    final obsCtrl = TextEditingController();
    final usuario = ref.read(currentUsuarioProvider).value;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cobrar - ${local.nombreSocial ?? ""}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Monto a cobrar (L)',
                    prefixIcon: Icon(Icons.payments_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != true) return;

    final monto = num.tryParse(montoCtrl.text) ?? 0;
    final cuota = local.cuotaDiaria ?? 0;
    final observaciones = obsCtrl.text.trim();

    // Lógica unificada de CobradorHomeScreen
    final saldoHoy = (cuota - monto).clamp(0, cuota);
    final estado = monto >= cuota
        ? 'cobrado'
        : monto > 0
        ? 'abono_parcial'
        : 'pendiente';

    final deudaActual = local.deudaAcumulada ?? 0;
    final paraDeudaReal = monto > deudaActual ? deudaActual : monto;
    final paraSaldoFavorReal = monto > paraDeudaReal
        ? monto - paraDeudaReal
        : 0;

    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';

    final double saldoResultante =
        (local.deudaAcumulada ?? 0).toDouble() -
        paraDeudaReal.toDouble() +
        saldoHoy.toDouble();
    final double favorResultante =
        (local.saldoAFavor ?? 0).toDouble() + paraSaldoFavorReal.toDouble();

    try {
      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);

      final int correlativo = await cobroDs.crearCobroConCorrelativo(
        cobroId: docId,
        mercadoId: local.mercadoId!,
        cobroData: {
          'actualizadoEn': Timestamp.fromDate(now),
          'actualizadoPor': usuario?.id ?? 'cobrador',
          'cobradorId': usuario?.id ?? '',
          'creadoEn': Timestamp.fromDate(now),
          'creadoPor': usuario?.id ?? 'cobrador',
          'cuotaDiaria': cuota,
          'estado': estado,
          'fecha': Timestamp.fromDate(now),
          'localId': local.id,
          'mercadoId': local.mercadoId,
          'municipalidadId': local.municipalidadId,
          'monto': monto,
          'pagoACuota': monto > cuota ? cuota : monto,
          'observaciones': monto > 0
              ? '${observaciones.isNotEmpty ? "$observaciones | " : ""}'
                    'Distribuido: ${paraDeudaReal > 0 ? "L ${paraDeudaReal.toStringAsFixed(2)} a deuda" : ""}'
                    '${paraDeudaReal > 0 && paraSaldoFavorReal > 0 ? " y " : ""}'
                    '${paraSaldoFavorReal > 0 ? "L ${paraSaldoFavorReal.toStringAsFixed(2)} a favor" : ""}'
              : observaciones,
          'saldoPendiente': saldoHoy,
          'deudaAnterior': local.deudaAcumulada ?? 0,
          'montoAbonadoDeuda': paraDeudaReal,
          'nuevoSaldoFavor': favorResultante,
          'telefonoRepresentante': local.telefonoRepresentante,
        },
      );

      if (local.id != null) {
        await localDs.procesarPago(local.id!, monto);
        await cobroDs.saldarDeudaHistoria(local.id!, monto);
      }

      // Imprimir ticket silenciosamente de fondo
      try {
        final printer = ref.read(printerServiceProvider);
        final mercados = ref
            .read(mercadosProvider)
            .maybeWhen(data: (list) => list, orElse: () => []);
        final mercadoNombre = mercados
            .where((m) => m.id == local.mercadoId)
            .firstOrNull
            ?.nombre;

        await printer.printReceipt(
          empresa: 'MUNICIPALIDAD',
          mercado: mercadoNombre,
          local: local.nombreSocial ?? 'Sin Nombre',
          monto: monto.toDouble(),
          fecha: now,
          saldoPendiente: saldoResultante > 0 ? saldoResultante : 0,
          saldoAFavor: favorResultante > 0 ? favorResultante : 0,
          deudaAnterior: (local.deudaAcumulada ?? 0).toDouble(),
          montoAbonadoDeuda: paraDeudaReal.toDouble(),
          cobrador: usuario?.nombre,
          correlativo: correlativo,
          anioCorrelativo: now.year,
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Cobro registrado: ${local.nombreSocial}'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        _resetScanner();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (_yaEscaneado)
            IconButton(
              onPressed: _resetScanner,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Escanear otro',
            ),
        ],
      ),
      body: _localEncontrado != null
          ? _LocalDetailPanel(
              local: _localEncontrado!,
              onCobrar: () => _registrarCobro(_localEncontrado!),
              onScanOtro: _resetScanner,
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                      // Overlay con marco
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_buscando)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Buscando local...'),
                      ],
                    ),
                  ),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _resetScanner,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Intentar de nuevo'),
                        ),
                      ],
                    ),
                  ),
                if (!_buscando && _error == null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Apunta la cámara al código QR del local',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LocalDetailPanel extends StatelessWidget {
  final Local local;
  final VoidCallback onCobrar;
  final VoidCallback onScanOtro;

  const _LocalDetailPanel({
    required this.local,
    required this.onCobrar,
    required this.onScanOtro,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Success header
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.green,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Local Encontrado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    local.nombreSocial ?? 'Sin nombre',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.person_rounded,
                    label: 'Representante',
                    value: local.representante ?? '-',
                  ),
                  _DetailRow(
                    icon: Icons.store_rounded,
                    label: 'Mercado',
                    value: local.mercadoId ?? '-',
                  ),
                  _DetailRow(
                    icon: Icons.square_foot_rounded,
                    label: 'Espacio',
                    value: '${local.espacioM2 ?? '-'} m²',
                  ),
                  _DetailRow(
                    icon: Icons.category_rounded,
                    label: 'Tipo',
                    value: local.tipoNegocioId ?? '-',
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.payments_rounded,
                    label: 'Cuota Diaria',
                    value: DateFormatter.formatCurrency(local.cuotaDiaria),
                    valueStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Action buttons
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onCobrar,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text(
                'Registrar Cobro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (local.latitud != null && local.longitud != null) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${local.latitud},${local.longitud}',
                  );
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir el mapa'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Abrir Ubicación (Maps)'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onScanOtro,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Escanear Otro QR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white38),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style:
                valueStyle ??
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
