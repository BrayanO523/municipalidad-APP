import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/locales/domain/entities/local.dart';
import '../../features/cobros/domain/entities/cobro.dart';
import '../../app/di/providers.dart';
import 'date_formatter.dart';
import 'date_range_formatter.dart';

class _ReceiptCobroSnapshot {
  final double saldoPendiente;
  final double deudaAnterior;
  final double montoAbonadoDeuda;
  final double? pagoHoy;
  final double? abonoCuotaHoy;
  final double saldoAFavor;
  final List<DateTime> fechasCubiertas;
  final String? periodoAbonadoStr;
  final String? periodoSaldoAFavorStr;

  const _ReceiptCobroSnapshot({
    required this.saldoPendiente,
    required this.deudaAnterior,
    required this.montoAbonadoDeuda,
    required this.pagoHoy,
    required this.abonoCuotaHoy,
    required this.saldoAFavor,
    required this.fechasCubiertas,
    required this.periodoAbonadoStr,
    required this.periodoSaldoAFavorStr,
  });

  factory _ReceiptCobroSnapshot.fromCobro(Cobro cobro) {
    final cuotaDiaria = (cobro.cuotaDiaria ?? 0).toDouble();
    final deudaAnterior = (cobro.deudaAnterior ?? 0).toDouble();
    final fechasDeuda = List<DateTime>.from(cobro.fechasDeudasSaldadas ?? []);
    final pagoCuotaRaw = (cobro.pagoACuota ?? 0).toDouble();

    double montoAbonadoDeuda = (cobro.montoAbonadoDeuda ?? 0).toDouble();
    if (montoAbonadoDeuda <= 0 && fechasDeuda.isNotEmpty && deudaAnterior > 0) {
      final montoCobro = (cobro.monto ?? 0).toDouble();
      montoAbonadoDeuda = montoCobro.clamp(0.0, deudaAnterior);
    }

    final saldoRecalculado = (deudaAnterior - montoAbonadoDeuda).clamp(
      0.0,
      double.infinity,
    );
    double saldoPendiente = (cobro.saldoPendiente ?? 0).toDouble();
    if (saldoPendiente <= 0 || saldoPendiente > saldoRecalculado) {
      saldoPendiente = saldoRecalculado;
    }

    final abonoCuotaHoy = pagoCuotaRaw > 0 ? pagoCuotaRaw : null;
    double? pagoHoy;
    if (abonoCuotaHoy != null && cuotaDiaria > 0) {
      pagoHoy = (cuotaDiaria - abonoCuotaHoy).clamp(0.0, cuotaDiaria);
    }

    final fechasCubiertas = <DateTime>[
      ...fechasDeuda.map((d) => DateTime(d.year, d.month, d.day)),
    ];
    final fechaCobro = cobro.fecha;
    if (abonoCuotaHoy != null && fechaCobro != null) {
      final fechaHoy = DateTime(
        fechaCobro.year,
        fechaCobro.month,
        fechaCobro.day,
      );
      final yaIncluida = fechasCubiertas.any(
        (d) =>
            d.year == fechaHoy.year &&
            d.month == fechaHoy.month &&
            d.day == fechaHoy.day,
      );
      if (!yaIncluida) {
        fechasCubiertas.add(fechaHoy);
      }
    }
    fechasCubiertas.sort((a, b) => a.compareTo(b));

    final periodoAbonadoStr = fechasCubiertas.isEmpty
        ? null
        : DateRangeFormatter.formatearRangos(fechasCubiertas);

    final saldoAFavor = (cobro.nuevoSaldoFavor ?? 0).toDouble();
    String? periodoSaldoAFavorStr;
    if (saldoAFavor > 0 && cuotaDiaria > 0) {
      final dias = (saldoAFavor / cuotaDiaria).floor();
      if (dias > 0) {
        DateTime inicioFavor;
        if (fechasCubiertas.isNotEmpty) {
          inicioFavor = fechasCubiertas.last.add(const Duration(days: 1));
        } else {
          final base = fechaCobro ?? DateTime.now();
          inicioFavor = DateTime(
            base.year,
            base.month,
            base.day,
          ).add(const Duration(days: 1));
        }
        periodoSaldoAFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
          inicioFavor,
          dias,
        );
      }
    }

    return _ReceiptCobroSnapshot(
      saldoPendiente: saldoPendiente,
      deudaAnterior: deudaAnterior,
      montoAbonadoDeuda: montoAbonadoDeuda,
      pagoHoy: pagoHoy,
      abonoCuotaHoy: abonoCuotaHoy,
      saldoAFavor: saldoAFavor,
      fechasCubiertas: fechasCubiertas,
      periodoAbonadoStr: periodoAbonadoStr,
      periodoSaldoAFavorStr: periodoSaldoAFavorStr,
    );
  }
}

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
    double? pagoHoy,
    double? abonoCuotaHoy,
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
    if (!context.mounted) return;
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Título
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Comprobante de Pago',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info del pago
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    local.nombreSocial ?? 'Local Desconocido',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  'Monto:',
                  DateFormatter.formatCurrency(monto),
                  isBold: true,
                  textColor: cs.onSurface,
                ),
                if (local.clave != null && local.clave!.isNotEmpty)
                  _infoRow(
                    'Clave Catastral:',
                    local.clave!,
                    textColor: cs.onSurface,
                  ),
                if (local.codigo != null && local.codigo!.isNotEmpty)
                  _infoRow(
                    'Num Puesto:',
                    local.codigo!,
                    textColor: cs.onSurface,
                  ),
                if (local.codigoCatastral != null &&
                    local.codigoCatastral!.isNotEmpty)
                  _infoRow(
                    'Cód. Catastral:',
                    local.codigoCatastral!,
                    textColor: cs.onSurface,
                  ),
                if (deudaAnterior > 0)
                  _infoRow(
                    'Deuda anterior:',
                    DateFormatter.formatCurrency(deudaAnterior),
                    color: Colors.redAccent,
                    textColor: cs.onSurface,
                  ),
                if (montoAbonadoDeuda > 0)
                  _infoRow(
                    'Abono a deuda:',
                    DateFormatter.formatCurrency(montoAbonadoDeuda),
                    color: Colors.orangeAccent,
                    textColor: cs.onSurface,
                  ),
                if (saldoPendiente > 0)
                  _infoRow(
                    'Deuda actual:',
                    DateFormatter.formatCurrency(saldoPendiente),
                    color: Colors.redAccent,
                    textColor: cs.onSurface,
                  ),
                if (pagoHoy != null)
                  _infoRow(
                    'Cuota del día:',
                    DateFormatter.formatCurrency(pagoHoy),
                    color: const Color(0xFF00D9A6),
                    textColor: cs.onSurface,
                  ),
                if (abonoCuotaHoy != null)
                  _infoRow(
                    'Abono cuota hoy:',
                    DateFormatter.formatCurrency(abonoCuotaHoy),
                    color: const Color(0xFF00D9A6),
                    textColor: cs.onSurface,
                  ),
                if (periodoAbonadoStr != null &&
                    periodoAbonadoStr.isNotEmpty &&
                    periodoAbonadoStr != '-')
                  _infoRow(
                    'Fechas cubiertas:',
                    periodoAbonadoStr,
                    color: Colors.orangeAccent.withValues(alpha: 0.9),
                    textColor: cs.onSurface,
                  )
                else if (fechasSaldadas != null &&
                    fechasSaldadas.length > 1) ...[
                  if (DateRangeFormatter.formatearRangos(fechasSaldadas) !=
                      null)
                    _infoRow(
                      'Fechas cubiertas:',
                      DateRangeFormatter.formatearRangos(fechasSaldadas)!,
                      color: Colors.orangeAccent.withValues(alpha: 0.9),
                      textColor: cs.onSurface,
                    ),
                ],
                if (saldoAFavor > 0)
                  _infoRow(
                    'Saldo a favor:',
                    DateFormatter.formatCurrency(saldoAFavor),
                    color: const Color(0xFF00D9A6),
                    textColor: cs.onSurface,
                  ),
                if (periodoSaldoAFavorStr != null &&
                    periodoSaldoAFavorStr.isNotEmpty)
                  _infoRow(
                    'Fechas adelantadas:',
                    periodoSaldoAFavorStr,
                    color: const Color(0xFF00D9A6).withValues(alpha: 0.9),
                    textColor: cs.onSurface,
                  ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo desea entregar el comprobante?',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                // Botones de acción
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
                        pagoHoy: pagoHoy,
                        cobrador: cobradorNombre,
                        boleta: numeroBoleta,
                        fechasSaldadas: fechasSaldadas,
                        periodoAbonadoStr: periodoAbonadoStr,
                        periodoSaldoAFavorStr: periodoSaldoAFavorStr,
                        slogan: slogan,
                        clave: local.clave,
                        codigoLocal: local.codigo,
                        codigoCatastral: local.codigoCatastral,
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
                          pagoHoy: pagoHoy,
                          abonoCuotaHoy: abonoCuotaHoy,
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
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
                        pagoHoy: pagoHoy,
                        cobrador: cobradorNombre,
                        boleta: numeroBoleta,
                        fechasSaldadas: fechasSaldadas,
                        periodoAbonadoStr: periodoAbonadoStr,
                        periodoSaldoAFavorStr: periodoSaldoAFavorStr,
                        slogan: slogan,
                        clave: local.clave,
                        codigoLocal: local.codigo,
                        codigoCatastral: local.codigoCatastral,
                      );
                    },
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Imprimir Ticket (Térmica)'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
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
                        pagoHoy: pagoHoy,
                        abonoCuotaHoy: abonoCuotaHoy,
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
                    style: FilledButton.styleFrom(
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _infoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor?.withValues(alpha: 0.7) ?? Colors.white70,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color ?? textColor ?? Colors.white,
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
    double? pagoHoy,
    double? abonoCuotaHoy,
    required String? cobrador,
    required String boleta,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? periodoSaldoAFavorStr,
    String? slogan,
    String? clave,
    String? codigoLocal,
    String? codigoCatastral,
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
        pagoHoy: pagoHoy,
        abonoCuotaHoy: abonoCuotaHoy,
        cobrador: cobrador,
        numeroBoleta: boleta,
        anioCorrelativo: fecha.year,
        fechasSaldadas: fechasSaldadas,
        periodoAbonadoStr: periodoAbonadoStr,
        periodoSaldoAFavorStr: periodoSaldoAFavorStr,
        slogan: slogan,
        clave: clave,
        codigoLocal: codigoLocal,
        codigoCatastral: codigoCatastral,
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
    double? pagoHoy,
    double? abonoCuotaHoy,
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

    final fontDefault = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(
          base: fontDefault,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                (muni ?? 'MUNICIPALIDAD').toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              if (merc != null) ...[
                pw.Text(
                  merc.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
              ],
              pw.SizedBox(height: 4),
              pw.Text(
                'BOLETA DE PAGO',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
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

              _pdfRow('LOCAL:', local.nombreSocial?.toUpperCase() ?? 'LOCAL'),
              if (local.clave != null && local.clave!.isNotEmpty)
                _pdfRow('CLAVE CATASTRAL:', local.clave!),
              if (local.codigo != null && local.codigo!.isNotEmpty)
                _pdfRow('NUM PUESTO:', local.codigo!),
              if (local.codigoCatastral != null &&
                  local.codigoCatastral!.isNotEmpty)
                _pdfRow('CÓD. CATASTRAL:', local.codigoCatastral!),
              _pdfRow('FECHA:', DateFormatter.formatDateTime(fecha)),
              if (cobrador != null)
                _pdfRow('COBRADOR:', cobrador.toUpperCase()),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              pw.Text(
                'MONTO PAGADO:',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'L ${monto.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              if (deudaAnterior > 0) ...[
                _pdfRow(
                  'DEUDA ANTERIOR:',
                  DateFormatter.formatCurrency(deudaAnterior),
                ),
                _pdfRow(
                  'ABONO A DEUDA:',
                  DateFormatter.formatCurrency(montoAbonadoDeuda),
                ),
                _pdfRow(
                  'DEUDA ACTUAL:',
                  DateFormatter.formatCurrency(saldoPendiente),
                ),
              ] else if (saldoPendiente > 0) ...[
                _pdfRow(
                  'DEUDA ACTUAL:',
                  DateFormatter.formatCurrency(saldoPendiente),
                ),
              ],

              if (pagoHoy != null) ...[
                _pdfRow(
                  'CUOTA DEL DÍA:',
                  DateFormatter.formatCurrency(pagoHoy),
                ),
              ],
              if (abonoCuotaHoy != null) ...[
                _pdfRow(
                  'ABONO CUOTA HOY:',
                  DateFormatter.formatCurrency(abonoCuotaHoy),
                ),
              ],

              if (periodoAbonadoStr != null &&
                  periodoAbonadoStr.isNotEmpty &&
                  periodoAbonadoStr != '-')
                _pdfRow('FECHAS CUBIERTAS:', periodoAbonadoStr)
              else if (diasCubiertosStr != null)
                _pdfRow('FECHAS CUBIERTAS:', diasCubiertosStr),

              if (saldoAFavor > 0) ...[
                _pdfRow(
                  'SALDO A FAVOR:',
                  DateFormatter.formatCurrency(saldoAFavor),
                ),
                if (periodoSaldoAFavorStr != null &&
                    periodoSaldoAFavorStr.isNotEmpty)
                  _pdfRow('FECHAS ADELANTADAS:', periodoSaldoAFavorStr),
              ],

              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              pw.Text(
                '¡Gracias por su pago!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (slogan != null && slogan.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  slogan.trim(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al compartir PDF: $e')));
      }
    }
  }

  static Future<void> imprimirDesdeCobro({
    required BuildContext context,
    required WidgetRef ref,
    required Cobro cobro,
    Local? local,
    String? municipalidadNombre,
    String? mercadoNombre,
    String? cobradorNombre,
    String? slogan,
  }) async {
    // Si no se pasan los datos maestros, tratamos de obtenerlos de los providers
    final localDoc =
        local ??
        ref
            .read(localesProvider)
            .value
            ?.where((l) => l.id == cobro.localId)
            .firstOrNull;

    final muni =
        municipalidadNombre ??
        ref.read(municipalidadActualProvider)?.nombre ??
        'MUNICIPALIDAD';

    final merc =
        mercadoNombre ??
        ref
            .read(mercadosProvider)
            .value
            ?.where((m) => m.id == cobro.mercadoId)
            .map((m) => m.nombre)
            .firstOrNull;

    final cobrador =
        cobradorNombre ??
        ref
            .read(usuariosProvider)
            .value
            ?.where((u) => u.id == cobro.cobradorId)
            .map((u) => u.nombre)
            .firstOrNull;

    final sloganMuni = slogan ?? ref.read(municipalidadActualProvider)?.slogan;
    final snapshot = _ReceiptCobroSnapshot.fromCobro(cobro);
    // 1. Imprimir Ticket (Térmica)
    await _imprimirTicket(
      ref: ref,
      muni: muni,
      merc: merc,
      localName: localDoc?.nombreSocial ?? 'Local',
      monto: (cobro.monto ?? 0).toDouble(),
      fecha: cobro.fecha ?? DateTime.now(),
      saldoP: snapshot.saldoPendiente,
      favor: snapshot.saldoAFavor,
      deudaAnt: snapshot.deudaAnterior,
      abono: snapshot.montoAbonadoDeuda,
      pagoHoy: snapshot.pagoHoy,
      abonoCuotaHoy: snapshot.abonoCuotaHoy,
      cobrador: cobrador,
      boleta: cobro.numeroBoletaFmt,
      fechasSaldadas: snapshot.fechasCubiertas,
      periodoAbonadoStr: snapshot.periodoAbonadoStr,
      periodoSaldoAFavorStr: snapshot.periodoSaldoAFavorStr,
      slogan: sloganMuni,
      clave: localDoc?.clave,
      codigoLocal: localDoc?.codigo,
      codigoCatastral: localDoc?.codigoCatastral,
    );

    // 2. Compartir PDF (Digital)
    if (context.mounted) {
      await compartirPdf(
        context: context,
        local: localDoc ?? Local(id: cobro.localId ?? ''),
        monto: (cobro.monto ?? 0).toDouble(),
        fecha: cobro.fecha ?? DateTime.now(),
        saldoPendiente: snapshot.saldoPendiente,
        deudaAnterior: snapshot.deudaAnterior,
        montoAbonadoDeuda: snapshot.montoAbonadoDeuda,
        pagoHoy: snapshot.pagoHoy,
        abonoCuotaHoy: snapshot.abonoCuotaHoy,
        saldoAFavor: snapshot.saldoAFavor,
        numeroBoleta: cobro.numeroBoletaFmt,
        muni: muni,
        merc: merc,
        cobrador: cobrador,
        fechasSaldadas: snapshot.fechasCubiertas,
        periodoAbonadoStr: snapshot.periodoAbonadoStr,
        periodoSaldoAFavorStr: snapshot.periodoSaldoAFavorStr,
        slogan: sloganMuni,
      );
    }
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Flexible(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
