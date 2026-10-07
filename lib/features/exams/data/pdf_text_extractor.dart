import 'dart:io';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extrai texto de um PDF (arquivo local ou bytes).
class PdfTextExtractorService {
  Future<String> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    return fromBytes(bytes);
  }

  Future<String> fromBytes(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      for (var i = 0; i < document.pages.count; i++) {
        buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
      }
      return buffer.toString();
    } finally {
      document.dispose();
    }
  }

  Future<String> fromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return fromBytes(data.buffer.asUint8List());
  }
}
