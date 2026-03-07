import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/printer_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';

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

  Future<double> _montoPagadoHoy(String localId) async {
    try {
      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day);
      final querySnapshot = await FirebaseFirestore.instance
          .collection('cobros_json')
          .where('localId', isEqualTo: localId)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .get();
      double total = 0;
      for (var doc in querySnapshot.docs) {
        final monto = (doc.data()['monto'] as num?)?.toDouble() ?? 0.0;
        total += monto;
      }
      return total;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _registrarCobro(Local local) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    final pagadoHoy = await _montoPagadoHoy(local.id ?? '');
    if (mounted) Navigator.pop(context); // cerrar circular progress

    final cuota = local.cuotaDiaria ?? 0;
    final saldoActual = local.saldoAFavor ?? 0;
    final cuotaCubierta = pagadoHoy >= cuota;

    // Si tiene saldo a favor suficiente y NO ha pagado hoy, auto-cobrar con el crédito
    if (saldoActual >= cuota && cuota > 0 && !cuotaCubierta) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.savings_rounded,
                size: 22,
                color: Color(0xFF00D9A6),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Usar Saldo a Favor',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${local.nombreSocial ?? ""} tiene un crédito de:'),
              const SizedBox(height: 8),
              Text(
                DateFormatter.formatCurrency(saldoActual),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9A6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Se descontará ${DateFormatter.formatCurrency(cuota)} de ese crédito para cubrir el día de hoy.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _aplicarSaldoAFavor(local);
      return;
    }

    // Calcular cuánto falta para la cuota hoy
    final faltanteHoy = (cuota - pagadoHoy).clamp(0, cuota);
    final montoSugerido = faltanteHoy > 0 ? faltanteHoy : cuota;

    final montoCtrl = TextEditingController(text: montoSugerido.toString());
    final obsCtrl = TextEditingController();
    final usuario = ref.read(currentUsuarioProvider).value;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              cuotaCubierta
                  ? Icons.add_circle_outline_rounded
                  : Icons.receipt_long_rounded,
              size: 22,
              color: cuotaCubierta ? const Color(0xFF00D9A6) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cuotaCubierta
                    ? 'Abono Extra - ${local.nombreSocial ?? ""}'
                    : 'Cobrar - ${local.nombreSocial ?? ""}',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!cuotaCubierta)
                  _InfoRow(
                    label: 'Cuota diaria',
                    value: DateFormatter.formatCurrency(cuota),
                  ),
                if (pagadoHoy > 0)
                  _InfoRow(
                    label: 'Pagado hoy',
                    value: DateFormatter.formatCurrency(pagadoHoy),
                    color: Colors.green,
                  ),
                if (faltanteHoy > 0 && pagadoHoy > 0)
                  _InfoRow(
                    label: 'Faltante cuota',
                    value: DateFormatter.formatCurrency(faltanteHoy),
                    color: Colors.orange,
                  ),
                _InfoRow(
                  label: 'Representante',
                  value: local.representante ?? '-',
                ),
                if (saldoActual > 0)
                  _InfoRow(
                    label: 'Saldo a favor',
                    value: DateFormatter.formatCurrency(saldoActual),
                    color: const Color(0xFF00D9A6),
                  ),
                if ((local.deudaAcumulada ?? 0) > 0)
                  _InfoRow(
                    label: 'Deuda Acumulada',
                    value: DateFormatter.formatCurrency(local.deudaAcumulada),
                    color: const Color(0xFFEE5A6F),
                  ),
                _InfoRow(
                  label: 'Balance Neto',
                  value: DateFormatter.formatCurrency(local.balanceNeto),
                  color: local.balanceNeto >= 0
                      ? const Color(0xFF00D9A6)
                      : const Color(0xFFEE5A6F),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monto a cobrar (L)',
                    prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                    helperText:
                        'Si paga más de L ${cuota.toStringAsFixed(0)}, el excedente queda como saldo a favor',
                    helperMaxLines: 2,
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
                  label: const Text('Registrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final monto = num.tryParse(montoCtrl.text) ?? 0;
    await _guardarCobro(
      local: local,
      monto: monto,
      observaciones: obsCtrl.text,
      usuario: usuario,
      pagadoHoy: pagadoHoy,
    );
  }

  /// Aplica el saldo a favor del local para cubrir la cuota del día.
  Future<void> _aplicarSaldoAFavor(Local local) async {
    final cuota = local.cuotaDiaria ?? 0;
    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';
    final usuario = ref.read(currentUsuarioProvider).value;
    try {
      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);

      final int correlativo = await cobroDs.crearCobroConCorrelativo(
        cobroId: docId,
        mercadoId: local.mercadoId!,
        cobroData: {
          'cobradorId': usuario?.id ?? '',
          'creadoEn': Timestamp.fromDate(now),
          'creadoPor': usuario?.id ?? 'sistema',
          'actualizadoEn': Timestamp.fromDate(now),
          'actualizadoPor': usuario?.id ?? 'sistema',
          'cuotaDiaria': cuota,
          'estado': 'cobrado',
          'fecha': Timestamp.fromDate(now),
          'localId': local.id,
          'mercadoId': local.mercadoId,
          'municipalidadId': local.municipalidadId,
          'monto': cuota,
          'observaciones': 'Pagado con saldo a favor',
          'saldoPendiente': 0,
        },
      );
      // Descontar la cuota del saldo a favor
      await localDs.actualizarSaldoAFavor(local.id!, -cuota);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '💰 Cobro aplicado con saldo a favor: ${local.nombreSocial}',
            ),
            backgroundColor: const Color(0xFF00D9A6),
          ),
        );
      }

      // Imprimir boleta
      try {
        final printer = ref.read(printerServiceProvider);

        final double saldoResultante = (local.deudaAcumulada ?? 0).toDouble();
        final double favorResultante =
            (local.saldoAFavor ?? 0).toDouble() - cuota.toDouble();

        final impreso = await printer.printReceipt(
          empresa: 'MUNICIPALIDAD',
          local: local.nombreSocial ?? 'Sin Nombre',
          monto: cuota.toDouble(),
          fecha: now,
          saldoPendiente: saldoResultante > 0 ? saldoResultante : 0,
          saldoAFavor: favorResultante > 0 ? favorResultante : 0,
          cobrador: usuario?.nombre,
          correlativo: correlativo,
          anioCorrelativo: now.year,
        );
        if (!impreso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Comprobante no impreso.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (_) {}

      _resetScanner();
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

  /// Lógica central de guardado. Maneja excedentes como abono a deuda o saldo a favor.
  Future<void> _guardarCobro({
    required Local local,
    required num monto,
    required String observaciones,
    required dynamic usuario,
    required double pagadoHoy,
  }) async {
    final cuota = local.cuotaDiaria ?? 0;

    // Cuánto falta para cubrir la cuota de hoy
    final faltanteHoy = (cuota - pagadoHoy).clamp(0, cuota);

    // De lo que paga el usuario, ¿cuánto va para la cuota de hoy?
    final pagoACuota = monto > faltanteHoy ? faltanteHoy : monto;

    // El saldo que queda específicamente de la cuota de HOY
    final saldoHoy = (faltanteHoy - pagoACuota).clamp(0, cuota);

    final cuotaTotalHoy = pagadoHoy + pagoACuota;
    final estado = cuotaTotalHoy >= cuota
        ? 'cobrado'
        : cuotaTotalHoy > 0
        ? 'abono_parcial'
        : 'pendiente';

    // Calculamos cuánto va para deuda y cuánto para saldo extra
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
          'pagoACuota': pagoACuota,
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

      // Imprimir boleta silenciosamente de fondo
      try {
        final printer = ref.read(printerServiceProvider);
        final mercados = ref
            .read(mercadosProvider)
            .maybeWhen(data: (list) => list, orElse: () => <Mercado>[]);
        final mercadoNombre = mercados
            .where((m) => m.id == local.mercadoId)
            .firstOrNull
            ?.nombre;

        final impreso = await printer.printReceipt(
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
        if (!impreso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Comprobante Bluetoooth no impreso.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (_) {}

      if (mounted) {
        String mensajeExtra = '';
        if (paraDeudaReal > 0) {
          mensajeExtra +=
              '\n📉 Deuda -${DateFormatter.formatCurrency(paraDeudaReal)}';
        }
        if (paraSaldoFavorReal > 0) {
          mensajeExtra +=
              '\n💬 Saldo +${DateFormatter.formatCurrency(paraSaldoFavorReal)}';
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1B27),
            title: const Text(
              '✅ Cobro Registrado',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '${local.nombreSocial}$mensajeExtra',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetScanner();
                },
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _compartirPdfPostCobro(
                    context: context,
                    local: local,
                    monto: monto.toDouble(),
                    fecha: now,
                    saldoPendiente: saldoResultante > 0 ? saldoResultante : 0,
                    deudaAnterior: (local.deudaAcumulada ?? 0).toDouble(),
                    montoAbonadoDeuda: paraDeudaReal.toDouble(),
                    saldoAFavor: favorResultante > 0 ? favorResultante : 0,
                    correlativo: correlativo,
                    cobradorNombre: usuario?.nombre,
                  );
                  _resetScanner();
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
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

  Future<void> _compartirPdfPostCobro({
    required BuildContext context,
    required Local local,
    required double monto,
    required DateTime fecha,
    required double saldoPendiente,
    required double deudaAnterior,
    required double montoAbonadoDeuda,
    required double saldoAFavor,
    required int correlativo,
    required String? cobradorNombre,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando boleta en formato PDF...'),
        duration: Duration(seconds: 1),
      ),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'MUNICIPALIDAD',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Comprobante de Cobro',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (local.nombreSocial != null) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Local: ${local.nombreSocial}'),
                ),
              ],
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Fecha: ${DateFormatter.formatDateTime(fecha)}'),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Cobrador: ${cobradorNombre ?? "Desconocido"}'),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Boleta N°: $correlativo'),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Monto Pagado:'),
                  pw.Text(
                    DateFormatter.formatCurrency(monto),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (deudaAnterior > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deuda Anterior:'),
                    pw.Text(DateFormatter.formatCurrency(deudaAnterior)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Abonado a Deuda:'),
                    pw.Text(DateFormatter.formatCurrency(montoAbonadoDeuda)),
                  ],
                ),
              ],
              if (saldoPendiente > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deuda Actual:'),
                    pw.Text(DateFormatter.formatCurrency(saldoPendiente)),
                  ],
                ),
              if (saldoAFavor > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Saldo a Favor:'),
                    pw.Text(DateFormatter.formatCurrency(saldoAFavor)),
                  ],
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                '*** GRACIAS POR SU PAGO ***',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Comprobante_Municipalidad_$correlativo.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al compartir PDF: $e')));
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
