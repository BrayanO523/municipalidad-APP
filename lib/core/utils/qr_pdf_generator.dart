import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrPdfGenerator {
  /// Genera un PDF de una sola página en tamaño Carta, diseñado para ser
  /// impreso y pegado en el local. Excluye deliberadamente IDs para
  /// proteger la estructura de datos.
  static Future<Uint8List> generateLocalQrDocument({
    required String nombreLocal,
    required String qrData, // El ID técnico a incrustar en el QR
  }) async {
    final pdf = pw.Document();

    // Podemos usar la fuente por defecto, pero si queremos darle estilo
    // podemos descargar alguna de Google Fonts usando printing:
    final titleFont = await PdfGoogleFonts.poppinsSemiBold();
    final regularFont = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final iconFont = await PdfGoogleFonts.materialIcons();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(24),
              border: pw.Border.all(
                color: PdfColor.fromHex('#2F3E46'),
                width: 4,
              ),
            ),
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Spacer(),
                // Marca (QRecauda)
                pw.Text(
                  'QRecauda',
                  style: pw.TextStyle(
                    font: titleFont,
                    fontSize: 48,
                    color: PdfColor.fromHex('#4F46E5'), // Indigo
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Portal de Pagos Rápidos',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 20,
                    color: PdfColor.fromHex('#6B7280'),
                    letterSpacing: 1.5,
                  ),
                ),
                pw.Spacer(),

                // Nombre del Local (Protagonista)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F3F4F6'),
                    borderRadius: pw.BorderRadius.circular(16),
                  ),
                  child: pw.Text(
                    nombreLocal.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 32,
                      color: PdfColor.fromHex('#111827'),
                    ),
                  ),
                ),

                pw.SizedBox(height: 40),

                // QR Code Vectorizado (Alta Calidad)
                pw.Container(
                  width: 320,
                  height: 320,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(24),
                    boxShadow: [
                      pw.BoxShadow(
                        color: PdfColor.fromHex('#E5E7EB'),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high,
                    ),
                    data: qrData, // Aquí va el ID nativo para la app
                    color: PdfColor.fromHex('#111827'),
                    width: 280,
                    height: 280,
                  ),
                ),

                pw.Spacer(flex: 2),

                // Instrucciones
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Icon(
                      pw.IconData(0xe3b0),
                      color: PdfColor.fromHex('#6B7280'),
                      size: 24,
                      font: iconFont,
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      'Escanea este código usando la aplicación oficial',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 18,
                        color: PdfColor.fromHex('#4B5563'),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  '© ${DateTime.now().year} Sistema de Administración Municipal',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 12,
                    color: PdfColor.fromHex('#9CA3AF'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
