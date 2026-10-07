import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/exam_marker.dart';
import '../domain/exam_report.dart';
import 'lab_pdf_parser.dart';
import 'pdf_text_extractor.dart';
import 'sample_exam_text.dart';

const _reportsKey = 'controle_saude_reports';

class ExamsRepository {
  ExamsRepository({
    required this.prefs,
    LabPdfParser? parser,
    PdfTextExtractorService? extractor,
  })  : _parser = parser ?? LabPdfParser(),
        _extractor = extractor ?? PdfTextExtractorService();

  final SharedPreferences prefs;
  final LabPdfParser _parser;
  final PdfTextExtractorService _extractor;

  final List<ExamReport> _reports = [];

  List<ExamReport> get reports {
    final sorted = [..._reports];
    sorted.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    return sorted;
  }

  bool get hasReports => _reports.isNotEmpty;

  Future<void> load() async {
    _reports.clear();
    final raw = prefs.getString(_reportsKey);
    if (raw == null || raw.isEmpty) return;
    final list = jsonDecode(raw) as List<dynamic>;
    for (final item in list) {
      _reports.add(ExamReport.fromJson(item as Map<String, dynamic>));
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_reports.map((e) => e.toJson()).toList());
    await prefs.setString(_reportsKey, encoded);
  }

  Future<ExamReport> importPdfFile(File file) async {
    final text = await _extractor.fromFile(file);
    final report = _parser.parse(
      text,
      sourceFileName: file.uri.pathSegments.last,
    );
    _reports.add(report);
    await _persist();
    return report;
  }

  Future<ExamReport> importPdfBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final text = await _extractor.fromBytes(bytes);
    final report = _parser.parse(text, sourceFileName: fileName);
    _reports.add(report);
    await _persist();
    return report;
  }

  Future<ExamReport> importSample() async {
    final report = _parser.parse(
      sampleExamPdfText,
      sourceFileName: 'exame-exemplo.pdf',
    );
    _reports.add(report);
    await _persist();
    return report;
  }

  Future<void> deleteReport(String id) async {
    _reports.removeWhere((r) => r.id == id);
    await _persist();
  }

  ExamReport? getById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  List<MarkerSeries> buildSeries() {
    final map = <String, _SeriesBuilder>{};

    for (final report in reports.reversed) {
      for (final marker in report.markers) {
        final key = marker.name.toLowerCase();
        final builder = map.putIfAbsent(
          key,
          () => _SeriesBuilder(
            name: marker.name,
            unit: marker.unit,
            category: marker.category,
            referenceMin: marker.referenceMin,
            referenceMax: marker.referenceMax,
            referenceText: marker.referenceText,
          ),
        );

        for (final prev in marker.previousValues) {
          builder.addPoint(prev);
        }
        builder.addPoint(
          HistoricalValue(date: marker.collectedAt, value: marker.value),
        );

        builder.referenceMin ??= marker.referenceMin;
        builder.referenceMax ??= marker.referenceMax;
        builder.referenceText ??= marker.referenceText;
      }
    }

    final series = map.values.map((b) => b.build()).toList();
    series.sort((a, b) => a.name.compareTo(b.name));
    return series;
  }

  MarkerSeries? seriesFor(String name) {
    try {
      return buildSeries().firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  DashboardSummary summary() {
    final series = buildSeries();
    final outOfRange = series
        .where(
          (s) =>
              s.latestStatus == MarkerStatus.low ||
              s.latestStatus == MarkerStatus.high,
        )
        .toList();
    return DashboardSummary(
      totalMarkers: series.length,
      outOfRange: outOfRange,
      reportCount: _reports.length,
      lastCollectedAt: reports.isEmpty ? null : reports.first.collectedAt,
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalMarkers,
    required this.outOfRange,
    required this.reportCount,
    this.lastCollectedAt,
  });

  final int totalMarkers;
  final List<MarkerSeries> outOfRange;
  final int reportCount;
  final DateTime? lastCollectedAt;
}

class _SeriesBuilder {
  _SeriesBuilder({
    required this.name,
    required this.unit,
    required this.category,
    this.referenceMin,
    this.referenceMax,
    this.referenceText,
  });

  final String name;
  final String unit;
  final String category;
  double? referenceMin;
  double? referenceMax;
  String? referenceText;
  final _points = <String, HistoricalValue>{};

  void addPoint(HistoricalValue point) {
    final key =
        '${point.date.year}-${point.date.month}-${point.date.day}-${point.value}';
    _points[key] = point;
  }

  MarkerSeries build() {
    final points = _points.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return MarkerSeries(
      name: name,
      unit: unit,
      category: category,
      points: points,
      referenceMin: referenceMin,
      referenceMax: referenceMax,
      referenceText: referenceText,
    );
  }
}
