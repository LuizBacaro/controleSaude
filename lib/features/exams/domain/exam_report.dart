import 'exam_marker.dart';

/// Um laudo completo importado de um PDF (uma coleta).
class ExamReport {
  const ExamReport({
    required this.id,
    required this.collectedAt,
    required this.importedAt,
    required this.markers,
    this.patientName,
    this.labName,
    this.doctorName,
    this.insuranceName,
    this.sourceFileName,
    this.notes,
    this.unrecognized = const [],
  });

  final String id;
  final DateTime collectedAt;
  final DateTime importedAt;
  final List<ExamMarker> markers;
  final String? patientName;
  final String? labName;
  final String? doctorName;
  final String? insuranceName;
  final String? sourceFileName;
  final String? notes;

  /// Trechos do PDF que pareciam exame e não viraram marcador.
  final List<String> unrecognized;

  int get markerCount => markers.length;

  ExamReport withMarkers(List<ExamMarker> kept) => ExamReport(
    id: id,
    collectedAt: collectedAt,
    importedAt: importedAt,
    markers: kept,
    patientName: patientName,
    labName: labName,
    doctorName: doctorName,
    insuranceName: insuranceName,
    sourceFileName: sourceFileName,
    notes: notes,
    unrecognized: unrecognized,
  );

  int get outOfRangeCount => markers
      .where(
        (m) =>
            m.status == MarkerStatus.low ||
            m.status == MarkerStatus.high ||
            m.status == MarkerStatus.altered,
      )
      .length;

  List<String> get categories {
    final set = <String>{};
    for (final m in markers) {
      set.add(m.category);
    }
    return set.toList()..sort();
  }

  factory ExamReport.fromJson(Map<String, dynamic> json) => ExamReport(
    id: json['id'] as String,
    collectedAt: DateTime.parse(json['collected_at'] as String),
    importedAt: DateTime.parse(json['imported_at'] as String),
    patientName: json['patient_name'] as String?,
    labName: json['lab_name'] as String?,
    doctorName: json['doctor_name'] as String?,
    insuranceName: json['insurance_name'] as String?,
    sourceFileName: json['source_file_name'] as String?,
    notes: json['notes'] as String?,
    unrecognized: (json['unrecognized'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
    markers: (json['markers'] as List<dynamic>)
        .map((e) => ExamMarker.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'collected_at': collectedAt.toIso8601String(),
    'imported_at': importedAt.toIso8601String(),
    'patient_name': patientName,
    'lab_name': labName,
    'doctor_name': doctorName,
    'insurance_name': insuranceName,
    'source_file_name': sourceFileName,
    'notes': notes,
    'unrecognized': unrecognized,
    'markers': markers.map((e) => e.toJson()).toList(),
  };
}

/// Visão agregada de um marcador ao longo de vários laudos.
class MarkerSeries {
  const MarkerSeries({
    required this.name,
    required this.unit,
    required this.category,
    required this.points,
    this.referenceMin,
    this.referenceMax,
    this.referenceText,
  });

  final String name;
  final String unit;
  final String category;
  final List<HistoricalValue> points;
  final double? referenceMin;
  final double? referenceMax;
  final String? referenceText;

  HistoricalValue? get latest => points.isEmpty ? null : points.last;

  bool get qualitative => latest != null && latest!.isQualitative;

  String get latestLabel => latest?.label(unit) ?? '—';

  MarkerStatus get latestStatus {
    final point = latest;
    if (point == null) return MarkerStatus.unknown;
    return statusForValue(
      text: point.text,
      value: point.value,
      referenceMin: referenceMin,
      referenceMax: referenceMax,
      referenceText: referenceText,
    );
  }

  double? get delta {
    if (points.length < 2) return null;
    if (points.last.isQualitative || points[points.length - 2].isQualitative) {
      return null;
    }
    return points.last.value - points[points.length - 2].value;
  }

  /// Variação em relação à coleta anterior (0,1 = 10%).
  double? get relativeChange {
    final change = delta;
    if (change == null) return null;
    final before = points[points.length - 2].value;
    if (before == 0) return null;
    return change / before.abs();
  }
}
