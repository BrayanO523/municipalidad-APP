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

    // 1. Separar cobrados (los que tienen recibo real)
    final cobrados = cobros
        .where((c) => c.estado == 'cobrado' || c.estado == 'cobrado_saldo')
        .toList();
    
    // 2. Pendientes vienen del arreglo del corte, no de los cobros
    final pendientesInfo = corte.pendientesInfo ?? [];

    // 3. Calcular subtotales
    final totalCobrado = cobrados.fold<double>(
        0, (sum, c) => sum + (c.monto ?? 0).toDouble());
    final totalPendiente = pendientesInfo.fold<double>(
        0, (sum, i) => sum + ((i['montoPendiente'] as num?)?.toDouble() ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ── Cabecera Principal ──
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Reporte de Corte Diario',
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Documento Oficial',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Resumen ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cobrador: ${corte.cobradorNombre}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.SizedBox(height: 4),
                    pw.Text('Fecha de impresión: ${formatter.format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Fecha de corte: ${formatter.format(corte.fechaCorte)}',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 8),
                    pw.Text('Total de Locales en Ruta: ${corte.cantidadRegistros}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Cobrados: ${corte.cantidadCobrados ?? cobrados.length} | Pendientes: ${corte.cantidadPendientes ?? pendientesInfo.length}',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'Recaudado: L. ${totalCobrado.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Pendiente: L. ${totalPendiente.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 16),

            // ── Tabla Cobrados ──
            if (cobrados.isNotEmpty) ...[
              pw.Text('Detalle de Recibos Cobrados',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900)),
              pw.SizedBox(height: 8),
              _buildTable(cobrados, localNames, PdfColors.green50),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                    'Subtotal Cobrado: L. ${totalCobrado.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ),
              pw.SizedBox(height: 24),
            ],

            // ── Tabla Pendientes (desde pendientesInfo) ──
            if (pendientesInfo.isNotEmpty) ...[
              pw.Text('Detalle de Locales Pendientes',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange900)),
              pw.SizedBox(height: 8),
              _buildPendientesTable(pendientesInfo, PdfColors.orange50),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                    'Subtotal Pendiente: L. ${totalPendiente.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ),
              pw.SizedBox(height: 24),
            ],

            // ── Zona de Firmas ──
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(
                        width: 160,
                        child: pw.Divider(color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    pw.Text('Firma del Recaudador',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(
                        width: 160,
                        child: pw.Divider(color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    pw.Text('Firma Autorizada (Admin)',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTable(
      List<Cobro> cobros, Map<String, String>? localNames, PdfColor headerColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2), // No. Boleta
        1: pw.FlexColumnWidth(3), // Local
        2: pw.FlexColumnWidth(1.5), // Monto
        3: pw.FlexColumnWidth(1.5), // Estado
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('No. Boleta',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Local',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Monto',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Estado',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.center)),
          ],
        ),
        ...cobros.map((cobro) {
          final String localDisplay = localNames?[cobro.localId] ?? 'Sin Nombre';
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(cobro.numeroBoletaFmt,
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(localDisplay,
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('L. ${(cobro.monto ?? 0).toStringAsFixed(2)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(cobro.estado?.toUpperCase() ?? '-',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildPendientesTable(
      List<Map<String, dynamic>> pendientesInfo, PdfColor headerColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4), // Local
        1: pw.FlexColumnWidth(2), // Monto Pendiente
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Local',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('Cuota Pendiente',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
        ...pendientesInfo.map((info) {
          final nombre = info['nombreSocial'] as String? ?? 'S/N';
          final monto =
              (info['montoPendiente'] as num?)?.toDouble() ?? 0;
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(nombre,
                      style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('L. ${monto.toStringAsFixed(2)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold))),
            ],
          );
        }),
      ],
    );
  }

  static Future<void> printCorte(Corte corte, List<Cobro> cobros, {Map<String, String>? localNames}) async {
    final pdfBytes = await generateCortePdf(corte, cobros, localNames: localNames);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Corte_${DateFormat('yyyyMMdd').format(corte.fechaCorte)}',
    );
  }
}
