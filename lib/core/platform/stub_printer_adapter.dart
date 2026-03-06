import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'printer_service.dart';

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
    String? cobrador,
    int? correlativo,
    int? anioCorrelativo,
  }) async {
    final doc = pw.Document();
    final fCurrency = NumberFormat.currency(symbol: 'L ', decimalDigits: 2);
    final fDate = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
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
              if (correlativo != null)
                pw.Text(
                  'No. ${anioCorrelativo ?? DateTime.now().year}-${correlativo.toString().padLeft(5, '0')}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              _pdfRow('LOCAL:', local.toUpperCase()),
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
              ),
              pw.Text(
                fCurrency.format(monto),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
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
              if (saldoAFavor != null && saldoAFavor > 0)
                _pdfRow('SALDO A FAVOR:', fCurrency.format(saldoAFavor)),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 12),
              pw.Text(
                '¡Gracias por su pago!',
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
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Ticket_${correlativo ?? 'reimpresion'}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Ticket_${correlativo ?? 'reimpresion'}.pdf',
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

PrinterService getPrinterAdapter() => StubPrinterAdapter();
