import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../exams/domain/exam_report.dart';

final grantedChartsProvider = NotifierProvider<GrantedCharts, int>(
  GrantedCharts.new,
);

/// Laudos de um paciente aceito. Não entra na lista da conta do médico.
class GrantedCharts extends Notifier<int> {
  final _byPatient = <String, List<ExamReport>>{};

  @override
  int build() => 0;

  List<ExamReport> reportsOf(String patientId) =>
      _byPatient[patientId] ?? const [];

  Future<void> load(String patientId) async {
    final reports = await ref
        .read(examsRepositoryProvider)
        .fetchReportsOf(patientId);
    _byPatient[patientId] = reports;
    state++;
  }

  List<MarkerSeries> seriesOf(String patientId) {
    return ref.read(examsRepositoryProvider).seriesOf(reportsOf(patientId));
  }

  MarkerSeries? seriesFor(String patientId, String name) {
    for (final series in seriesOf(patientId)) {
      if (series.name.toLowerCase() == name.toLowerCase()) return series;
    }
    return null;
  }

  void clear() {
    _byPatient.clear();
    state++;
  }
}
