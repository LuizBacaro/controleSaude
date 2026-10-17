import 'package:intl/intl.dart';

enum MarkerStatus { normal, low, high, altered, unknown }

String formatLabNumber(double value) {
  if (value >= 1000) {
    return NumberFormat.decimalPattern('pt_BR').format(value.round());
  }
  final fixed = value.toStringAsFixed(3);
  final trimmed = fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return trimmed.replaceAll('.', ',');
}

String _fold(String raw) {
  const from = 'áàâãéêíóôõúç';
  const to = 'aaaaeeiooouc';
  final buffer = StringBuffer();
  for (final char in raw.toLowerCase().trim().split('')) {
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}

MarkerStatus statusForValue({
  String? text,
  required double value,
  double? referenceMin,
  double? referenceMax,
  String? referenceText,
}) {
  if (text != null && text.trim().isNotEmpty) {
    if (referenceText == null || referenceText.trim().isEmpty) {
      return MarkerStatus.unknown;
    }
    return _fold(text) == _fold(referenceText)
        ? MarkerStatus.normal
        : MarkerStatus.altered;
  }
  if (referenceMin != null && value < referenceMin) return MarkerStatus.low;
  if (referenceMax != null && value > referenceMax) return MarkerStatus.high;
  if (referenceMin != null || referenceMax != null) return MarkerStatus.normal;
  return MarkerStatus.unknown;
}

/// Um valor medido (ex.: Hemoglobina 16,1 g/dL).
class ExamMarker {
  const ExamMarker({
    required this.id,
    required this.name,
    required this.value,
    required this.unit,
    required this.collectedAt,
    this.category = 'Geral',
    this.textValue,
    this.referenceText,
    this.referenceMin,
    this.referenceMax,
    this.previousValues = const [],
  });

  final String id;
  final String name;
  final double value;
  final String? textValue;
  final String unit;
  final DateTime collectedAt;
  final String category;
  final String? referenceText;
  final double? referenceMin;
  final double? referenceMax;
  final List<HistoricalValue> previousValues;

  bool get isQualitative => textValue != null && textValue!.trim().isNotEmpty;

  String get resultLabel {
    if (isQualitative) return textValue!.trim();
    final number = formatLabNumber(value);
    return unit.isEmpty ? number : '$number $unit';
  }

  MarkerStatus get status => statusForValue(
    text: textValue,
    value: value,
    referenceMin: referenceMin,
    referenceMax: referenceMax,
    referenceText: referenceText,
  );

  String get statusLabel => switch (status) {
    MarkerStatus.normal => 'Normal',
    MarkerStatus.low => 'Baixo',
    MarkerStatus.high => 'Alto',
    MarkerStatus.altered => 'Alterado',
    MarkerStatus.unknown => '—',
  };

  ExamMarker copyWith({List<HistoricalValue>? previousValues}) {
    return ExamMarker(
      id: id,
      name: name,
      value: value,
      textValue: textValue,
      unit: unit,
      collectedAt: collectedAt,
      category: category,
      referenceText: referenceText,
      referenceMin: referenceMin,
      referenceMax: referenceMax,
      previousValues: previousValues ?? this.previousValues,
    );
  }

  /// Série temporal: anteriores + valor atual, ordenada por data.
  List<HistoricalValue> get timeline {
    final all = [
      ...previousValues,
      HistoricalValue(
        date: collectedAt,
        value: value,
        text: textValue,
        origin: ValueOrigin.imported,
      ),
    ];
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  factory ExamMarker.fromJson(Map<String, dynamic> json) => ExamMarker(
    id: json['id'] as String,
    name: json['name'] as String,
    value: (json['value'] as num).toDouble(),
    textValue: json['text_value'] as String?,
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
    'text_value': textValue,
    'unit': unit,
    'collected_at': collectedAt.toIso8601String(),
    'category': category,
    'reference_text': referenceText,
    'reference_min': referenceMin,
    'reference_max': referenceMax,
    'previous_values': previousValues.map((e) => e.toJson()).toList(),
  };
}

enum ValueOrigin {
  /// Valor da coleta deste PDF importado.
  imported,

  /// Valor que o laboratório citou como resultado anterior dentro do PDF.
  citedInReport,
}

class HistoricalValue {
  const HistoricalValue({
    required this.date,
    required this.value,
    this.text,
    this.origin = ValueOrigin.citedInReport,
  });

  final DateTime date;
  final double value;
  final String? text;
  final ValueOrigin origin;

  bool get isQualitative => text != null && text!.trim().isNotEmpty;

  String label(String unit) {
    if (isQualitative) return text!.trim();
    final number = formatLabNumber(value);
    return unit.isEmpty ? number : '$number $unit';
  }

  factory HistoricalValue.fromJson(Map<String, dynamic> json) =>
      HistoricalValue(
        date: DateTime.parse(json['date'] as String),
        value: (json['value'] as num).toDouble(),
        text: json['text'] as String?,
        origin: json['origin'] == 'imported'
            ? ValueOrigin.imported
            : ValueOrigin.citedInReport,
      );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'value': value,
    'text': text,
    'origin': origin == ValueOrigin.imported ? 'imported' : 'cited',
  };
}
