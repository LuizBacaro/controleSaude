import 'package:controle_saude/features/exams/data/lab_pdf_parser.dart';
import 'package:controle_saude/features/exams/data/sample_exam_text.dart';
import 'package:controle_saude/features/exams/domain/exam_marker.dart';
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
    expect(find('TSH').value, closeTo(0.91, 0.01));
    expect(find('AST/TGO').previousValues.length, greaterThanOrEqualTo(1));
  });
}
