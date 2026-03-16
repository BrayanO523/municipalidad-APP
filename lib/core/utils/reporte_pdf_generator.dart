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
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    final deudores = locales.where((l) => (l.deudaAcumulada ?? 0) > 0).toList()
      ..sort((a, b) => (b.deudaAcumulada ?? 0).compareTo(a.deudaAcumulada ?? 0));

    final totalDeuda = deudores.fold<num>(0, (s, l) => s + (l.deudaAcumulada ?? 0));

    final Map<String, List<Local>> porMercado = {};
    for (final l in deudores) {
      porMercado.putIfAbsent(l.mercadoId ?? '__sin_mercado__', () => []).add(l);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(fonts, titulo: 'REPORTE DE DEUDORES', subtitulo: 'Locales con deuda pendiente', fecha: fecha),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(fonts, items: [('Total deudores', '${deudores.length} locales'), ('Deuda total', 'L ${_fMoneda.format(totalDeuda)}'), ('Corte', fecha)]),
          pw.SizedBox(height: 16),
          ...porMercado.entries.map((entry) {
            final mercado = mercados.firstWhere((m) => m.id == entry.key, orElse: () => const Mercado(nombre: 'Sin Mercado'));
            final deudaM = entry.value.fold<num>(0, (s, l) => s + (l.deudaAcumulada ?? 0));
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _seccionMercado(fonts, mercado.nombre ?? '—', entry.value.length, deudaM, color: _colorRojo),
              _tablaDeudores(fonts, entry.value),
              pw.SizedBox(height: 20),
            ]);
          }),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarReporteSaldosFavor({
    required List<Local> locales,
    required List<Mercado> mercados,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    final conSaldo = locales.where((l) => (l.saldoAFavor ?? 0) > 0).toList()
      ..sort((a, b) => (b.saldoAFavor ?? 0).compareTo(a.saldoAFavor ?? 0));

    final totalSaldo = conSaldo.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0));

    final Map<String, List<Local>> porMercado = {};
    for (final l in conSaldo) {
      porMercado.putIfAbsent(l.mercadoId ?? '__sin_mercado__', () => []).add(l);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(fonts, titulo: 'REPORTE DE SALDOS A FAVOR', subtitulo: 'Créditos acumulados', fecha: fecha),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(fonts, items: [('Total locales', '${conSaldo.length}'), ('Crédito total', 'L ${_fMoneda.format(totalSaldo)}'), ('Corte', fecha)]),
          pw.SizedBox(height: 16),
          ...porMercado.entries.map((entry) {
            final mercado = mercados.firstWhere((m) => m.id == entry.key, orElse: () => const Mercado(nombre: 'Sin Mercado'));
            final saldoM = entry.value.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0));
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _seccionMercado(fonts, mercado.nombre ?? '—', entry.value.length, saldoM, color: _colorAcento),
              _tablaSaldosFavor(fonts, entry.value),
              pw.SizedBox(height: 20),
            ]);
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
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    final sorted = [...cobros]..sort((a, b) => (a.fecha ?? DateTime(2000)).compareTo(b.fecha ?? DateTime(2000)));
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
        header: (ctx) => _pdfHeader(fonts, titulo: 'REPORTE DE COBROS', subtitulo: periodoLabel ?? 'Historial', fecha: fecha),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(fonts, items: [('Total cobros', '${sorted.length}'), ('Total recaudado', 'L ${_fMoneda.format(totalMonto)}'), ('Período', periodoLabel ?? 'Gral')]),
          pw.SizedBox(height: 16),
          ...porMercado.entries.map((entry) {
            final mercado = mercados.firstWhere((m) => m.id == entry.key, orElse: () => const Mercado(nombre: 'Sin Mercado'));
            final montoM = entry.value.fold<num>(0, (s, c) => s + (c.monto ?? 0));
            final Map<String?, List<Cobro>> porLocal = {};
            for (final c in entry.value) { porLocal.putIfAbsent(c.localId, () => []).add(c); }
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _seccionMercado(fonts, mercado.nombre ?? '—', entry.value.length, montoM),
              ...porLocal.entries.map((loc) {
                final local = mapLocales[loc.key];
                return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _seccionLocal(fonts, local?.nombreSocial ?? 'Local Desconocido', loc.value.length, loc.value.fold<num>(0, (s, c) => s + (c.monto ?? 0))),
                  _tablaCobros(fonts, loc.value),
                  pw.SizedBox(height: 10),
                ]);
              }),
            ]);
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
    required List<Local> locales,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(fonts, titulo: 'RESUMEN OPERATIVO CONSOLIDADO', subtitulo: 'Periodo: $periodoLabel', fecha: fecha),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(fonts, items: [('Total Cobrado', 'L ${_fMoneda.format(totalCobrado)}'), ('Monto Pendiente', 'L ${_fMoneda.format(totalPendiente)}'), ('Período', periodoLabel)]),
          pw.SizedBox(height: 12),
          _resumenCard(fonts, items: [('Total Mora', 'L ${_fMoneda.format(totalMora)}'), ('Saldos a Favor', 'L ${_fMoneda.format(totalFavor)}'), ('Eficiencia', '${((totalCobrado / (totalCobrado + totalPendiente + 0.0001)) * 100).toStringAsFixed(1)}%')]),
          pw.SizedBox(height: 24),
          pw.Text('DESGLOSE POR MERCADO', style: pw.TextStyle(font: fonts['bold'], fontSize: 12, color: _colorFondoCabecera)),
          pw.SizedBox(height: 8),
          ...mercados.map((m) {
            final cobrosM = cobros.where((c) => c.mercadoId == m.id);
            final localesM = locales.where((l) => l.mercadoId == m.id);
            final rM = cobrosM.where((c) => c.estado?.contains('cobrado') ?? false).fold<num>(0, (s, c) => s + (c.monto ?? 0));
            final pM = cobrosM.where((c) => c.estado == 'pendiente').fold<num>(0, (s, c) => s + (c.saldoPendiente ?? 0));
            final mM = localesM.fold<num>(0, (s, l) => s + (l.deudaAcumulada ?? 0));
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _colorGris, width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(m.nombre ?? 'Sin Nombre', style: pw.TextStyle(font: fonts['bold'], fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  _miniKpi(fonts, 'Cobrado', 'L ${_fMoneda.format(rM)}', _colorAcento),
                  _miniKpi(fonts, 'Pendiente', 'L ${_fMoneda.format(pM)}', _colorPrimario),
                  _miniKpi(fonts, 'Mora', 'L ${_fMoneda.format(mM)}', _colorRojo),
                ]),
              ]),
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
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fechaGen = _fFechaHora.format(DateTime.now());

    final subtituloCompleto = '${local.nombreSocial ?? 'Local'}${local.clave != null ? ' | Clave Catastral: ${local.clave}' : ''}${local.codigo != null ? ' | Cód: ${local.codigo}' : ''}';
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(fonts, titulo: 'ESTADO DE CUENTA', subtitulo: subtituloCompleto, fecha: fechaGen),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(fonts, items: [('Balance Neto', 'L ${_fMoneda.format(local.balanceNeto)}'), ('Deuda Total', 'L ${_fMoneda.format(local.deudaAcumulada ?? 0)}'), ('Saldo a Favor', 'L ${_fMoneda.format(local.saldoAFavor ?? 0)}')]),
          pw.SizedBox(height: 16),
          _tablaCobros(fonts, cobros),
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
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    final totalCobrado = cobros.where((c) => c.estado?.contains('cobrado') ?? false).fold<num>(0, (s, c) => s + (c.monto ?? 0));
    final totalPendiente = cobros.where((c) => c.estado == 'pendiente').fold<num>(0, (s, c) => s + (c.saldoPendiente ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(fonts, titulo: 'REPORTE DE DASHBOARD', subtitulo: 'Resumen de actividad: $periodoLabel', fecha: fecha),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(fonts, items: [
            ('Cobros realizados', '${cobros.length}'),
            ('Total Recaudado', 'L ${_fMoneda.format(totalCobrado)}'),
            ('Monto Pendiente', 'L ${_fMoneda.format(totalPendiente)}'),
          ]),
          pw.SizedBox(height: 20),
          _seccionMercado(fonts, 'DETALLE POR MERCADO', cobros.length, totalCobrado),
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

  static pw.Widget _pdfHeader(Map<String, pw.Font> f, {required String titulo, required String subtitulo, required String fecha}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: _colorFondoCabecera, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('QRecauda', style: pw.TextStyle(font: f['bold'], fontSize: 10, color: _colorAcento)),
          pw.Text('Generado: $fecha', style: pw.TextStyle(font: f['regular'], fontSize: 7, color: _colorGris)),
        ]),
        pw.Divider(color: _colorGris, thickness: 0.2),
        pw.Center(child: pw.Column(children: [
          pw.Text(titulo, style: pw.TextStyle(font: f['bold'], fontSize: 15, color: PdfColors.white)),
          pw.Text(subtitulo, style: pw.TextStyle(font: f['regular'], fontSize: 10, color: _colorGris)),
        ])),
      ]),
    );
  }

  static pw.Widget _pdfFooter(Map<String, pw.Font> f, pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _colorGris, width: 0.3))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('QRecauda — Reporte Oficial', style: pw.TextStyle(font: f['regular'], fontSize: 8, color: _colorGris)),
        pw.Text('Página ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(font: f['regular'], fontSize: 8, color: _colorGris)),
      ]),
    );
  }

  static pw.Widget _resumenCard(Map<String, pw.Font> f, {required List<(String, String)> items}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _colorFondoFila, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: _colorGris, width: 0.3)),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: items.map((i) => pw.Column(children: [
        pw.Text(i.$2, style: pw.TextStyle(font: f['bold'], fontSize: 13, color: _colorPrimario)),
        pw.Text(i.$1, style: pw.TextStyle(font: f['regular'], fontSize: 8, color: _colorGris)),
      ])).toList()),
    );
  }

  static pw.Widget _seccionMercado(Map<String, pw.Font> f, String nombre, int cantidad, num total, {PdfColor color = _colorPrimario}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Mercado: $nombre', style: pw.TextStyle(font: f['bold'], fontSize: 12, color: PdfColors.white)),
        pw.Text('$cantidad reg. | L ${_fMoneda.format(total)}', style: pw.TextStyle(font: f['semi'], fontSize: 10, color: PdfColors.white)),
      ]),
    );
  }

  static pw.Widget _seccionLocal(Map<String, pw.Font> f, String nombre, int cantidad, num total) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 10, bottom: 4),
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFEDE9FE), border: pw.Border(left: pw.BorderSide(color: _colorPrimario, width: 3))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('  Local: $nombre', style: pw.TextStyle(font: f['semi'], fontSize: 10, color: _colorPrimario)),
        pw.Text('$cantidad cobros | L ${_fMoneda.format(total)}', style: pw.TextStyle(font: f['regular'], fontSize: 9, color: _colorGris)),
      ]),
    );
  }

  static pw.Widget _tablaDeudores(Map<String, pw.Font> f, List<Local> items) {
    const h = ['Local', 'Rep.', 'Tel.', 'Cuota', 'Deuda'];
    return pw.Table(columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.5)}, children: [
      _tableHeaderRow(f, h),
      ...items.asMap().entries.map((e) => pw.TableRow(decoration: pw.BoxDecoration(color: e.key.isEven ? _colorFondoFila : PdfColors.white), children: [
        _cell(f, e.value.nombreSocial ?? '—'), _cell(f, e.value.representante ?? '—'), _cell(f, e.value.telefonoRepresentante ?? '—'), _cell(f, 'L ${_fMoneda.format(e.value.cuotaDiaria ?? 0)}'), _cell(f, 'L ${_fMoneda.format(e.value.deudaAcumulada ?? 0)}', color: _colorRojo, bold: true),
      ])),
      _tableTotalRow(f, h.length, 'TOTAL DEUDA', 'L ${_fMoneda.format(items.fold<num>(0, (s, l) => s + (l.deudaAcumulada ?? 0)))}'),
    ]);
  }

  static pw.Widget _tablaSaldosFavor(Map<String, pw.Font> f, List<Local> items) {
    const h = ['Local', 'Rep.', 'Tel.', 'Cuota', 'Favor'];
    return pw.Table(columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.5)}, children: [
      _tableHeaderRow(f, h),
      ...items.asMap().entries.map((e) => pw.TableRow(decoration: pw.BoxDecoration(color: e.key.isEven ? _colorFondoFila : PdfColors.white), children: [
        _cell(f, e.value.nombreSocial ?? '—'), _cell(f, e.value.representante ?? '—'), _cell(f, e.value.telefonoRepresentante ?? '—'), _cell(f, 'L ${_fMoneda.format(e.value.cuotaDiaria ?? 0)}'), _cell(f, 'L ${_fMoneda.format(e.value.saldoAFavor ?? 0)}', color: _colorAcento, bold: true),
      ])),
      _tableTotalRow(f, h.length, 'TOTAL SALDO', 'L ${_fMoneda.format(items.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0)))}'),
    ]);
  }

  static pw.Widget _tablaCobros(Map<String, pw.Font> f, List<Cobro> items) {
    const h = ['#', 'Fecha', 'Est.', 'Cuota', 'Abono', 'Monto'];
    return pw.Table(columnWidths: {0: const pw.FlexColumnWidth(0.6), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.2), 5: const pw.FlexColumnWidth(1.3)}, children: [
      _tableHeaderRow(f, h, small: true),
      ...items.asMap().entries.map((e) => pw.TableRow(decoration: pw.BoxDecoration(color: e.key.isEven ? _colorFondoFila : PdfColors.white), children: [
        _cell(f, e.value.numeroBoletaFmt, small: true), _cell(f, e.value.fecha != null ? _fFecha.format(e.value.fecha!) : '—', small: true), _cell(f, e.value.estado ?? '—', small: true), _cell(f, 'L ${_fMoneda.format(e.value.pagoACuota ?? e.value.monto ?? 0)}', small: true), _cell(f, (e.value.montoAbonadoDeuda ?? 0) > 0 ? 'L ${_fMoneda.format(e.value.montoAbonadoDeuda!)}' : '—', small: true), _cell(f, 'L ${_fMoneda.format(e.value.monto ?? 0)}', bold: true, small: true, color: _colorPrimario),
      ])),
      _tableTotalRow(f, h.length, 'SUBTOTAL', 'L ${_fMoneda.format(items.fold<num>(0, (s, c) => s + (c.monto ?? 0)))}'),
    ]);
  }

  static pw.TableRow _tableHeaderRow(Map<String, pw.Font> f, List<String> h, {bool small = false}) {
    return pw.TableRow(decoration: const pw.BoxDecoration(color: _colorFondoCabecera), children: h.map((s) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(s, style: pw.TextStyle(font: f['semi'], fontSize: small ? 7.5 : 8.5, color: PdfColors.white)))).toList());
  }

  static pw.TableRow _tableTotalRow(Map<String, pw.Font> f, int cols, String l, String v) {
    return pw.TableRow(decoration: const pw.BoxDecoration(color: _colorFondoCabecera), children: [
      ...List.generate(cols - 1, (i) => i == 0 ? pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(l, style: pw.TextStyle(font: f['bold'], fontSize: 8, color: _colorAcento))) : pw.SizedBox()),
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(v, style: pw.TextStyle(font: f['bold'], fontSize: 8.5, color: _colorAcento), textAlign: pw.TextAlign.right)),
    ]);
  }

  static pw.Widget _cell(Map<String, pw.Font> f, String t, {PdfColor? color, bool bold = false, bool small = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.Text(t, style: pw.TextStyle(font: bold ? f['bold'] : f['regular'], fontSize: small ? 7.5 : 8.5, color: color ?? PdfColors.black)));
  }

  static pw.Widget _miniKpi(Map<String, pw.Font> f, String label, String value, PdfColor color) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(font: f['regular'], fontSize: 7, color: _colorGris)),
      pw.Text(value, style: pw.TextStyle(font: f['bold'], fontSize: 9, color: color)),
    ]);
  }
}
