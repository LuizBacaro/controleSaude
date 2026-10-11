import 'dart:io';

import 'package:exame_facil/features/exams/data/lab_pdf_parser.dart';
import 'package:exame_facil/features/exams/data/pdf_text_extractor.dart';
import 'package:exame_facil/features/exams/data/sample_exam_text.dart';
import 'package:exame_facil/features/exams/domain/exam_marker.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isAgeOrDocument(ExamMarker marker) {
  final name = marker.name.toLowerCase();
  const blocked = [
    'mes',
    'mês',
    'meses',
    'ano',
    'anos',
    'adulto',
    'nasc',
    'anterior',
    'procedimento',
    'página',
    'pagina',
    'c.n.e.s',
    'cnes',
  ];
  return blocked.any(name.contains);
}

void main() {
  test('extrai marcadores do laudo de exemplo Unilab', () {
    final report = LabPdfParser().parse(sampleExamPdfText);

    expect(report.markers.length, greaterThanOrEqualTo(20));
    expect(report.collectedAt.day, 3);
    expect(report.collectedAt.month, 8);
    expect(report.collectedAt.year, 2026);
    expect(report.labName, 'Unilab');
    expect(report.patientName, 'PACIENTE EXEMPLO');

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

  test(
    'Exame2 traz os exames das páginas seguintes, cada um com a Coleta',
    () async {
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
    },
  );

  test(
    'ipc.pdf entra com os mesmos nomes para cruzar com outros laudos',
    () async {
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
      expect(report.patientName, 'LUIS ROBERTO BACARO SALVADOR');
      expect(report.doctorName, 'WALDEMAR PASCHOALINO JUNIOR');
      expect(report.labName, 'IPC - CENTRAL');
      expect(report.insuranceName, 'UNIMED ARARAQUARA');
    },
  );

  test('resultado.pdf lê frações com o nome invertido e a ureia', () async {
    final text = await PdfTextExtractorService().fromFile(
      File('resultado.pdf'),
    );
    final report = LabPdfParser().parse(text);

    ExamMarker find(String name) =>
        report.markers.firstWhere((m) => m.name == name);

    expect(report.collectedAt, DateTime(2025, 5, 22));
    expect(report.patientName, 'LUIS ROBERTO BACARO SALVADOR');
    expect(report.doctorName, 'LUCIANA DOS SANTOS SCHRAIBER');
    expect(report.labName, 'Unilab');
    expect(report.insuranceName, 'UNIMED');
    expect(find('Colesterol Total').value, 164);
    expect(find('Colesterol HDL').value, 51);
    expect(find('Colesterol LDL').value, 96);
    expect(find('Colesterol VLDL').value, 17);
    expect(find('Colesterol não HDL').value, 113);
    expect(find('Índice de Castelli').value, closeTo(3.22, 0.01));
    expect(find('Triglicerídeos').value, 87);
    expect(find('Hemácias').value, closeTo(5.71, 0.01));
    expect(find('Plaquetas').value, 182000);
    expect(find('Creatinina').value, closeTo(1.3, 0.01));
    expect(find('Ureia').value, closeTo(40.2, 0.01));
    expect(find('Glicose').value, 96);
    expect(find('AST/TGO').value, 24);
    expect(find('ALT/TGP').value, 37);
    expect(find('GGT').value, 9);
    expect(find('Fosfatase alcalina').value, 59);
    expect(find('Ferritina').value, closeTo(189.6, 0.01));
    expect(
      find('Colesterol HDL').previousValues.map((p) => p.value),
      containsAll([39, 38]),
    );
    expect(find('Metamielócitos').value, 0);
    expect(find('Metamielócitos').category, 'Não classificado');
    expect(find('Bastonetes').category, 'Não classificado');
    expect(report.markers.where((m) => m.name == 'Colesterol HDL').length, 1);
    expect(
      report.markers.where(_isAgeOrDocument),
      isEmpty,
    );
  });

  test('faixa de idade e texto do laudo não viram exame', () {
    const text = '''
Coleta: 01/02/2024
Creatinina
Resultado: 1,1 mg/dL
Valores de Referência:
Recém Nascidos: 0,29 - 1,04 mg/dL
De 02 a 12 meses: 0,17 - 0,42 mg/dL
De 01 a 03 anos: 0,24 - 0,41 mg/dL
Adultos: 0,70 - 1,20 mg/dL
meses: 0,17 mg/dL
Zinco: 88 µg/dL
Resultado(s) anterior(es):
16/03/2024
0,9 mg/dL
''';
    final report = LabPdfParser().parse(text);
    expect(report.markers.where(_isAgeOrDocument), isEmpty);
    expect(report.markers.where((m) => m.name == 'Zinco').length, 1);
    expect(report.markers.where((m) => m.name == 'Creatinina').length, 1);
    expect(
      report.markers.firstWhere((m) => m.name == 'Creatinina').value,
      closeTo(1.1, 0.01),
    );
  });

  test('leitor genérico guarda exame desconhecido com a faixa do PDF', () {
    const text = '''
Coleta: 01/02/2024
Zinco: 88 µg/dL
Valor de Referência: 70 a 120 µg/dL
HIV: Não reagente
Glicose
Resultado: 90 mg/dL
''';
    final report = LabPdfParser().parse(text);
    ExamMarker find(String name) =>
        report.markers.firstWhere((m) => m.name == name);

    expect(find('Zinco').value, 88);
    expect(find('Zinco').category, 'Não classificado');
    expect(find('Zinco').referenceMin, 70);
    expect(find('Zinco').referenceMax, 120);
    expect(find('HIV').textValue, 'Não reagente');
    expect(find('HIV').isQualitative, isTrue);
    expect(report.markers.where((m) => m.name == 'Glicose').length, 1);
    expect(find('Glicose').value, 90);
  });

  test('exame.pdf guarda o solicitante, a unidade e o convênio', () async {
    final text = await PdfTextExtractorService().fromFile(File('exame.pdf'));
    final report = LabPdfParser().parse(text);

    expect(report.patientName, 'LUIS ROBERTO BACARO SALVADOR');
    expect(report.doctorName, 'Dra. CECILIA MEIRELLES BARROS');
    expect(report.labName, 'Unilab');
    expect(report.insuranceName, 'Várias fontes pagadoras');
  });

  test('exame4 separa a urina tipo I do sangue e lê PSA', () async {
    final text = await PdfTextExtractorService().fromFile(File('exame4.pdf'));
    final report = LabPdfParser().parse(text);

    ExamMarker find(String name) =>
        report.markers.firstWhere((m) => m.name == name);

    expect(find('Urina: Cor').textValue, 'Amarelo');
    expect(find('Urina: Cor').isQualitative, isTrue);
    expect(find('Urina: Aspecto').textValue, 'Límpido');
    expect(find('Urina: Proteínas').status, MarkerStatus.normal);
    expect(find('Urina: Densidade').value, closeTo(1.032, 0.0001));
    expect(find('Urina: Densidade').status, MarkerStatus.high);
    expect(find('Urina: pH').value, closeTo(7.5, 0.01));
    expect(find('Urina: pH').status, MarkerStatus.high);
    expect(find('Urina: Glicose').value, 500);
    expect(find('Urina: Hemácias').value, closeTo(8.4, 0.01));
    expect(find('Urina: Não escamosas').status, MarkerStatus.high);
    expect(find('Urina: Densidade').collectedAt, DateTime(2024, 8, 9));

    expect(find('Creatinina').value, closeTo(1.1, 0.01));
    expect(find('Creatinina').collectedAt, DateTime(2024, 8, 8));
    expect(find('PSA').value, closeTo(0.87, 0.01));
    expect(report.markers.where((m) => m.name == 'Hemácias'), isEmpty);
    expect(report.markers.where((m) => m.name == 'Glicose'), isEmpty);
  });
}
