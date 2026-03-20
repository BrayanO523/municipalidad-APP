import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/cobros/domain/entities/cobro.dart';
import '../../features/locales/domain/entities/local.dart';
import '../../features/mercados/domain/entities/mercado.dart';

/// Genera PDFs de reportes detallados para el Administrador General.
class ReportePdfGenerator {
  static final _fMoneda = NumberFormat('#,##0.00', 'es_HN');
  static final _fFecha = DateFormat('dd/MM/yyyy');
  static final _fFechaHora = DateFormat('dd/MM/yyyy HH:mm');

  static const _colorPrimario = PdfColor.fromInt(0xFF4F46E5);
  static const _colorAcento = PdfColor.fromInt(0xFF00D9A6);
  static const _colorRojo = PdfColor.fromInt(0xFFEE5A6F);
  static const _colorGris = PdfColor.fromInt(0xFF6B7280);
  static const _colorFondoFila = PdfColor.fromInt(0xFFF3F4F6);
  static const _colorFondoCabecera = PdfColor.fromInt(0xFF1E1B4B);

  static Future<Uint8List> generarReporteDeudores({
    required List<Local> locales,
    required List<Mercado> mercados,
    String? municipalidadNombre,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());
    final entidad = _entidadReporte(municipalidadNombre);

    final deudores = locales.where((l) => (l.deudaAcumulada ?? 0) > 0).toList()
      ..sort(
        (a, b) => (b.deudaAcumulada ?? 0).compareTo(a.deudaAcumulada ?? 0),
      );

    final totalDeuda = deudores.fold<num>(
      0,
      (s, l) => s + (l.deudaAcumulada ?? 0),
    );

    final Map<String, List<Local>> porMercado = {};
    for (final l in deudores) {
      porMercado.putIfAbsent(l.mercadoId ?? '__sin_mercado__', () => []).add(l);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          entidad: entidad,
          titulo: 'REPORTE DE DEUDORES',
          subtitulo: 'Locales con deuda pendiente',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx, entidad: entidad),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total deudores', '${deudores.length} locales'),
              ('Deuda total', 'L ${_fMoneda.format(totalDeuda)}'),
              ('Corte', fecha),
            ],
          ),
          pw.SizedBox(height: 16),
          ...porMercado.entries.expand((entry) sync* {
            final mercado = _buscarMercadoPorId(mercados, entry.key);
            final deudaM = entry.value.fold<num>(
              0,
              (s, l) => s + (l.deudaAcumulada ?? 0),
            );
            yield _seccionMercado(
              fonts,
              mercado?.nombre ?? 'Sin Mercado',
              entry.value.length,
              deudaM,
              color: _colorRojo,
            );
            yield _tablaDeudores(fonts, entry.value);
            yield pw.SizedBox(height: 20);
          }),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarReporteSaldosFavor({
    required List<Local> locales,
    required List<Mercado> mercados,
    String? municipalidadNombre,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());
    final entidad = _entidadReporte(municipalidadNombre);

    final conSaldo = locales.where((l) => (l.saldoAFavor ?? 0) > 0).toList()
      ..sort((a, b) => (b.saldoAFavor ?? 0).compareTo(a.saldoAFavor ?? 0));

    final totalSaldo = conSaldo.fold<num>(
      0,
      (s, l) => s + (l.saldoAFavor ?? 0),
    );

    final Map<String, List<Local>> porMercado = {};
    for (final l in conSaldo) {
      porMercado.putIfAbsent(l.mercadoId ?? '__sin_mercado__', () => []).add(l);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          entidad: entidad,
          titulo: 'REPORTE DE SALDOS A FAVOR',
          subtitulo: 'Créditos acumulados',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx, entidad: entidad),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total locales', '${conSaldo.length}'),
              ('Crédito total', 'L ${_fMoneda.format(totalSaldo)}'),
              ('Corte', fecha),
            ],
          ),
          pw.SizedBox(height: 16),
          ...porMercado.entries.map((entry) {
            final mercado = _buscarMercadoPorId(mercados, entry.key);
            final saldoM = entry.value.fold<num>(
              0,
              (s, l) => s + (l.saldoAFavor ?? 0),
            );
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _seccionMercado(
                  fonts,
                  mercado?.nombre ?? 'Sin Mercado',
                  entry.value.length,
                  saldoM,
                  color: _colorAcento,
                ),
                _tablaSaldosFavor(fonts, entry.value),
                pw.SizedBox(height: 20),
              ],
            );
          }),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarReporteCobros({
    required List<Cobro> cobros,
    required List<Local> locales,
    required List<Mercado> mercados,
    String? periodoLabel,
    String? municipalidadNombre,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());
    final entidad = _entidadReporte(municipalidadNombre);

    final sorted = [...cobros]
      ..sort(
        (a, b) =>
            (a.fecha ?? DateTime(2000)).compareTo(b.fecha ?? DateTime(2000)),
      );
    final totalMonto = sorted.fold<num>(0, (s, c) => s + (c.monto ?? 0));
    final mapLocales = {for (final l in locales) l.id: l};

    final Map<String, List<Cobro>> porMercado = {};
    for (final c in sorted) {
      porMercado.putIfAbsent(c.mercadoId ?? '__sin_mercado__', () => []).add(c);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          entidad: entidad,
          titulo: 'REPORTE DE COBROS',
          subtitulo: periodoLabel ?? 'Historial',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx, entidad: entidad),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total cobros', '${sorted.length}'),
              ('Total recaudado', 'L ${_fMoneda.format(totalMonto)}'),
              ('Período', periodoLabel ?? 'Gral'),
            ],
          ),
          pw.SizedBox(height: 16),
          ...porMercado.entries.expand((entry) sync* {
            final mercado = _buscarMercadoPorId(mercados, entry.key);
            final montoM = entry.value.fold<num>(
              0,
              (s, c) => s + (c.monto ?? 0),
            );
            final Map<String?, List<Cobro>> porLocal = {};
            for (final c in entry.value) {
              porLocal.putIfAbsent(c.localId, () => []).add(c);
            }

            yield _seccionMercado(
              fonts,
              mercado?.nombre ?? 'Sin Mercado',
              entry.value.length,
              montoM,
            );

            for (final loc in porLocal.entries) {
              final local = mapLocales[loc.key];
              final nombreLocal = local?.nombreSocial ?? 'Local Desconocido';
              final totalLocal = loc.value.fold<num>(
                0,
                (s, c) => s + (c.monto ?? 0),
              );
              final bloques = _dividirEnBloques(loc.value, 28);

              for (var i = 0; i < bloques.length; i++) {
                final esContinuacion = i > 0;
                yield _seccionLocal(
                  fonts,
                  esContinuacion
                      ? '$nombreLocal (continuación ${i + 1})'
                      : nombreLocal,
                  loc.value.length,
                  totalLocal,
                );
                yield _tablaCobros(fonts, bloques[i]);
                yield pw.SizedBox(height: 8);
              }
            }

            yield pw.SizedBox(height: 12);
          }),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarReporteResumenOperativo({
    required num totalCobrado,
    required num totalPendiente,
    required num totalMora,
    required num totalFavor,
    required String periodoLabel,
    required List<Mercado> mercados,
    required List<Cobro> cobros,
    String? municipalidadNombre,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());
    final entidad = _entidadReporte(municipalidadNombre);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          entidad: entidad,
          titulo: 'RESUMEN OPERATIVO CONSOLIDADO',
          subtitulo: 'Periodo: $periodoLabel',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx, entidad: entidad),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total Cobrado', 'L ${_fMoneda.format(totalCobrado)}'),
              ('Monto Pendiente', 'L ${_fMoneda.format(totalPendiente)}'),
              ('Período', periodoLabel),
            ],
          ),
          pw.SizedBox(height: 12),
          _resumenCard(
            fonts,
            items: [
              ('Mora Recuperada', 'L ${_fMoneda.format(totalMora)}'),
              ('Saldo Favor Actual', 'L ${_fMoneda.format(totalFavor)}'),
              (
                'Eficiencia',
                '${((totalCobrado / (totalCobrado + totalPendiente + 0.0001)) * 100).toStringAsFixed(1)}%',
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'DESGLOSE POR MERCADO',
            style: pw.TextStyle(
              font: fonts['bold'],
              fontSize: 12,
              color: _colorFondoCabecera,
            ),
          ),
          pw.SizedBox(height: 8),
          ...mercados.map((m) {
            final cobrosM = cobros.where((c) => c.mercadoId == m.id);
            final rM = cobrosM.fold<num>(0, (s, c) => s + (c.monto ?? 0));
            final pM = cobrosM
                .where(
                  (c) => c.estado == 'pendiente' || c.estado == 'abono_parcial',
                )
                .fold<num>(0, (s, c) => s + (c.saldoPendiente ?? 0));
            final mM = cobrosM.fold<num>(0, (s, c) => s + (c.montoMora ?? 0));
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _colorGris, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    m.nombre ?? 'Sin Nombre',
                    style: pw.TextStyle(font: fonts['bold'], fontSize: 10),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _miniKpi(
                        fonts,
                        'Cobrado',
                        'L ${_fMoneda.format(rM)}',
                        _colorAcento,
                      ),
                      _miniKpi(
                        fonts,
                        'Pendiente',
                        'L ${_fMoneda.format(pM)}',
                        _colorPrimario,
                      ),
                      _miniKpi(
                        fonts,
                        'Mora Rec.',
                        'L ${_fMoneda.format(mM)}',
                        _colorRojo,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarEstadoCuentaLocalPdf({
    required Local local,
    required List<Cobro> cobros,
    String? nombreMercado,
    String? municipalidadNombre,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fechaGen = _fFechaHora.format(DateTime.now());
    final entidad = _entidadReporte(municipalidadNombre);
    final resumenDeuda = _resumenDeudaEstadoCuenta(local, cobros);

    final subtituloCompleto =
        '${local.nombreSocial ?? 'Local'}${local.clave != null ? ' | Clave Catastral: ${local.clave}' : ''}${local.codigo != null ? ' | Cód: ${local.codigo}' : ''}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          entidad: entidad,
          titulo: 'ESTADO DE CUENTA',
          subtitulo: subtituloCompleto,
          fecha: fechaGen,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx, entidad: entidad),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              (
                'Deuda Original',
                'L ${_fMoneda.format(resumenDeuda.deudaOriginal)}',
              ),
              (
                'Abonado a Deuda',
                'L ${_fMoneda.format(resumenDeuda.abonadoDeuda)}',
              ),
              (
                'Deuda Actual',
                'L ${_fMoneda.format(resumenDeuda.deudaActual)}',
              ),
              ('Saldo a Favor', 'L ${_fMoneda.format(local.saldoAFavor ?? 0)}'),
            ],
          ),
          if (resumenDeuda.ultimaFechaAbono != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Último abono registrado: ${_fFecha.format(resumenDeuda.ultimaFechaAbono!)}',
              style: pw.TextStyle(
                font: fonts['regular'],
                fontSize: 8,
                color: _colorGris,
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          _tablaEstadoCuentaLocal(fonts, local, cobros),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarReporteDashboard({
    required List<Cobro> cobros,
    required List<Local> locales,
    required List<Mercado> mercados,
    required String periodoLabel,
    String? municipalidadNombre,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());
    final entidad = _entidadReporte(municipalidadNombre);

    final totalCobrado = cobros.fold<num>(0, (s, c) => s + (c.monto ?? 0));
    final totalPendiente = cobros
        .where((c) => c.estado == 'pendiente' || c.estado == 'abono_parcial')
        .fold<num>(0, (s, c) => s + (c.saldoPendiente ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          entidad: entidad,
          titulo: 'REPORTE DE DASHBOARD',
          subtitulo: 'Resumen de actividad: $periodoLabel',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx, entidad: entidad),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Cobros realizados', '${cobros.length}'),
              ('Total Recaudado', 'L ${_fMoneda.format(totalCobrado)}'),
              ('Monto Pendiente', 'L ${_fMoneda.format(totalPendiente)}'),
            ],
          ),
          pw.SizedBox(height: 20),
          _seccionMercado(
            fonts,
            'DETALLE POR MERCADO',
            cobros.length,
            totalCobrado,
          ),
          _tablaCobros(fonts, cobros),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Map<String, pw.Font>> _fonts() async => {
    'bold': await PdfGoogleFonts.poppinsBold(),
    'semi': await PdfGoogleFonts.poppinsSemiBold(),
    'regular': await PdfGoogleFonts.poppinsRegular(),
  };

  static Mercado? _buscarMercadoPorId(
    List<Mercado> mercados,
    String? mercadoId,
  ) {
    for (final mercado in mercados) {
      if (mercado.id == mercadoId) return mercado;
    }
    return null;
  }

  static pw.Widget _pdfHeader(
    Map<String, pw.Font> f, {
    required String entidad,
    required String titulo,
    required String subtitulo,
    required String fecha,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _colorFondoCabecera,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                entidad,
                style: pw.TextStyle(
                  font: f['bold'],
                  fontSize: 10,
                  color: _colorAcento,
                ),
              ),
              pw.Text(
                'Generado: $fecha',
                style: pw.TextStyle(
                  font: f['regular'],
                  fontSize: 7,
                  color: _colorGris,
                ),
              ),
            ],
          ),
          pw.Divider(color: _colorGris, thickness: 0.2),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    font: f['bold'],
                    fontSize: 15,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  subtitulo,
                  style: pw.TextStyle(
                    font: f['regular'],
                    fontSize: 10,
                    color: _colorGris,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfFooter(
    Map<String, pw.Font> f,
    pw.Context ctx, {
    required String entidad,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _colorGris, width: 0.3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$entidad - Reporte Oficial',
            style: pw.TextStyle(
              font: f['regular'],
              fontSize: 8,
              color: _colorGris,
            ),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
              font: f['regular'],
              fontSize: 8,
              color: _colorGris,
            ),
          ),
        ],
      ),
    );
  }

  static String _entidadReporte(String? municipalidadNombre) {
    final nombre = municipalidadNombre?.trim() ?? '';
    if (nombre.isNotEmpty) return nombre;
    return 'Municipalidad';
  }

  static pw.Widget _resumenCard(
    Map<String, pw.Font> f, {
    required List<(String, String)> items,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _colorFondoFila,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _colorGris, width: 0.3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: items
            .map(
              (i) => pw.Column(
                children: [
                  pw.Text(
                    i.$2,
                    style: pw.TextStyle(
                      font: f['bold'],
                      fontSize: 13,
                      color: _colorPrimario,
                    ),
                  ),
                  pw.Text(
                    i.$1,
                    style: pw.TextStyle(
                      font: f['regular'],
                      fontSize: 8,
                      color: _colorGris,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  static pw.Widget _seccionMercado(
    Map<String, pw.Font> f,
    String nombre,
    int cantidad,
    num total, {
    PdfColor color = _colorPrimario,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Mercado: $nombre',
            style: pw.TextStyle(
              font: f['bold'],
              fontSize: 12,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            '$cantidad reg. | L ${_fMoneda.format(total)}',
            style: pw.TextStyle(
              font: f['semi'],
              fontSize: 10,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _seccionLocal(
    Map<String, pw.Font> f,
    String nombre,
    int cantidad,
    num total,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 10, bottom: 4),
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEDE9FE),
        border: pw.Border(left: pw.BorderSide(color: _colorPrimario, width: 3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '  Local: $nombre',
            style: pw.TextStyle(
              font: f['semi'],
              fontSize: 10,
              color: _colorPrimario,
            ),
          ),
          pw.Text(
            '$cantidad cobros | L ${_fMoneda.format(total)}',
            style: pw.TextStyle(
              font: f['regular'],
              fontSize: 9,
              color: _colorGris,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tablaDeudores(Map<String, pw.Font> f, List<Local> items) {
    const h = ['Local', 'Representante', 'Teléfono', 'Cuota', 'Deuda'];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableHeaderRow(f, h),
        ...items.asMap().entries.map(
          (e) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: e.key.isEven ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, e.value.nombreSocial ?? '—'),
              _cell(f, e.value.representante ?? '—'),
              _cell(f, e.value.telefonoRepresentante ?? '—'),
              _cell(f, 'L ${_fMoneda.format(e.value.cuotaDiaria ?? 0)}'),
              _cell(
                f,
                'L ${_fMoneda.format(e.value.deudaAcumulada ?? 0)}',
                color: _colorRojo,
                bold: true,
              ),
            ],
          ),
        ),
        _tableTotalRow(
          f,
          h.length,
          'TOTAL DEUDA',
          'L ${_fMoneda.format(items.fold<num>(0, (s, l) => s + (l.deudaAcumulada ?? 0)))}',
        ),
      ],
    );
  }

  static pw.Widget _tablaSaldosFavor(
    Map<String, pw.Font> f,
    List<Local> items,
  ) {
    const h = ['Local', 'Representante', 'Teléfono', 'Cuota', 'Favor'];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableHeaderRow(f, h),
        ...items.asMap().entries.map(
          (e) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: e.key.isEven ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, e.value.nombreSocial ?? '—'),
              _cell(f, e.value.representante ?? '—'),
              _cell(f, e.value.telefonoRepresentante ?? '—'),
              _cell(f, 'L ${_fMoneda.format(e.value.cuotaDiaria ?? 0)}'),
              _cell(
                f,
                'L ${_fMoneda.format(e.value.saldoAFavor ?? 0)}',
                color: _colorAcento,
                bold: true,
              ),
            ],
          ),
        ),
        _tableTotalRow(
          f,
          h.length,
          'TOTAL SALDO',
          'L ${_fMoneda.format(items.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0)))}',
        ),
      ],
    );
  }

  static pw.Widget _tablaCobros(Map<String, pw.Font> f, List<Cobro> items) {
    const h = ['Boleta', 'Fecha', 'Est.', 'Cuota', 'Abono', 'Monto'];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.3),
      },
      children: [
        _tableHeaderRow(f, h, small: true),
        ...items.asMap().entries.map(
          (e) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: e.key.isEven ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, e.value.numeroBoletaFmt, small: true),
              _cell(
                f,
                e.value.fecha != null ? _fFecha.format(e.value.fecha!) : '—',
                small: true,
              ),
              _cell(f, e.value.estado ?? '—', small: true),
              _cell(
                f,
                'L ${_fMoneda.format(e.value.pagoACuota ?? e.value.monto ?? 0)}',
                small: true,
              ),
              _cell(
                f,
                (e.value.montoAbonadoDeuda ?? 0) > 0
                    ? 'L ${_fMoneda.format(e.value.montoAbonadoDeuda!)}'
                    : '—',
                small: true,
              ),
              _cell(
                f,
                'L ${_fMoneda.format(e.value.monto ?? 0)}',
                bold: true,
                small: true,
                color: _colorPrimario,
              ),
            ],
          ),
        ),
        _tableTotalRow(
          f,
          h.length,
          'SUBTOTAL',
          'L ${_fMoneda.format(items.fold<num>(0, (s, c) => s + (c.monto ?? 0)))}',
        ),
      ],
    );
  }

  static pw.Widget _tablaEstadoCuentaLocal(
    Map<String, pw.Font> f,
    Local local,
    List<Cobro> items,
  ) {
    const h = ['#', 'Fecha', 'Est.', 'Cuota', 'Abono', 'Monto'];
    final filas = _normalizarFilasEstadoCuenta(local, items);

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.3),
      },
      children: [
        _tableHeaderRow(f, h, small: true),
        ...filas.asMap().entries.map(
          (e) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: e.key.isEven ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, e.value.boleta, small: true),
              _cell(
                f,
                e.value.fecha != null ? _fFecha.format(e.value.fecha!) : '—',
                small: true,
              ),
              _cell(f, e.value.estado, small: true),
              _cell(f, 'L ${_fMoneda.format(e.value.cuota)}', small: true),
              _cell(
                f,
                e.value.abono > 0 ? 'L ${_fMoneda.format(e.value.abono)}' : '—',
                small: true,
              ),
              _cell(
                f,
                'L ${_fMoneda.format(e.value.monto)}',
                bold: true,
                small: true,
                color: _colorPrimario,
              ),
            ],
          ),
        ),
        _tableTotalRow(
          f,
          h.length,
          'SUBTOTAL',
          'L ${_fMoneda.format(filas.fold<double>(0, (s, r) => s + r.monto))}',
        ),
      ],
    );
  }

  static List<_EstadoCuentaFilaPdf> _normalizarFilasEstadoCuenta(
    Local local,
    List<Cobro> items,
  ) {
    final filas = <_EstadoCuentaFilaPdf>[];
    final porBoleta = <String, List<Cobro>>{};
    final sinBoleta = <Cobro>[];
    final fechasCubiertasPorBoleta = <DateTime>{};
    final cuotaLocal = _toDouble(local.cuotaDiaria);

    for (final c in items) {
      final boletaId = _boletaIdValida(c);
      if (boletaId != null) {
        porBoleta.putIfAbsent(boletaId, () => []).add(c);
      } else {
        sinBoleta.add(c);
      }
    }

    for (final entry in porBoleta.entries) {
      final boleta = entry.key;
      final grupo = entry.value;
      if (grupo.isEmpty) continue;

      Cobro master = grupo.first;
      var maxMonto = _toDouble(master.monto);
      for (final c in grupo) {
        final monto = _toDouble(c.monto);
        if (monto > maxMonto) {
          maxMonto = monto;
          master = c;
        }
      }

      final cuotaGrupo = _maxPositivo([
        for (final c in grupo) _toDouble(c.cuotaDiaria),
        cuotaLocal,
      ]);

      final rowsPorFecha = <DateTime, _EstadoCuentaFilaPdf>{};
      void acumularFila(_EstadoCuentaFilaPdf nueva) {
        final fecha = nueva.fecha;
        if (fecha == null) {
          filas.add(nueva);
          return;
        }
        final actual = rowsPorFecha[fecha];
        if (actual == null) {
          rowsPorFecha[fecha] = nueva;
          return;
        }
        rowsPorFecha[fecha] = _EstadoCuentaFilaPdf(
          boleta: actual.boleta,
          fecha: actual.fecha,
          estado:
              actual.estado == 'abono_parcial' ||
                  nueva.estado == 'abono_parcial'
              ? 'abono_parcial'
              : actual.estado,
          cuota: actual.cuota + nueva.cuota,
          abono: actual.abono + nueva.abono,
          monto: actual.monto + nueva.monto,
        );
      }

      final fechasDeuda = <DateTime>{};
      final cuotaPorFecha = <DateTime, double>{};
      for (final c in grupo) {
        for (final d in (c.fechasDeudasSaldadas ?? const <DateTime>[])) {
          fechasDeuda.add(_soloFecha(d));
        }
        final pagoCuota = _toDouble(c.pagoACuota);
        if (pagoCuota > 0) {
          final fechaCuota = c.fecha ?? c.creadoEn;
          if (fechaCuota != null) {
            final normalizada = _soloFecha(fechaCuota);
            cuotaPorFecha[normalizada] =
                (cuotaPorFecha[normalizada] ?? 0) + pagoCuota;
          }
        }
      }

      for (final d in fechasDeuda) {
        fechasCubiertasPorBoleta.add(d);
        final valorCuota = _maxPositivo([cuotaGrupo, cuotaLocal]);
        acumularFila(
          _EstadoCuentaFilaPdf(
            boleta: boleta,
            fecha: d,
            estado: 'cobrado',
            cuota: valorCuota,
            abono: valorCuota,
            monto: valorCuota,
          ),
        );
      }

      for (final e in cuotaPorFecha.entries) {
        fechasCubiertasPorBoleta.add(e.key);
        final pago = _maxPositivo([e.value, cuotaGrupo, cuotaLocal]);
        final esParcial = cuotaGrupo > 0 && (pago + 0.001) < cuotaGrupo;
        acumularFila(
          _EstadoCuentaFilaPdf(
            boleta: boleta,
            fecha: e.key,
            estado: esParcial ? 'abono_parcial' : 'cobrado',
            cuota: pago,
            abono: 0,
            monto: pago,
          ),
        );
      }

      if (rowsPorFecha.isEmpty) {
        final fecha = master.fecha ?? master.creadoEn;
        final cuota = _maxPositivo([
          _toDouble(master.pagoACuota),
          _toDouble(master.saldoPendiente),
          _toDouble(master.cuotaDiaria),
          cuotaGrupo,
          cuotaLocal,
        ]);
        final abono = _toDouble(master.montoAbonadoDeuda);
        final monto = _maxPositivo([
          _toDouble(master.monto),
          cuota + abono,
          cuota,
          abono,
        ]);
        final estado = (master.estado ?? 'cobrado').trim();
        filas.add(
          _EstadoCuentaFilaPdf(
            boleta: boleta,
            fecha: fecha,
            estado: estado.isNotEmpty ? estado : 'cobrado',
            cuota: cuota,
            abono: abono,
            monto: monto,
          ),
        );
        if (fecha != null) {
          fechasCubiertasPorBoleta.add(_soloFecha(fecha));
        }
      } else {
        final listaGrupo = rowsPorFecha.values.toList()
          ..sort(
            (a, b) =>
                (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
          );
        filas.addAll(listaGrupo);
      }
    }

    for (final c in sinBoleta) {
      final fecha = c.fecha ?? c.creadoEn;
      if (fecha != null) {
        final normalizada = _soloFecha(fecha);
        if (fechasCubiertasPorBoleta.contains(normalizada)) continue;
      }

      final estado = (c.estado ?? 'pendiente').trim();
      final esPendiente = estado == 'pendiente' || estado == 'abono_parcial';

      final cuota = esPendiente
          ? _maxPositivo([
              _toDouble(c.saldoPendiente),
              _toDouble(c.cuotaDiaria),
              cuotaLocal,
            ])
          : _maxPositivo([
              _toDouble(c.pagoACuota),
              _toDouble(c.cuotaDiaria),
              _toDouble(c.monto),
              cuotaLocal,
            ]);

      final abono = _toDouble(c.montoAbonadoDeuda);
      final monto = _maxPositivo([
        _toDouble(c.monto),
        cuota + abono,
        cuota,
        abono,
      ]);

      filas.add(
        _EstadoCuentaFilaPdf(
          boleta: c.numeroBoletaFmt == '0' ? '—' : c.numeroBoletaFmt,
          fecha: fecha != null ? _soloFecha(fecha) : null,
          estado: estado.isNotEmpty ? estado : 'pendiente',
          cuota: cuota,
          abono: abono,
          monto: monto,
        ),
      );
    }

    filas.sort((a, b) {
      final cmpFecha = (b.fecha ?? DateTime(0)).compareTo(
        a.fecha ?? DateTime(0),
      );
      if (cmpFecha != 0) return cmpFecha;
      return a.boleta.compareTo(b.boleta);
    });

    return filas;
  }

  static _ResumenDeudaEstadoCuenta _resumenDeudaEstadoCuenta(
    Local local,
    List<Cobro> items,
  ) {
    final deudaActual = _toDouble(local.deudaAcumulada);
    final porBoleta = <String, List<Cobro>>{};
    final sinBoleta = <Cobro>[];

    for (final c in items) {
      final boleta = _boletaIdValida(c);
      if (boleta != null) {
        porBoleta.putIfAbsent(boleta, () => []).add(c);
      } else {
        sinBoleta.add(c);
      }
    }

    double abonadoDeuda = 0;
    DateTime? ultimaFechaAbono;

    void registrarFechaAbono(DateTime? fecha) {
      if (fecha == null) return;
      if (ultimaFechaAbono == null || fecha.isAfter(ultimaFechaAbono!)) {
        ultimaFechaAbono = fecha;
      }
    }

    for (final grupo in porBoleta.values) {
      if (grupo.isEmpty) continue;

      final cuotaGrupo = _maxPositivo([
        for (final c in grupo) _toDouble(c.cuotaDiaria),
        _toDouble(local.cuotaDiaria),
      ]);

      double abonoGrupo = 0;
      DateTime? fechaBoleta;
      final fechasDeuda = <DateTime>{};

      for (final c in grupo) {
        final abono = _toDouble(c.montoAbonadoDeuda);
        if (abono > abonoGrupo) abonoGrupo = abono;

        for (final d in (c.fechasDeudasSaldadas ?? const <DateTime>[])) {
          fechasDeuda.add(_soloFecha(d));
        }

        final fechaRef = c.fecha ?? c.creadoEn;
        if (fechaRef != null &&
            (fechaBoleta == null || fechaRef.isAfter(fechaBoleta))) {
          fechaBoleta = fechaRef;
        }
      }

      if (abonoGrupo <= 0 && cuotaGrupo > 0 && fechasDeuda.isNotEmpty) {
        abonoGrupo = cuotaGrupo * fechasDeuda.length;
      }

      if (abonoGrupo > 0) {
        abonadoDeuda += abonoGrupo;
        registrarFechaAbono(fechaBoleta);
      }
    }

    for (final c in sinBoleta) {
      final cuota = _maxPositivo([
        _toDouble(c.cuotaDiaria),
        _toDouble(local.cuotaDiaria),
      ]);
      final fechasDeuda = (c.fechasDeudasSaldadas ?? const <DateTime>[])
          .map(_soloFecha)
          .toSet();

      double abono = _toDouble(c.montoAbonadoDeuda);
      if (abono <= 0 && cuota > 0 && fechasDeuda.isNotEmpty) {
        abono = cuota * fechasDeuda.length;
      }

      if (abono > 0) {
        abonadoDeuda += abono;
        registrarFechaAbono(c.fecha ?? c.creadoEn);
      }
    }

    return _ResumenDeudaEstadoCuenta(
      deudaOriginal: deudaActual + abonadoDeuda,
      abonadoDeuda: abonadoDeuda,
      deudaActual: deudaActual,
      ultimaFechaAbono: ultimaFechaAbono != null
          ? _soloFecha(ultimaFechaAbono!)
          : null,
    );
  }

  static String? _boletaIdValida(Cobro c) {
    final id = (c.numeroBoleta ?? c.correlativo?.toString())?.trim();
    if (id == null || id.isEmpty || id == '0') return null;
    return id;
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  static double _toDouble(num? n) => (n ?? 0).toDouble();

  static double _maxPositivo(Iterable<double> values) {
    double max = 0;
    for (final v in values) {
      if (v > max) max = v;
    }
    return max;
  }

  static List<List<T>> _dividirEnBloques<T>(List<T> items, int tamano) {
    if (items.isEmpty || tamano <= 0) return [items];
    final bloques = <List<T>>[];
    for (var i = 0; i < items.length; i += tamano) {
      final fin = (i + tamano < items.length) ? i + tamano : items.length;
      bloques.add(items.sublist(i, fin));
    }
    return bloques;
  }

  static pw.TableRow _tableHeaderRow(
    Map<String, pw.Font> f,
    List<String> h, {
    bool small = false,
  }) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _colorFondoCabecera),
      children: h
          .map(
            (s) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              child: pw.Text(
                s,
                style: pw.TextStyle(
                  font: f['semi'],
                  fontSize: small ? 7.5 : 8.5,
                  color: PdfColors.white,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.TableRow _tableTotalRow(
    Map<String, pw.Font> f,
    int cols,
    String l,
    String v,
  ) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _colorFondoCabecera),
      children: [
        ...List.generate(
          cols - 1,
          (i) => i == 0
              ? pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  child: pw.Text(
                    l,
                    style: pw.TextStyle(
                      font: f['bold'],
                      fontSize: 8,
                      color: _colorAcento,
                    ),
                  ),
                )
              : pw.SizedBox(),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            v,
            style: pw.TextStyle(
              font: f['bold'],
              fontSize: 8.5,
              color: _colorAcento,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static pw.Widget _cell(
    Map<String, pw.Font> f,
    String t, {
    PdfColor? color,
    bool bold = false,
    bool small = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          font: bold ? f['bold'] : f['regular'],
          fontSize: small ? 7.5 : 8.5,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _miniKpi(
    Map<String, pw.Font> f,
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: f['regular'],
            fontSize: 7,
            color: _colorGris,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: f['bold'], fontSize: 9, color: color),
        ),
      ],
    );
  }
}

class _EstadoCuentaFilaPdf {
  final String boleta;
  final DateTime? fecha;
  final String estado;
  final double cuota;
  final double abono;
  final double monto;

  const _EstadoCuentaFilaPdf({
    required this.boleta,
    required this.fecha,
    required this.estado,
    required this.cuota,
    required this.abono,
    required this.monto,
  });
}

class _ResumenDeudaEstadoCuenta {
  final double deudaOriginal;
  final double abonadoDeuda;
  final double deudaActual;
  final DateTime? ultimaFechaAbono;

  const _ResumenDeudaEstadoCuenta({
    required this.deudaOriginal,
    required this.abonadoDeuda,
    required this.deudaActual,
    required this.ultimaFechaAbono,
  });
}
