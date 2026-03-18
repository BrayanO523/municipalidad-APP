import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/cortes/domain/entities/corte.dart';
import '../../features/cobros/domain/entities/cobro.dart';

class PdfGenerator {
  static bool _esMovimientoCorte(Cobro cobro) {
    final estado = (cobro.estado ?? '').toLowerCase();
    return (cobro.monto ?? 0) > 0 ||
        (cobro.pagoACuota ?? 0) > 0 ||
        (cobro.montoAbonadoDeuda ?? 0) > 0 ||
        estado == 'cobrado_saldo';
  }

  static Future<Uint8List> generateCortePdf(
    Corte corte,
    List<Cobro> cobros, {
    Map<String, Map<String, String>>? localInfo,
  }) async {
    final fontRegular = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final DateFormat formatter = DateFormat('dd/MM/yyyy hh:mm a');

    final cobrados = cobros.where(_esMovimientoCorte).toList();

    // 2. Pendientes vienen del arreglo del corte, no de los cobros
    final pendientesInfo = corte.pendientesInfo ?? [];
    final gestionesInfo = corte.gestionesInfo ?? [];

    // 3. Calcular subtotales
    final totalCobrado = cobrados.fold<double>(
      0,
      (sum, c) => sum + (c.monto ?? 0).toDouble(),
    );
    final totalPendiente = pendientesInfo.fold<double>(
      0,
      (sum, i) => sum + ((i['montoPendiente'] as num?)?.toDouble() ?? 0),
    );
    // 4. Desglose mora / corriente
    final totalMoraCorte = (corte.totalMora ?? cobrados.fold<double>(0, (s, c) => s + (c.montoMora ?? 0).toDouble())).toDouble();
    final totalCorrienteCorte = (totalCobrado - totalMoraCorte).clamp(0.0, double.infinity);
    final tieneMora = totalMoraCorte > 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // â”€â”€ Cabecera Principal â”€â”€
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Reporte de Corte Diario',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Documento Oficial',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // â”€â”€ Resumen â”€â”€
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Cobrador: ${corte.cobradorNombre}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Fecha de impresión: ${formatter.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Fecha de corte: ${formatter.format(corte.fechaCorte)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Total de movimientos: ${corte.cantidadRegistros}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Cobrados: ${corte.cantidadCobrados ?? cobrados.length} | Pendientes: ${corte.cantidadPendientes ?? pendientesInfo.length}${gestionesInfo.isNotEmpty ? ' | Gestiones: ${gestionesInfo.length}' : ''}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Recaudado: ${CurrencyFormatter.format(totalCobrado)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    if (tieneMora) ...[
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFD1FAE5),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'Corriente: ${CurrencyFormatter.format(totalCorrienteCorte)}',
                              style: pw.TextStyle(fontSize: 8, color: PdfColors.green900, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFFFEDD5),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'Mora: ${CurrencyFormatter.format(totalMoraCorte)}',
                              style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFFC2410C), fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Pendiente: ${CurrencyFormatter.format(totalPendiente)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 16),

            // â”€â”€ Tabla Cobrados â”€â”€
            if (cobrados.isNotEmpty) ...[
              pw.Text(
                'Detalle de Cobros y Abonos',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildTable(cobrados, localInfo, PdfColors.green50),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Subtotal Cobrado: ${CurrencyFormatter.format(totalCobrado)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            if (gestionesInfo.isNotEmpty) ...[
              _buildIncidenciasTabla(gestionesInfo, localInfo),
              pw.SizedBox(height: 24),
            ],

            // â”€â”€ Tabla Pendientes (desde pendientesInfo) â”€â”€
            if (pendientesInfo.isNotEmpty) ...[
              pw.Text(
                'Detalle de Locales Pendientes',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange900,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPendientesTable(pendientesInfo, PdfColors.orange50),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Subtotal Pendiente: ${CurrencyFormatter.format(totalPendiente)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // â”€â”€ Zona de Firmas â”€â”€
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(
                      width: 160,
                      child: pw.Divider(color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Firma del Recaudador',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(
                      width: 160,
                      child: pw.Divider(color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Firma Autorizada (Admin)',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
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
    List<Cobro> cobros,
    Map<String, Map<String, String>>? localInfo,
    PdfColor headerColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3), // Local
        1: pw.FlexColumnWidth(2), // No. Boleta
        2: pw.FlexColumnWidth(1.5), // Monto
        3: pw.FlexColumnWidth(1.5), // Estado
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Local',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'No. Boleta',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Monto',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Estado',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
        ...cobros.map((cobro) {
          final info = localInfo?[cobro.localId];
          final String localDisplay = info?['nombre'] ?? 'Sin Nombre';
          final codigo = info?['codigo'];
          final clave = info?['clave'];
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      localDisplay,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                    if ((codigo != null && codigo.isNotEmpty) ||
                        (clave != null && clave.isNotEmpty))
                      pw.Text(
                        [
                          if (codigo != null && codigo.isNotEmpty) 'Cód: $codigo',
                          if (clave != null && clave.isNotEmpty) 'Clave: $clave',
                        ].join(' • '),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  cobro.numeroBoletaFmt,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  CurrencyFormatter.format((cobro.monto ?? 0).toDouble()),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  cobro.estado?.toUpperCase() ?? '-',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildIncidenciasTabla(
    List<Map<String, dynamic>> gestionesInfo,
    Map<String, Map<String, String>>? localInfo,
  ) {
    if (gestionesInfo.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Incidencias del día',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.brown900,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3), // Local
            1: pw.FlexColumnWidth(2.5), // Boleta
            2: pw.FlexColumnWidth(2.5), // Motivo
            3: pw.FlexColumnWidth(3), // Comentario
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown50),
              children: [
                _cellHeader('Local'),
                _cellHeader('Boleta'),
                _cellHeader('Motivo'),
                _cellHeader('Comentario'),
              ],
            ),
            ...gestionesInfo.map((g) {
              final localId = g['localId'] as String?;
              final info = (localId != null && localInfo != null)
                  ? localInfo[localId]
                  : null;
              final localNombre = info?['nombre'] ?? g['nombreSocial'] ?? 'S/N';
              final codigo = info?['codigo'] ?? g['codigo'] ?? '';
              final clave = info?['clave'] ?? g['clave'] ?? '';
              final boleta = g['boleta'] as String? ?? '';
              final tipo = g['tipoIncidencia'] as String? ?? 'OTRO';
              final comentario = g['comentario'] as String? ?? '';

              final detallesLocal = [
                if (codigo.isNotEmpty) 'Cód: $codigo',
                if (clave.isNotEmpty) 'Clave: $clave',
              ].join(' \u2022 ');

              return pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  _cellBody(
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(localNombre, style: const pw.TextStyle(fontSize: 9)),
                        if (detallesLocal.isNotEmpty)
                          pw.Text(
                            detallesLocal,
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                      ],
                    ),
                  ),
                  _cellBody(pw.Text(boleta.isNotEmpty ? boleta : '-', style: const pw.TextStyle(fontSize: 9))),
                  _cellBody(pw.Text(_labelTipoIncidencia(tipo), style: const pw.TextStyle(fontSize: 9))),
                  _cellBody(pw.Text(
                    comentario.isNotEmpty ? comentario : '-',
                    style: const pw.TextStyle(fontSize: 9),
                  )),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cellHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      );

  static pw.Widget _cellBody(pw.Widget child) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: child);

  static pw.Widget _buildPendientesTable(
    List<Map<String, dynamic>> pendientesInfo,
    PdfColor headerColor,
  ) {
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
              child: pw.Text(
                'Local',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Cuota Pendiente',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        ...pendientesInfo.map((info) {
          final nombre = info['nombreSocial'] as String? ?? 'S/N';
          final clave = info['clave'] as String? ?? '';
          final codigo = info['codigo'] as String? ?? '';
          final monto = (info['montoPendiente'] as num?)?.toDouble() ?? 0;
          final saldoAFavor = (info['saldoAFavor'] as num?)?.toDouble() ?? 0;
          final tieneSaldoAFavor = info['tieneSaldoAFavor'] == true;
          final saldoCubreCuota = info['saldoCubreCuota'] == true;

          final detallesLocal = [
            if (codigo.isNotEmpty) 'Cód: $codigo',
            if (clave.isNotEmpty) 'Clave Catastral: $clave',
            if (tieneSaldoAFavor)
              saldoCubreCuota
                  ? 'Tiene saldo a favor suficiente; falta registrar el cobro con saldo'
                  : 'Saldo a favor: L. ${saldoAFavor.toStringAsFixed(2)}',
          ].join(' \u2022 ');

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(nombre, style: const pw.TextStyle(fontSize: 9)),
                    if (detallesLocal.isNotEmpty)
                      pw.Text(
                        detallesLocal,
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  CurrencyFormatter.format(monto),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static String _labelTipoIncidencia(String tipo) {
    switch (tipo) {
      case 'CERRADO':
        return 'Local Cerrado';
      case 'AUSENTE':
        return 'Encargado Ausente';
      case 'SIN_EFECTIVO':
        return 'Sin Efectivo';
      case 'NEGADO':
        return 'Se niega a pagar';
      case 'VOLVER_TARDE':
        return 'Volver más tarde';
      default:
        return 'Otro motivo';
    }
  }

  static pw.Widget _buildGestionesTable(
    List<Map<String, dynamic>> gestionesInfo,
    PdfColor headerColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3), // Local
        1: pw.FlexColumnWidth(2.5), // Tipo
        2: pw.FlexColumnWidth(3), // Comentario
        3: pw.FlexColumnWidth(1.2), // Hora
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Local',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Tipo',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Comentario',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'Hora',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
        ...gestionesInfo.map((info) {
          final nombre = info['nombreSocial'] as String? ?? 'S/N';
          final clave = info['clave'] as String? ?? '';
          final codigo = info['codigo'] as String? ?? '';
          final tipo = info['tipoIncidencia'] as String? ?? 'OTRO';
          final comentario = info['comentario'] as String? ?? '';
          final tsRaw = info['timestamp'] as String? ?? '';
          String horaStr = '-';
          if (tsRaw.isNotEmpty) {
            try {
              final dt = DateTime.parse(tsRaw);
              horaStr =
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {}
          }

          final detallesLocal = [
            if (codigo.isNotEmpty) 'Cód: $codigo',
            if (clave.isNotEmpty) 'Clave Catastral: $clave',
          ].join(' \u2022 ');

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(nombre, style: const pw.TextStyle(fontSize: 9)),
                    if (detallesLocal.isNotEmpty)
                      pw.Text(
                        detallesLocal,
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  _labelTipoIncidencia(tipo),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  comentario.isNotEmpty ? comentario : '-',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  horaStr,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static Future<void> printCorte(
    Corte corte,
    List<Cobro> cobros, {
    Map<String, Map<String, String>>? localInfo,
  }) async {
    final pdfBytes = await generateCortePdf(
      corte,
      cobros,
      localInfo: localInfo,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Corte_${DateFormat('yyyyMMdd').format(corte.fechaCorte)}',
    );
  }

  static Future<Uint8List> generateCorteMercadoPdf(
    List<Corte> cortesCobradores,
    String mercadoNombre,
    DateTime fecha,
  ) async {
    final fontRegular = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final DateFormat formatter = DateFormat('dd/MM/yyyy hh:mm a');
    final DateFormat dateOnly = DateFormat('dd/MM/yyyy');

    // Calcular totales consolidados
    final totalConsolidado = cortesCobradores.fold<double>(
      0,
      (sum, c) => sum + c.totalCobrado,
    );
    final totalRegistros = cortesCobradores.fold<int>(
      0,
      (sum, c) => sum + c.cantidadRegistros,
    );
    final totalCobrados = cortesCobradores.fold<int>(
      0,
      (sum, c) => sum + (c.cantidadCobrados ?? 0),
    );
    final totalPendientes = cortesCobradores.fold<int>(
      0,
      (sum, c) => sum + (c.cantidadPendientes ?? 0),
    );
    final totalMoraConsolidado = cortesCobradores.fold<double>(
      0,
      (sum, c) => sum + (c.totalMora ?? 0).toDouble(),
    );
    final totalCorrienteConsolidado = (totalConsolidado - totalMoraConsolidado).clamp(0.0, double.infinity);
    final tieneMoraConsolidado = totalMoraConsolidado > 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ─── Cabecera Principal ───
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Corte Consolidado de Mercado',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Documento Oficial',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ─── Información del Mercado ───
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Mercado: $mercadoNombre',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Fecha: ${dateOnly.format(fecha)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Cobradores: ${cortesCobradores.length}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ─── Resumen Consolidado ───
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.green200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Registros: $totalRegistros',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Cobrados: $totalCobrados | Pendientes: $totalPendientes',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Recaudado: ${CurrencyFormatter.format(totalConsolidado)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                      if (tieneMoraConsolidado) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFD1FAE5),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'Corriente: ${CurrencyFormatter.format(totalCorrienteConsolidado)}',
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.green900, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFFFEDD5),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'Mora: ${CurrencyFormatter.format(totalMoraConsolidado)}',
                                style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFFC2410C), fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // ─── Título de la Tabla ───
            pw.Text(
              'Detalle por Cobrador',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),

            // ─── Tabla de Cortes por Cobrador ───
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // Cobrador
                1: const pw.FlexColumnWidth(2), // Registros
                2: const pw.FlexColumnWidth(2), // Cobrados
                3: const pw.FlexColumnWidth(2), // Pendientes
                4: const pw.FlexColumnWidth(2), // Total
                5: const pw.FlexColumnWidth(2), // Fecha/Hora
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Cobrador',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Registros (boletas)',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Cobrados',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Pendientes',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total (L.)',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Fecha Corte',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                // Filas de datos
                ...cortesCobradores.map((corte) {
                  final String? rangoBoletas;
                  if (corte.primerBoleta != null && corte.ultimaBoleta != null) {
                    rangoBoletas = corte.primerBoleta == corte.ultimaBoleta
                        ? corte.primerBoleta
                        : '${corte.primerBoleta} - ${corte.ultimaBoleta}';
                  } else {
                    rangoBoletas = null;
                  }

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          corte.cobradorNombre,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              '${corte.cantidadRegistros}',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                            if (rangoBoletas != null)
                              pw.Text(
                                rangoBoletas,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 7,
                                  color: PdfColors.grey700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${corte.cantidadCobrados ?? 0}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${corte.cantidadPendientes ?? 0}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          CurrencyFormatter.format(corte.totalCobrado),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          formatter.format(corte.fechaCorte),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // ─── Pie de página ───
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Documento generado el ${formatter.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printCorteMercado(
    List<Corte> cortesCobradores,
    String mercadoNombre,
    DateTime fecha,
  ) async {
    final pdfBytes = await generateCorteMercadoPdf(
      cortesCobradores,
      mercadoNombre,
      fecha,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Corte_Mercado_${DateFormat('yyyyMMdd').format(fecha)}',
    );
  }
}
