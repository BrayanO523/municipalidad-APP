import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/locales/domain/entities/local.dart';
import '../../app/di/providers.dart';
import 'date_formatter.dart';
import 'date_range_formatter.dart';

class ReceiptDispatcher {
  static Future<void> presentReceiptOptions({
    required BuildContext context,
    required WidgetRef ref,
    required Local local,
    required double monto,
    required DateTime fecha,
    required double saldoPendiente,
    required double deudaAnterior,
    required double montoAbonadoDeuda,
    required double saldoAFavor,
    required String numeroBoleta,
    required String? municipalidadNombre,
    required String? mercadoNombre,
    required String? cobradorNombre,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? periodoSaldoAFavorStr,
    String? slogan,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1B27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Comprobante de Pago', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              local.nombreSocial ?? 'Local Desconocido',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _infoRow('Monto:', DateFormatter.formatCurrency(monto), isBold: true),
            if (local.clave != null && local.clave!.isNotEmpty)
              _infoRow('Clave:', local.clave!),
            if (montoAbonadoDeuda > 0)
              _infoRow('Abono Deuda:', DateFormatter.formatCurrency(montoAbonadoDeuda), color: Colors.orangeAccent),
            if (fechasSaldadas != null && fechasSaldadas.length > 1) ...[
              if (DateRangeFormatter.formatearRangos(fechasSaldadas) != null)
                _infoRow(
                  'Periodo abonado:',
                  periodoAbonadoStr ?? DateRangeFormatter.formatearRangos(fechasSaldadas)!,
                  color: Colors.orangeAccent.withValues(alpha: 0.9),
                ),
            ],
            if (saldoAFavor > 0)
              _infoRow('Nuevo Saldo:', DateFormatter.formatCurrency(saldoAFavor), color: const Color(0xFF00D9A6)),
            if (periodoSaldoAFavorStr != null && periodoSaldoAFavorStr.isNotEmpty)
              _infoRow('Periodo a favor:', periodoSaldoAFavorStr, color: const Color(0xFF00D9A6).withValues(alpha: 0.9)),
            const SizedBox(height: 16),
            const Text(
              '¿Cómo desea entregar el comprobante?',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _imprimirTicket(
                      ref: ref,
                      muni: municipalidadNombre ?? 'MUNICIPALIDAD',
                      merc: mercadoNombre,
                      localName: local.nombreSocial ?? 'Local',
                      monto: monto,
                      fecha: fecha,
                      saldoP: saldoPendiente,
                      favor: saldoAFavor,
                      deudaAnt: deudaAnterior,
                      abono: montoAbonadoDeuda,
                      cobrador: cobradorNombre,
                      boleta: numeroBoleta,
                      fechasSaldadas: fechasSaldadas,
                      periodoAbonadoStr: periodoAbonadoStr,
                      periodoSaldoAFavorStr: periodoSaldoAFavorStr,
                      slogan: slogan,
                      clave: local.clave,
                    );
                    if (context.mounted) {
                      await compartirPdf(
                        context: context,
                        local: local,
                        monto: monto,
                        fecha: fecha,
                        saldoPendiente: saldoPendiente,
                        deudaAnterior: deudaAnterior,
                        montoAbonadoDeuda: montoAbonadoDeuda,
                        saldoAFavor: saldoAFavor,
                        numeroBoleta: numeroBoleta,
                        muni: municipalidadNombre,
                        merc: mercadoNombre,
                        cobrador: cobradorNombre,
                        fechasSaldadas: fechasSaldadas,
                        periodoAbonadoStr: periodoAbonadoStr,
                        periodoSaldoAFavorStr: periodoSaldoAFavorStr,
                        slogan: slogan,
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AMBOS (Imprimir + PDF)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _imprimirTicket(
                      ref: ref,
                      muni: municipalidadNombre ?? 'MUNICIPALIDAD',
                      merc: mercadoNombre,
                      localName: local.nombreSocial ?? 'Local',
                      monto: monto,
                      fecha: fecha,
                      saldoP: saldoPendiente,
                      favor: saldoAFavor,
                      deudaAnt: deudaAnterior,
                      abono: montoAbonadoDeuda,
                      cobrador: cobradorNombre,
                      boleta: numeroBoleta,
                      fechasSaldadas: fechasSaldadas,
                      periodoAbonadoStr: periodoAbonadoStr,
                      periodoSaldoAFavorStr: periodoSaldoAFavorStr,
                      slogan: slogan,
                      clave: local.clave,
                    );
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Imprimir Ticket (Térmica)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await compartirPdf(
                      context: context,
                      local: local,
                      monto: monto,
                      fecha: fecha,
                      saldoPendiente: saldoPendiente,
                      deudaAnterior: deudaAnterior,
                      montoAbonadoDeuda: montoAbonadoDeuda,
                      saldoAFavor: saldoAFavor,
                      numeroBoleta: numeroBoleta,
                      muni: municipalidadNombre,
                      merc: mercadoNombre,
                      cobrador: cobradorNombre,
                      fechasSaldadas: fechasSaldadas,
                      periodoAbonadoStr: periodoAbonadoStr,
                      periodoSaldoAFavorStr: periodoSaldoAFavorStr,
                      slogan: slogan,
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Compartir PDF (Digital)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Solo Cerrar (No entregar)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _imprimirTicket({
    required WidgetRef ref,
    required String muni,
    String? merc,
    required String localName,
    required double monto,
    required DateTime fecha,
    required double saldoP,
    required double favor,
    required double deudaAnt,
    required double abono,
    required String? cobrador,
    required String boleta,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? periodoSaldoAFavorStr,
    String? slogan,
    String? clave,
  }) async {
    try {
      final printer = ref.read(printerServiceProvider);
      await printer.printReceipt(
        empresa: muni,
        mercado: merc,
        local: localName,
        monto: monto,
        fecha: fecha,
        saldoPendiente: saldoP > 0 ? saldoP : 0.0,
        saldoAFavor: favor > 0 ? favor : 0.0,
        deudaAnterior: deudaAnt,
        montoAbonadoDeuda: abono,
        cobrador: cobrador,
        numeroBoleta: boleta,
        anioCorrelativo: fecha.year,
        fechasSaldadas: fechasSaldadas,
        periodoAbonadoStr: periodoAbonadoStr,
        periodoSaldoAFavorStr: periodoSaldoAFavorStr,
        slogan: slogan,
        clave: clave,
      );
    } catch (_) {}
  }

  static Future<void> compartirPdf({
    required BuildContext context,
    required Local local,
    required double monto,
    required DateTime fecha,
    required double saldoPendiente,
    required double deudaAnterior,
    required double montoAbonadoDeuda,
    required double saldoAFavor,
    required String numeroBoleta,
    required String? muni,
    required String? merc,
    required String? cobrador,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? periodoSaldoAFavorStr,
    String? slogan,
  }) async {
    String? diasCubiertosStr;
    if (fechasSaldadas != null && fechasSaldadas.isNotEmpty) {
      diasCubiertosStr = DateRangeFormatter.formatearRangos(fechasSaldadas);
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text((muni ?? 'MUNICIPALIDAD').toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              if (merc != null) ...[
                pw.Text(merc.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),
              ],
              pw.SizedBox(height: 4),
              pw.Text('BOLETA DE PAGO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('No. $numeroBoleta', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              _pdfRow('LOCAL:', local.nombreSocial?.toUpperCase() ?? 'LOCAL'),
              if (local.clave != null && local.clave!.isNotEmpty)
                _pdfRow('CLAVE:', local.clave!),
              _pdfRow('FECHA:', DateFormatter.formatDateTime(fecha)),
              if (cobrador != null) _pdfRow('COBRADOR:', cobrador.toUpperCase()),
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              
              pw.Text('MONTO PAGADO:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.Text('L ${monto.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              if (deudaAnterior > 0) ...[
                _pdfRow('DEUDA ANTE.:', DateFormatter.formatCurrency(deudaAnterior)),
                _pdfRow('ABONO:', DateFormatter.formatCurrency(montoAbonadoDeuda)),
                _pdfRow('DEUDA ACT.:', DateFormatter.formatCurrency(saldoPendiente)),
              ] else if (saldoPendiente > 0) ...[
                _pdfRow('DEUDA ACTUAL:', DateFormatter.formatCurrency(saldoPendiente)),
              ],

              if (periodoAbonadoStr != null && periodoAbonadoStr.isNotEmpty && periodoAbonadoStr != '-')
                _pdfRow('PERIODO ABONADO:', periodoAbonadoStr)
              else if (diasCubiertosStr != null)
                _pdfRow('PERIODO ABONADO:', diasCubiertosStr),
              
              if (saldoAFavor > 0) ...[
                _pdfRow('SALDO FAVOR:', DateFormatter.formatCurrency(saldoAFavor)),
                if (periodoSaldoAFavorStr != null && periodoSaldoAFavorStr.isNotEmpty)
                  _pdfRow('PERIODO A FAVOR:', periodoSaldoAFavorStr),
              ],
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
              
              pw.Text('¡Gracias por su pago!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              if (slogan != null && slogan.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(slogan, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center),
              ],
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Boleta_Municipalidad_$numeroBoleta.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir PDF: $e')));
      }
    }
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Flexible(child: pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }
}
