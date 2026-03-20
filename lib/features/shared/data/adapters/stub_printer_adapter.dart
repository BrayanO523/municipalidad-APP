import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../../../core/platform/printer_service.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
import '../../../../core/utils/date_range_formatter.dart';

/// Implementación para plataformas Web y Desktop que genera un PDF.
/// Permite "imprimir" comprobantes abriendo el diálogo del sistema.
class StubPrinterAdapter implements PrinterService {
  @override
  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    return [];
  }

  @override
  Future<bool> connect(String macAddress) async {
    return false;
  }

  @override
  Future<bool> disconnect() async {
    return true;
  }

  @override
  Future<bool> printReceipt({
    required String empresa,
    String? mercado,
    required String local,
    required double monto,
    required DateTime fecha,
    double? saldoPendiente,
    double? saldoAFavor,
    double? deudaAnterior,
    double? montoAbonadoDeuda,
    double? pagoHoy,
    double? abonoCuotaHoy,
    String? cobrador,
    required String numeroBoleta,
    required int anioCorrelativo,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? periodoSaldoAFavorStr,
    String? slogan,
    String? clave,
    String? codigoLocal,
    String? codigoCatastral,
  }) async {
    debugPrint(
      'StubPrinterAdapter: Emulando impresión de ${empresa.toUpperCase()}',
    );

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          final fCurrency = NumberFormat.currency(
            symbol: 'L ',
            decimalDigits: 2,
          );
          final fDate = DateFormat('dd/MM/yyyy HH:mm');

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                empresa.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (mercado != null)
                pw.Text(
                  mercado.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              pw.Text(
                'BOLETA DE PAGO',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'No. $numeroBoleta',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              _pdfRow('LOCAL:', local.toUpperCase()),
              if (clave != null && clave.isNotEmpty)
                _pdfRow('CLAVE CATASTRAL:', clave),
              if (codigoLocal != null && codigoLocal.isNotEmpty)
                _pdfRow('NUM PUESTO:', codigoLocal),
              if (codigoCatastral != null && codigoCatastral.isNotEmpty)
                _pdfRow('CÓD. CATASTRAL:', codigoCatastral),
              _pdfRow('FECHA:', fDate.format(fecha)),
              if (cobrador != null)
                _pdfRow('COBRADOR:', cobrador.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
              pw.Text(
                'MONTO PAGADO:',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                fCurrency.format(monto),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
              if (deudaAnterior != null && deudaAnterior > 0) ...[
                _pdfRow('DEUDA ANTERIOR:', fCurrency.format(deudaAnterior)),
                _pdfRow('ABONO:', fCurrency.format(montoAbonadoDeuda ?? 0)),
                _pdfRow('DEUDA ACTUAL:', fCurrency.format(saldoPendiente ?? 0)),
              ] else if (saldoPendiente != null && saldoPendiente > 0)
                _pdfRow('DEUDA ACTUAL:', fCurrency.format(saldoPendiente)),

              if (pagoHoy != null)
                _pdfRow('CUOTA DEL DÍA:', fCurrency.format(pagoHoy)),

              if (abonoCuotaHoy != null)
                _pdfRow('ABONO CUOTA HOY:', fCurrency.format(abonoCuotaHoy)),

              if (periodoAbonadoStr != null &&
                  periodoAbonadoStr.isNotEmpty &&
                  periodoAbonadoStr != '-') ...[
                _pdfRow('PERIODO ABONADO:', periodoAbonadoStr),
              ] else if (fechasSaldadas != null &&
                  fechasSaldadas.length > 1) ...[
                if (DateRangeFormatter.formatearRangos(fechasSaldadas) != null)
                  _pdfRow(
                    'PERIODO ABONADO:',
                    DateRangeFormatter.formatearRangos(fechasSaldadas)!,
                  ),
              ],

              if (saldoAFavor != null && saldoAFavor > 0)
                _pdfRow('SALDO A FAVOR:', fCurrency.format(saldoAFavor)),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 12),
              pw.Text(
                slogan ?? '¡Gracias por su pago!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                fDate.format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    if (kIsWeb) {
      await descargarPdfWeb(bytes, 'Ticket_$numeroBoleta.pdf');
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Ticket_$numeroBoleta.pdf',
      );
    }

    return true;
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Flexible(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

PrinterService getPlatformPrinterAdapter() => StubPrinterAdapter();
