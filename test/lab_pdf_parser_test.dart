import 'dart:io';

import 'package:exame_facil/features/exams/data/lab_pdf_parser.dart';
import 'package:exame_facil/features/exams/data/pdf_text_extractor.dart';
import 'package:exame_facil/features/exams/data/sample_exam_text.dart';
import 'package:exame_facil/features/exams/domain/exam_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrai marcadores do laudo de exemplo Unilab', () {
    final report = LabPdfParser().parse(sampleExamPdfText);

    expect(report.markers.length, greaterThanOrEqualTo(20));
    expect(report.collectedAt.day, 3);
    expect(report.collectedAt.month, 8);
    expect(report.collectedAt.year, 2026);
    expect(report.labName, 'Unilab');

    ExamMarker find(String name) =>
        report.markers.firstWhere((m) => m.name == name);

    expect(find('Hemoglobina').value, closeTo(16.1, 0.01));
    expect(find('Glicose').value, 92);
    expect(find('Glicose').status, MarkerStatus.normal);
    expect(find('INR').value, closeTo(3.10, 0.01));
    expect(find('INR').status, MarkerStatus.high);
    expect(find('Ácido úrico').status, MarkerStatus.low);
    expect(find('Colesterol Total').value, 143);
    expect(find('Colesterol LDL').value, 84);
    expect(find('TSH').value, closeTo(0.91, 0.01));
    expect(find('AST/TGO').previousValues.length, greaterThanOrEqualTo(1));
  });

  test('usa Data atend. mesmo quando o valor vem separado da impressão', () {
    const text = '''
Documento CPF :
Data atend.
:
Data impressão :
Procedimento(s):
Qtd. páginas
:
316.938.268-36
03/08/2026 - 08:06
07/08/2026 - 14:30
16
de 16
1/12

Glicose
Material: Soro Coleta: 15/01/2026 - 08:18
Resultado: 92 mg/dL
Valor de Referência: 70 a 99 mg/dL
''';

    final report = LabPdfParser().parse(text);
    expect(report.collectedAt.day, 3);
    expect(report.collectedAt.month, 8);
    expect(report.collectedAt.year, 2026);
    expect(report.collectedAt, isNot(DateTime(2026, 8, 7)));
  });

  test('Exame2 traz os exames das páginas seguintes, cada um com a Coleta', () async {
    final text = await PdfTextExtractorService().fromFile(File('Exame2.pdf'));
    final report = LabPdfParser().parse(text);

    ExamMarker find(String name) =>
        report.markers.firstWhere((m) => m.name == name);

    expect(find('AST/TGO').value, 21);
    expect(find('ALT/TGP').value, 28);
    expect(find('Fosfatase alcalina').value, 57);
    expect(find('GGT').value, 8);
    expect(find('Bilirrubina direta').value, closeTo(0.38, 0.01));
    expect(find('Bilirrubina indireta').value, closeTo(0.67, 0.01));
    expect(find('Bilirrubina total').value, closeTo(1.05, 0.01));
    expect(find('Vitamina D').value, closeTo(20.9, 0.01));
    expect(find('Vitamina B12').value, 413);

    for (final name in [
      'AST/TGO',
      'Fosfatase alcalina',
      'GGT',
      'Vitamina D',
      'Bilirrubina total',
    ]) {
      expect(find(name).collectedAt, DateTime(2026, 3, 30), reason: name);
    }
  });

  test('ipc.pdf entra com os mesmos nomes para cruzar com outros laudos', () async {
    final text = await PdfTextExtractorService().fromFile(File('ipc.pdf'));
    final report = LabPdfParser().parse(text);

    ExamMarker find(String name) =>
        report.markers.firstWhere((m) => m.name == name);

    expect(find('Hemoglobina').value, closeTo(14.8, 0.01));
    expect(find('Hemoglobina').collectedAt, DateTime(2023, 8, 18));
    expect(find('Leucócitos').value, 5800);
    expect(find('Plaquetas').value, 198000);
    expect(find('Glicose').value, 85);
    expect(find('Ácido úrico').value, closeTo(5.5, 0.01));
    expect(find('Colesterol Total').value, 290);
    expect(find('Colesterol HDL').value, 40);
    expect(find('Colesterol LDL').value, 206);
    expect(find('Colesterol VLDL').value, 29);
    expect(find('Triglicerídeos').value, 137);
    expect(find('Ferritina').value, closeTo(157, 0.01));
    expect(find('Vitamina B12').value, 475);
    expect(find('Colesterol LDL').collectedAt, DateTime(2023, 8, 18));
  });
}
