enum MarkerStatus { normal, low, high, unknown }

/// Um valor medido (ex.: Hemoglobina 16,1 g/dL).
class ExamMarker {
  const ExamMarker({
    required this.id,
    required this.name,
    required this.value,
    required this.unit,
    required this.collectedAt,
    this.category = 'Geral',
    this.referenceText,
    this.referenceMin,
    this.referenceMax,
    this.previousValues = const [],
  });

  final String id;
  final String name;
  final double value;
  final String unit;
  final DateTime collectedAt;
  final String category;
  final String? referenceText;
  final double? referenceMin;
  final double? referenceMax;
  final List<HistoricalValue> previousValues;

  MarkerStatus get status {
    if (referenceMin != null && value < referenceMin!) return MarkerStatus.low;
    if (referenceMax != null && value > referenceMax!) return MarkerStatus.high;
    if (referenceMin != null || referenceMax != null) return MarkerStatus.normal;
    return MarkerStatus.unknown;
  }

  String get statusLabel => switch (status) {
        MarkerStatus.normal => 'Normal',
        MarkerStatus.low => 'Baixo',
        MarkerStatus.high => 'Alto',
        MarkerStatus.unknown => '—',
      };

  /// Série temporal: anteriores + valor atual, ordenada por data.
  List<HistoricalValue> get timeline {
    final all = [...previousValues, HistoricalValue(date: collectedAt, value: value)];
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  factory ExamMarker.fromJson(Map<String, dynamic> json) => ExamMarker(
        id: json['id'] as String,
        name: json['name'] as String,
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String? ?? '',
        collectedAt: DateTime.parse(json['collected_at'] as String),
        category: json['category'] as String? ?? 'Geral',
        referenceText: json['reference_text'] as String?,
        referenceMin: (json['reference_min'] as num?)?.toDouble(),
        referenceMax: (json['reference_max'] as num?)?.toDouble(),
        previousValues: (json['previous_values'] as List<dynamic>? ?? [])
            .map((e) => HistoricalValue.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'unit': unit,
        'collected_at': collectedAt.toIso8601String(),
        'category': category,
        'reference_text': referenceText,
        'reference_min': referenceMin,
        'reference_max': referenceMax,
        'previous_values': previousValues.map((e) => e.toJson()).toList(),
      };
}

class HistoricalValue {
  const HistoricalValue({required this.date, required this.value});

  final DateTime date;
  final double value;

  factory HistoricalValue.fromJson(Map<String, dynamic> json) => HistoricalValue(
        date: DateTime.parse(json['date'] as String),
        value: (json['value'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'value': value,
      };
}
