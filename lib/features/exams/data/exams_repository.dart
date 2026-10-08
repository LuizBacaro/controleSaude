import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exam_marker.dart';
import '../domain/exam_report.dart';
import 'lab_pdf_parser.dart';
import 'pdf_text_extractor.dart';
import 'sample_exam_text.dart';

const _reportsKey = 'exame_facil_reports';
const _migratedKey = 'exame_facil_reports_migrated';

class ExamsRepository {
  ExamsRepository({
    required this.prefs,
    SupabaseClient? client,
    LabPdfParser? parser,
    PdfTextExtractorService? extractor,
  }) : _client = client ?? Supabase.instance.client,
       _parser = parser ?? LabPdfParser(),
       _extractor = extractor ?? PdfTextExtractorService();

  final SharedPreferences prefs;
  final SupabaseClient _client;
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
    try {
      final remote = await _fetchRemote();
      if (remote.isEmpty && prefs.getBool(_migratedKey) != true) {
        final local = _readLocal();
        for (final report in local) {
          await _insertReport(report);
        }
        await prefs.setBool(_migratedKey, true);
        await prefs.remove(_reportsKey);
        _reports
          ..clear()
          ..addAll(local);
        return;
      }
      await prefs.setBool(_migratedKey, true);
      await prefs.remove(_reportsKey);
      _reports
        ..clear()
        ..addAll(remote);
    } catch (_) {
      _reports
        ..clear()
        ..addAll(_readLocal());
    }
  }

  Future<ExamReport> importPdfFile(File file) async {
    final text = await _extractor.fromFile(file);
    final report = _parser.parse(
      text,
      sourceFileName: file.uri.pathSegments.last,
    );
    await _insertReport(report);
    _reports.add(report);
    return report;
  }

  Future<ExamReport> importPdfBytes(Uint8List bytes, {String? fileName}) async {
    final text = await _extractor.fromBytes(bytes);
    final report = _parser.parse(text, sourceFileName: fileName);
    await _insertReport(report);
    _reports.add(report);
    return report;
  }

  Future<ExamReport> importSample() async {
    final report = _parser.parse(
      sampleExamPdfText,
      sourceFileName: 'exame-exemplo.pdf',
    );
    await _insertReport(report);
    _reports.add(report);
    return report;
  }

  Future<void> deleteReport(String id) async {
    await _client.from('exam_reports').delete().eq('id', id);
    _reports.removeWhere((r) => r.id == id);
  }

  ExamReport? getById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ExamReport> _readLocal() {
    final raw = prefs.getString(_reportsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        ExamReport.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<ExamReport>> _fetchRemote() async {
    final reportRows = await _client
        .from('exam_reports')
        .select()
        .order('collected_at', ascending: false);
    final resultRows = await _client.from('exam_results').select();
    final byReport = <String, List<Map<String, dynamic>>>{};
    for (final row in resultRows) {
      final map = Map<String, dynamic>.from(row);
      byReport.putIfAbsent(map['report_id'] as String, () => []).add(map);
    }
    return [
      for (final row in reportRows)
        _reportFromRows(
          Map<String, dynamic>.from(row),
          byReport[row['id'] as String] ?? const [],
        ),
    ];
  }

  ExamReport _reportFromRows(
    Map<String, dynamic> report,
    List<Map<String, dynamic>> rows,
  ) {
    final byMarker = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      byMarker.putIfAbsent(row['marker_id'] as String, () => []).add(row);
    }
    final markers = <ExamMarker>[];
    for (final group in byMarker.values) {
      final current = group.firstWhere(
        (row) => row['is_current'] == true,
        orElse: () => group.first,
      );
      final previous = group
          .where((row) => row['is_current'] != true)
          .map(
            (row) => HistoricalValue(
              date: DateTime.parse(row['collected_at'] as String),
              value: (row['value'] as num).toDouble(),
              origin: row['origin'] == 'imported'
                  ? ValueOrigin.imported
                  : ValueOrigin.citedInReport,
            ),
          )
          .toList();
      markers.add(
        ExamMarker(
          id: current['marker_id'] as String,
          name: current['marker_name'] as String,
          value: (current['value'] as num).toDouble(),
          unit: current['unit'] as String? ?? '',
          collectedAt: DateTime.parse(current['collected_at'] as String),
          category: current['category'] as String? ?? 'Geral',
          referenceText: current['reference_text'] as String?,
          referenceMin: (current['reference_min'] as num?)?.toDouble(),
          referenceMax: (current['reference_max'] as num?)?.toDouble(),
          previousValues: previous,
        ),
      );
    }
    return ExamReport(
      id: report['id'] as String,
      collectedAt: DateTime.parse(report['collected_at'] as String),
      importedAt: DateTime.parse(report['imported_at'] as String),
      patientName: report['patient_name'] as String?,
      labName: report['lab_name'] as String?,
      sourceFileName: report['source_file_name'] as String?,
      notes: report['notes'] as String?,
      markers: markers,
    );
  }

  Future<void> _insertReport(ExamReport report) async {
    await _client.from('exam_reports').upsert({
      'id': report.id,
      'collected_at': report.collectedAt.toUtc().toIso8601String(),
      'imported_at': report.importedAt.toUtc().toIso8601String(),
      'patient_name': report.patientName,
      'lab_name': report.labName,
      'source_file_name': report.sourceFileName,
      'notes': report.notes,
    });
    await _client.from('exam_results').delete().eq('report_id', report.id);
    final rows = <Map<String, dynamic>>[];
    for (final marker in report.markers) {
      rows.add(
        _resultRow(
          report.id,
          marker,
          marker.value,
          marker.collectedAt,
          true,
          ValueOrigin.imported,
        ),
      );
      for (final previous in marker.previousValues) {
        rows.add(
          _resultRow(
            report.id,
            marker,
            previous.value,
            previous.date,
            false,
            previous.origin,
          ),
        );
      }
    }
    if (rows.isNotEmpty) {
      await _client.from('exam_results').insert(rows);
    }
  }

  Map<String, dynamic> _resultRow(
    String reportId,
    ExamMarker marker,
    double value,
    DateTime collectedAt,
    bool isCurrent,
    ValueOrigin origin,
  ) {
    return {
      'report_id': reportId,
      'marker_id': marker.id,
      'marker_name': marker.name,
      'value': value,
      'unit': marker.unit,
      'collected_at': collectedAt.toUtc().toIso8601String(),
      'category': marker.category,
      'reference_text': marker.referenceText,
      'reference_min': marker.referenceMin,
      'reference_max': marker.referenceMax,
      'origin': origin == ValueOrigin.imported ? 'imported' : 'cited',
      'is_current': isCurrent,
    };
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
          HistoricalValue(
            date: marker.collectedAt,
            value: marker.value,
            origin: ValueOrigin.imported,
          ),
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
    final existing = _points[key];
    if (existing != null &&
        existing.origin == ValueOrigin.imported &&
        point.origin == ValueOrigin.citedInReport) {
      return;
    }
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
