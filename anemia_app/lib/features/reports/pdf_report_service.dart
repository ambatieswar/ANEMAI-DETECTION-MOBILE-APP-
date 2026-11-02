import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../screening/domain/screening_result.dart';

class PdfReportService {
  Future<Uint8List> buildReport({
    required String patientId,
    required ScreeningResult result,
    required Uint8List eyeImage,
  }) async {
    final document = pw.Document();
    final image = pw.MemoryImage(eyeImage);
    final risk = (result.riskProbability * 100).toStringAsFixed(1);
    final quality = (result.qualityScore * 100).toStringAsFixed(0);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HemoScan Edge - Screening Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Patient ID: $patientId'),
              pw.Text('Date: ${result.createdAt.toLocal()}'),
              pw.SizedBox(height: 18),
              pw.Center(child: pw.Image(image, height: 220)),
              pw.SizedBox(height: 18),
              pw.Text('Result: ${result.label}'),
              pw.Text('Risk score: $risk%'),
              pw.Text('Image quality score: $quality%'),
              pw.SizedBox(height: 20),
              pw.Text(
                result.disclaimer,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  Future<void> shareReport({
    required String patientId,
    required ScreeningResult result,
    required Uint8List eyeImage,
  }) async {
    final bytes = await buildReport(
      patientId: patientId,
      result: result,
      eyeImage: eyeImage,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'hemoscan-$patientId.pdf',
    );
  }
}
