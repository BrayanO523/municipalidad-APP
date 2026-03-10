import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/cobros/domain/entities/cobro.dart';
import '../../features/locales/domain/entities/local.dart';
import '../../features/mercados/domain/entities/mercado.dart';

/// Genera PDFs de reportes detallados para el Administrador General.
/// Soporta agrupación por Mercado → Local con todos los campos disponibles.
class ReportePdfGenerator {
  static final _fMoneda = NumberFormat('#,##0.00', 'es_HN');
  static final _fFecha = DateFormat('dd/MM/yyyy');
  static final _fFechaHora = DateFormat('dd/MM/yyyy HH:mm');

  // ── Colores corporativos ────────────────────────────────────────────────────
  static const _colorPrimario = PdfColor.fromInt(0xFF4F46E5); // indigo
  static const _colorAcento = PdfColor.fromInt(0xFF00D9A6); // verde acqua
  static const _colorRojo = PdfColor.fromInt(0xFFEE5A6F);
  static const _colorGris = PdfColor.fromInt(0xFF6B7280);
  static const _colorFondoFila = PdfColor.fromInt(0xFFF3F4F6);
  static const _colorFondoCabecera = PdfColor.fromInt(0xFF1E1B4B);

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTE DE DEUDORES
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generarReporteDeudores({
    required List<Local> locales,
    required List<Mercado> mercados,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    // Solo locales con deuda, ordenados mayor a menor
    final deudores = locales.where((l) => (l.deudaAcumulada ?? 0) > 0).toList()
      ..sort(
        (a, b) => (b.deudaAcumulada ?? 0).compareTo(a.deudaAcumulada ?? 0),
      );

    final totalDeuda = deudores.fold<num>(
      0,
      (s, l) => s + (l.deudaAcumulada ?? 0),
    );

    // Agrupar por mercado
    final Map<String, List<Local>> porMercado = {};
    for (final l in deudores) {
      final mId = l.mercadoId ?? '__sin_mercado__';
      porMercado.putIfAbsent(mId, () => []).add(l);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          titulo: 'REPORTE DE DEUDORES',
          subtitulo: 'Locales con deuda pendiente de pago',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total deudores', '${deudores.length} locales'),
              ('Deuda total acumulada', 'L ${_fMoneda.format(totalDeuda)}'),
              ('Fecha de corte', fecha),
            ],
          ),
          pw.SizedBox(height: 16),

          // Secciones por mercado
          ...porMercado.entries.map((entry) {
            final mercado = mercados.cast<Mercado>().firstWhere(
              (m) => m.id == entry.key,
              orElse: () => const Mercado(nombre: 'Sin Mercado'),
            );
            final deudaM = entry.value.fold<num>(
              0,
              (s, l) => s + (l.deudaAcumulada ?? 0),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _seccionMercado(
                  fonts,
                  mercado.nombre ?? '—',
                  entry.value.length,
                  deudaM,
                  color: _colorRojo,
                ),
                _tablaDeudores(fonts, entry.value),
                pw.SizedBox(height: 20),
              ],
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTE DE SALDOS A FAVOR
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generarReporteSaldosFavor({
    required List<Local> locales,
    required List<Mercado> mercados,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

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
          titulo: 'REPORTE DE SALDOS A FAVOR',
          subtitulo: 'Créditos acumulados por pagos adelantados',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total locales con crédito', '${conSaldo.length} locales'),
              ('Crédito total acumulado', 'L ${_fMoneda.format(totalSaldo)}'),
              ('Fecha de corte', fecha),
            ],
          ),
          pw.SizedBox(height: 16),

          ...porMercado.entries.map((entry) {
            final mercado = mercados.cast<Mercado>().firstWhere(
              (m) => m.id == entry.key,
              orElse: () => const Mercado(nombre: 'Sin Mercado'),
            );
            final saldoM = entry.value.fold<num>(
              0,
              (s, l) => s + (l.saldoAFavor ?? 0),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _seccionMercado(
                  fonts,
                  mercado.nombre ?? '—',
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

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTE DE COBROS
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generarReporteCobros({
    required List<Cobro> cobros,
    required List<Local> locales,
    required List<Mercado> mercados,
    String? periodoLabel,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fecha = _fFechaHora.format(DateTime.now());

    final sorted = [...cobros]
      ..sort(
        (a, b) =>
            (a.fecha ?? DateTime(2000)).compareTo(b.fecha ?? DateTime(2000)),
      );

    final totalMonto = sorted.fold<num>(0, (s, c) => s + (c.monto ?? 0));
    final mapLocales = {for (final l in locales) l.id: l};

    // Agrupar cobros por mercado
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
          titulo: 'REPORTE DE COBROS',
          subtitulo: periodoLabel ?? 'Historial de cobros registrados',
          fecha: fecha,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          _resumenCard(
            fonts,
            items: [
              ('Total de cobros', '${sorted.length} registros'),
              ('Monto total recaudado', 'L ${_fMoneda.format(totalMonto)}'),
              ('Período', periodoLabel ?? 'General'),
            ],
          ),
          pw.SizedBox(height: 16),

          ...porMercado.entries.map((entry) {
            final mercado = mercados.cast<Mercado>().firstWhere(
              (m) => m.id == entry.key,
              orElse: () => const Mercado(nombre: 'Sin Mercado'),
            );
            final montoM = entry.value.fold<num>(
              0,
              (s, c) => s + (c.monto ?? 0),
            );

            // Agrupar cobros de este mercado por local
            final Map<String?, List<Cobro>> porLocal = {};
            for (final c in entry.value) {
              porLocal.putIfAbsent(c.localId, () => []).add(c);
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _seccionMercado(
                  fonts,
                  mercado.nombre ?? '—',
                  entry.value.length,
                  montoM,
                ),
                pw.SizedBox(height: 6),

                // Sub-secciones por local
                ...porLocal.entries.map((loc) {
                  final local = mapLocales[loc.key];
                  final montoLocal = loc.value.fold<num>(
                    0,
                    (s, c) => s + (c.monto ?? 0),
                  );
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _seccionLocal(
                        fonts,
                        local?.nombreSocial ?? loc.key ?? '—',
                        loc.value.length,
                        montoLocal,
                      ),
                      _tablaCobros(fonts, loc.value),
                      pw.SizedBox(height: 10),
                    ],
                  );
                }),
                pw.SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Helpers de diseño ──────────────────────────────────────────────────────

  static Future<Map<String, pw.Font>> _fonts() async => {
    'bold': await PdfGoogleFonts.poppinsBold(),
    'semi': await PdfGoogleFonts.poppinsSemiBold(),
    'regular': await PdfGoogleFonts.poppinsRegular(),
  };

  static pw.Widget _pdfHeader(
    Map<String, pw.Font> f, {
    required String titulo,
    required String subtitulo,
    required String fecha,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                'QRecauda',
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
          pw.SizedBox(height: 4),
          pw.Divider(color: _colorGris, thickness: 0.2),
          pw.SizedBox(height: 4),
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
                pw.SizedBox(height: 2),
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

  static pw.Widget _pdfFooter(Map<String, pw.Font> f, pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _colorGris, width: 0.3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'QRecauda — Reporte Oficial',
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
              (item) => pw.Column(
                children: [
                  pw.Text(
                    item.$2,
                    style: pw.TextStyle(
                      font: f['bold'],
                      fontSize: 13,
                      color: _colorPrimario,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    item.$1,
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            '$cantidad registros  |  L ${_fMoneda.format(total)}',
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
      margin: const pw.EdgeInsets.only(top: 4, bottom: 4, left: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEDE9FE),
        border: pw.Border(left: pw.BorderSide(color: _colorPrimario, width: 3)),
        // En package:pdf, borderRadius solo es válido si el borde es uniforme
        // borderRadius: pw.BorderRadius.circular(3),
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
            '$cantidad cobros  |  L ${_fMoneda.format(total)}',
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

  // ── Tablas de datos ────────────────────────────────────────────────────────

  static pw.Widget _tablaDeudores(Map<String, pw.Font> f, List<Local> items) {
    const headers = [
      'Local',
      'Representante',
      'Teléfono',
      'Cuota/día',
      'Deuda',
    ];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableHeaderRow(f, headers),
        ...items.asMap().entries.map((e) {
          final l = e.value;
          final isAlternate = e.key.isEven;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isAlternate ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, l.nombreSocial ?? '—'),
              _cell(f, l.representante ?? '—'),
              _cell(f, l.telefonoRepresentante ?? '—'),
              _cell(f, 'L ${_fMoneda.format(l.cuotaDiaria ?? 0)}'),
              _cell(
                f,
                'L ${_fMoneda.format(l.deudaAcumulada ?? 0)}',
                color: _colorRojo,
                bold: true,
              ),
            ],
          );
        }),
        _tableTotalRow(
          f,
          headers.length,
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
    const headers = [
      'Local',
      'Representante',
      'Teléfono',
      'Cuota/día',
      'Saldo a Favor',
    ];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableHeaderRow(f, headers),
        ...items.asMap().entries.map((e) {
          final l = e.value;
          final isAlternate = e.key.isEven;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isAlternate ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, l.nombreSocial ?? '—'),
              _cell(f, l.representante ?? '—'),
              _cell(f, l.telefonoRepresentante ?? '—'),
              _cell(f, 'L ${_fMoneda.format(l.cuotaDiaria ?? 0)}'),
              _cell(
                f,
                'L ${_fMoneda.format(l.saldoAFavor ?? 0)}',
                color: _colorAcento,
                bold: true,
              ),
            ],
          );
        }),
        _tableTotalRow(
          f,
          headers.length,
          'TOTAL SALDO',
          'L ${_fMoneda.format(items.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0)))}',
        ),
      ],
    );
  }

  static pw.Widget _tablaCobros(Map<String, pw.Font> f, List<Cobro> items) {
    const headers = ['#', 'Fecha', 'Estado', 'Cuota', 'Abono Deuda', 'Monto'];
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
        _tableHeaderRow(f, headers, small: true),
        ...items.asMap().entries.map((e) {
          final c = e.value;
          final isAlternate = e.key.isEven;
          final correlativoStr = c.numeroBoletaFmt;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isAlternate ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              _cell(f, correlativoStr, small: true),
              _cell(
                f,
                c.fecha != null ? _fFecha.format(c.fecha!) : '—',
                small: true,
              ),
              _cell(f, c.estado ?? '—', small: true),
              _cell(
                f,
                'L ${_fMoneda.format(c.pagoACuota ?? c.monto ?? 0)}',
                small: true,
              ),
              _cell(
                f,
                c.montoAbonadoDeuda != null && c.montoAbonadoDeuda! > 0
                    ? 'L ${_fMoneda.format(c.montoAbonadoDeuda!)}'
                    : '—',
                small: true,
              ),
              _cell(
                f,
                'L ${_fMoneda.format(c.monto ?? 0)}',
                bold: true,
                small: true,
                color: _colorPrimario,
              ),
            ],
          );
        }),
        _tableTotalRow(
          f,
          headers.length,
          'SUBTOTAL',
          'L ${_fMoneda.format(items.fold<num>(0, (s, c) => s + (c.monto ?? 0)))}',
        ),
      ],
    );
  }

  // ── Helpers de tabla ───────────────────────────────────────────────────────

  static pw.TableRow _tableHeaderRow(
    Map<String, pw.Font> f,
    List<String> headers, {
    bool small = false,
  }) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _colorFondoCabecera),
      children: headers
          .map(
            (h) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              child: pw.Text(
                h,
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
    String label,
    String value,
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
                    label,
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
            value,
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
    String text, {
    PdfColor? color,
    bool bold = false,
    bool small = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? f['bold'] : f['regular'],
          fontSize: small ? 7.5 : 8.5,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTE ESTADO DE CUENTA LOCAL
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generarEstadoCuentaLocalPdf({
    required Local local,
    required List<Cobro> cobros,
    String? nombreMercado,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fechaGen = _fFechaHora.format(DateTime.now());

    // Transformación inicial (igual que vista real)
    final cuota = (local.cuotaDiaria ?? 0);
    final saldo = (local.saldoAFavor ?? 0);
    final deuda = (local.deudaAcumulada ?? 0);
    final balance = local.balanceNeto;
    final numAdelantados = cuota > 0 ? (saldo / cuota).floor() : 0;

    // Generar días adelantados virtuales
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final hoyTieneRegistro = cobros.any(
      (c) =>
          c.fecha != null &&
          c.fecha!.year == hoy.year &&
          c.fecha!.month == hoy.month &&
          c.fecha!.day == hoy.day,
    );
    final fechaInicio = hoyTieneRegistro
        ? hoy.add(const Duration(days: 1))
        : hoy;

    final adelantados = List.generate(
      numAdelantados,
      (i) => Cobro(
        id: 'VIRTUAL-$i',
        localId: local.id,
        fecha: fechaInicio.add(Duration(days: i)),
        monto: local.cuotaDiaria,
        estado: 'adelantado',
        cuotaDiaria: local.cuotaDiaria,
        saldoPendiente: 0,
        observaciones: 'Día cubierto por saldo a favor.',
      ),
    );

    final combinedList = [...cobros, ...adelantados];
    combinedList.sort(
      (a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)),
    );

    final cobrados = cobros.where((c) => c.estado == 'cobrado').toList();
    final pendientes = cobros.where((c) => c.estado == 'pendiente').toList();
    final recaudado = cobros.fold<num>(0, (s, c) => s + (c.monto ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          titulo: 'ESTADO DE CUENTA',
          subtitulo: local.nombreSocial ?? 'Local',
          fecha: fechaGen,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          // ── Datos del Local
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _colorGris, width: 0.3),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  local.nombreSocial ?? 'Local Sin Nombre',
                  style: pw.TextStyle(
                    font: fonts['bold'],
                    fontSize: 14,
                    color: _colorPrimario,
                  ),
                ),
                if (nombreMercado != null) pw.SizedBox(height: 4),
                if (nombreMercado != null)
                  pw.Text(
                    'Mercado: $nombreMercado',
                    style: pw.TextStyle(
                      font: fonts['regular'],
                      fontSize: 10,
                      color: _colorGris,
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _infoPar(
                      fonts,
                      'Representante:',
                      local.representante ?? '—',
                    ),
                    _infoPar(
                      fonts,
                      'Teléfono:',
                      local.telefonoRepresentante ?? '—',
                    ),
                    _infoPar(
                      fonts,
                      'Cuota Diaria:',
                      'L ${_fMoneda.format(local.cuotaDiaria ?? 0)}',
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _infoPar(fonts, 'ID de Local:', local.id ?? '—'),
                    pw.SizedBox(),
                    pw.SizedBox(),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ── Tarjetas Resumen Financiero
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Saldo a Favor',
                  'L ${_fMoneda.format(saldo)}',
                  _colorAcento,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Deuda Acumulada',
                  'L ${_fMoneda.format(deuda)}',
                  _colorRojo,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Balance Neto',
                  'L ${_fMoneda.format(balance)}',
                  balance < 0 ? _colorRojo : _colorAcento,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Días Cobrados',
                  '${cobrados.length}',
                  _colorPrimario,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Días Pendientes',
                  '${pendientes.length}',
                  _colorRojo,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Días Adelantados',
                  '$numAdelantados',
                  const PdfColor.fromInt(0xFFF59E0B),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Total Recaudado',
                  'L ${_fMoneda.format(recaudado)}',
                  _colorPrimario,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Total Registros',
                  '${combinedList.length}',
                  _colorGris,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()), // Spacer
            ],
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Historial de Cobros',
            style: pw.TextStyle(
              font: fonts['bold'],
              fontSize: 12,
              color: _colorPrimario,
            ),
          ),
          pw.SizedBox(height: 8),

          if (combinedList.isEmpty)
            pw.Text(
              'No hay historial registrado.',
              style: pw.TextStyle(
                font: fonts['regular'],
                fontSize: 10,
                color: _colorGris,
              ),
            )
          else
            _tablaEstadoCuenta(fonts, combinedList),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoPar(
    Map<String, pw.Font> f,
    String label,
    String value,
  ) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: f['regular'],
            fontSize: 9,
            color: _colorGris,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: f['semi'],
            fontSize: 9,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _kpiCard(
    Map<String, pw.Font> f,
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _colorFondoFila,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // Barra de acento lateral
          pw.Container(
            width: 3,
            height: 32,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                bottomLeft: pw.Radius.circular(6),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    value,
                    style: pw.TextStyle(
                      font: f['bold'],
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    label,
                    style: pw.TextStyle(
                      font: f['regular'],
                      fontSize: 7.5,
                      color: _colorGris,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tablaEstadoCuenta(
    Map<String, pw.Font> f,
    List<Cobro> items,
  ) {
    const headers = ['Fecha / Observación', 'Estado', 'Monto'];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        _tableHeaderRow(f, headers),
        ...items.asMap().entries.map((e) {
          final c = e.value;
          final isAlternate = e.key.isEven;

          PdfColor estadoColor = _colorGris;
          if (c.estado == 'cobrado') estadoColor = _colorAcento;
          if (c.estado == 'pendiente') estadoColor = _colorRojo;
          if (c.estado == 'adelantado') {
            estadoColor = const PdfColor.fromInt(0xFFF59E0B);
          }

          final String fechaObs = c.fecha != null
              ? _fFechaHora.format(c.fecha!)
              : '—';
          final String obvs =
              c.observaciones != null && c.observaciones!.isNotEmpty
              ? c.observaciones!
              : '';

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isAlternate ? _colorFondoFila : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      fechaObs,
                      style: pw.TextStyle(font: f['semi'], fontSize: 8.5),
                    ),
                    if (obvs.isNotEmpty)
                      pw.Text(
                        obvs,
                        style: pw.TextStyle(
                          font: f['regular'],
                          fontSize: 7,
                          color: _colorGris,
                        ),
                      ),
                  ],
                ),
              ),
              _cell(
                f,
                c.estado ?? '—',
                color: estadoColor,
                small: true,
                bold: true,
              ),
              _cell(
                f,
                'L ${_fMoneda.format(c.monto ?? 0)}',
                bold: true,
                small: true,
                color: _colorPrimario,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTE DE DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generarReporteDashboard({
    required List<Cobro> cobrosPeriodo,
    required List<Local> locales,
    required List<Mercado> mercados,
    required String periodoLabel,
  }) async {
    final fonts = await _fonts();
    final pdf = pw.Document();
    final fechaGen = _fFechaHora.format(DateTime.now());

    final recaudacion = cobrosPeriodo.fold<num>(
      0,
      (s, c) => s + (c.monto ?? 0),
    );
    final activos = locales.where((l) => l.activo == true).toList();
    final deudaTotal = activos.fold<num>(
      0,
      (s, l) => s + (l.deudaAcumulada ?? 0),
    );
    final saldoTotal = activos.fold<num>(0, (s, l) => s + (l.saldoAFavor ?? 0));
    final localesDeuda = activos
        .where((l) => (l.deudaAcumulada ?? 0) > 0)
        .length;
    final localesCredito = activos
        .where((l) => (l.saldoAFavor ?? 0) > 0)
        .length;

    // Agrupar cobros periodo por mercado para el detalle
    final Map<String, List<Cobro>> porMercado = {};
    for (final c in cobrosPeriodo) {
      porMercado.putIfAbsent(c.mercadoId ?? '__sin_mercado__', () => []).add(c);
    }
    final mapLocales = {for (final l in locales) l.id: l};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        header: (ctx) => _pdfHeader(
          fonts,
          titulo: 'REPORTE DE DASHBOARD',
          subtitulo: 'Período: $periodoLabel',
          fecha: fechaGen,
        ),
        footer: (ctx) => _pdfFooter(fonts, ctx),
        build: (ctx) => [
          // ── KPIs del Período
          pw.Text(
            'Métricas del Período',
            style: pw.TextStyle(
              font: fonts['bold'],
              fontSize: 12,
              color: _colorPrimario,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Recaudación',
                  'L ${_fMoneda.format(recaudacion)}',
                  _colorAcento,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Cobros',
                  '${cobrosPeriodo.length}',
                  _colorPrimario,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Mercados',
                  '${mercados.where((m) => m.activo == true).length}',
                  const PdfColor.fromInt(0xFFF59E0B),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Locales',
                  '${locales.length}',
                  _colorRojo,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── KPIs Globales
          pw.Text(
            'Métricas Globales (Históricas)',
            style: pw.TextStyle(
              font: fonts['bold'],
              fontSize: 12,
              color: _colorPrimario,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Deuda Acumulada',
                  'L ${_fMoneda.format(deudaTotal)}',
                  _colorRojo,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _kpiCard(
                  fonts,
                  'Saldo a Favor',
                  'L ${_fMoneda.format(saldoTotal)}',
                  _colorAcento,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Locales con Deuda: $localesDeuda  |  Locales con Saldo a Favor: $localesCredito',
            style: pw.TextStyle(
              font: fonts['regular'],
              fontSize: 9,
              color: _colorGris,
            ),
          ),
          pw.SizedBox(height: 24),

          // ── Detalle de cobros del período
          pw.Text(
            'Detalle de Recaudación del Período',
            style: pw.TextStyle(
              font: fonts['bold'],
              fontSize: 12,
              color: _colorPrimario,
            ),
          ),
          pw.SizedBox(height: 8),

          if (cobrosPeriodo.isEmpty)
            pw.Text(
              'No hay cobros registrados en este período.',
              style: pw.TextStyle(
                font: fonts['regular'],
                fontSize: 10,
                color: _colorGris,
              ),
            )
          else
            ...porMercado.entries.map((entry) {
              final mercado = mercados.cast<Mercado>().firstWhere(
                (m) => m.id == entry.key,
                orElse: () => const Mercado(nombre: 'Sin Mercado'),
              );
              final montoM = entry.value.fold<num>(
                0,
                (s, c) => s + (c.monto ?? 0),
              );

              final Map<String?, List<Cobro>> porLocal = {};
              for (final c in entry.value) {
                porLocal.putIfAbsent(c.localId, () => []).add(c);
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _seccionMercado(
                    fonts,
                    mercado.nombre ?? '—',
                    entry.value.length,
                    montoM,
                  ),
                  pw.SizedBox(height: 6),
                  ...porLocal.entries.map((loc) {
                    final local = mapLocales[loc.key];
                    final montoLocal = loc.value.fold<num>(
                      0,
                      (s, c) => s + (c.monto ?? 0),
                    );
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _seccionLocal(
                          fonts,
                          local?.nombreSocial ?? loc.key ?? '—',
                          loc.value.length,
                          montoLocal,
                        ),
                        _tablaCobros(fonts, loc.value),
                        pw.SizedBox(height: 10),
                      ],
                    );
                  }),
                  pw.SizedBox(height: 16),
                ],
              );
            }),
        ],
      ),
    );
    return pdf.save();
  }
}
