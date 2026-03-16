import 'dart:typed_data';
import 'package:intl/intl.dart';
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
    Map<String, String>? localNames,
  }) async {
    final pdf = pw.Document();
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
                      'Fecha de impresiÃ³n: ${formatter.format(DateTime.now())}',
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
                      'Recaudado: L. ${totalCobrado.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Pendiente: L. ${totalPendiente.toStringAsFixed(2)}',
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
              _buildTable(cobrados, localNames, PdfColors.green50),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Subtotal Cobrado: L. ${totalCobrado.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // â”€â”€ Tabla Gestiones/Incidencias â”€â”€
            if (gestionesInfo.isNotEmpty) ...[
              pw.Text(
                'Detalle de Incidencias Registradas',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.brown900,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildGestionesTable(gestionesInfo, PdfColors.brown50),
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
                  'Subtotal Pendiente: L. ${totalPendiente.toStringAsFixed(2)}',
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
    Map<String, String>? localNames,
    PdfColor headerColor,
  ) {
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
          final String localDisplay =
              localNames?[cobro.localId] ?? 'Sin Nombre';
          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
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
                  localDisplay,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'L. ${(cobro.monto ?? 0).toStringAsFixed(2)}',
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
            if (codigo.isNotEmpty) 'CÃ³d: $codigo',
            if (clave.isNotEmpty) 'Clave Catastral: $clave',
            if (tieneSaldoAFavor)
              saldoCubreCuota
                  ? 'Tiene saldo a favor suficiente; falta registrar el cobro con saldo'
                  : 'Saldo a favor: L. ${saldoAFavor.toStringAsFixed(2)}',
          ].join(' â€¢ ');

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
                  'L. ${monto.toStringAsFixed(2)}',
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
        return 'Volver mÃ¡s tarde';
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
            if (codigo.isNotEmpty) 'CÃ³d: $codigo',
            if (clave.isNotEmpty) 'Clave Catastral: $clave',
          ].join(' â€¢ ');

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
    Map<String, String>? localNames,
  }) async {
    final pdfBytes = await generateCortePdf(
      corte,
      cobros,
      localNames: localNames,
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
    final pdf = pw.Document();
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
                  pw.Text(
                    'Total Recaudado: L. ${totalConsolidado.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
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
                        'Registros',
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
                        child: pw.Text(
                          '${corte.cantidadRegistros}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9),
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
                          corte.totalCobrado.toStringAsFixed(2),
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
