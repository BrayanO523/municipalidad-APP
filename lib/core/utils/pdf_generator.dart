import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/cortes/domain/entities/corte.dart';
import '../../features/cobros/domain/entities/cobro.dart';

class PdfGenerator {
  static Future<Uint8List> generateCortePdf(
    Corte corte, 
    List<Cobro> cobros, {
    Map<String, String>? localNames,
  }) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Reporte de Corte de Caja', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Oficial', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cobrador: ${corte.cobradorNombre}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Fecha: ${formatter.format(corte.fechaCorte)}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Cobrado: L. ${corte.totalCobrado.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text('Registros: ${corte.cantidadRegistros}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Text('Desglose de Cobros', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('No. Boleta', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Local', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Estado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...cobros.map((cobro) {
                  final String localDisplay = localNames?[cobro.localId] ?? 'Sin Nombre';
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cobro.numeroBoleta ?? '-')),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(localDisplay)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('L. ${(cobro.monto ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cobro.estado?.toUpperCase() ?? '-')),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.SizedBox(width: 200, child: pw.Divider()),
                  pw.Text('Firma del Recaudador', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 40),
                  pw.SizedBox(width: 200, child: pw.Divider()),
                  pw.Text('Firma Autorizada (Admin)', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printCorte(Corte corte, List<Cobro> cobros, {Map<String, String>? localNames}) async {
    final pdfBytes = await generateCortePdf(corte, cobros, localNames: localNames);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Corte_${DateFormat('yyyyMMdd').format(corte.fechaCorte)}',
    );
  }
}
