import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../domain/exam_marker.dart';
import '../domain/exam_report.dart';

/// Extrai marcadores de laudos no formato Unilab / laboratórios BR.
class LabPdfParser {
  LabPdfParser({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  ExamReport parse(
    String text, {
    String? sourceFileName,
  }) {
    final cleaned = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    final collectedAt = _extractCollectionDate(cleaned);
    if (collectedAt == null) {
      throw FormatException(
        'Não foi possível encontrar a data de atendimento no PDF '
        '(Data atend. ou Coleta).',
      );
    }
    final patientName = _extractPatientName(cleaned);
    final labName = cleaned.contains('Unilab') ? 'Unilab' : null;

    final markers = <ExamMarker>[
      ..._parseHemogram(cleaned, collectedAt),
      ..._parseSimpleResults(cleaned, collectedAt),
      ..._parseLipidPanel(cleaned, collectedAt),
      ..._parseCoagulation(cleaned, collectedAt),
    ];

    // Deduplica por nome (mantém o primeiro).
    final seen = <String>{};
    final unique = <ExamMarker>[];
    for (final m in markers) {
      final key = m.name.toLowerCase();
      if (seen.add(key)) unique.add(m);
    }

    if (unique.isEmpty) {
      throw FormatException(
        'Não foi possível extrair resultados do PDF. '
        'Verifique se o arquivo é um laudo de laboratório em texto.',
      );
    }

    var reportDate = collectedAt;
    for (final marker in unique) {
      if (marker.collectedAt.isAfter(reportDate)) {
        reportDate = marker.collectedAt;
      }
    }

    return ExamReport(
      id: _uuid.v4(),
      collectedAt: reportDate,
      importedAt: DateTime.now(),
      markers: unique,
      patientName: patientName,
      labName: labName,
      sourceFileName: sourceFileName,
    );
  }

  DateTime _dateNear(String text, int index, DateTime fallback) {
    final head = text.substring(0, index.clamp(0, text.length));
    final matches = RegExp(
      r'Coleta:\s*(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    ).allMatches(head);
    if (matches.isEmpty) return fallback;
    return _tryParseDate(matches.last.group(1)!) ?? fallback;
  }

  DateTime? _extractCollectionDate(String text) {
    final adjacent = RegExp(
      r'Data\s+atend\.?\s*:?\s*(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    final adjacentDate = adjacent == null
        ? null
        : _tryParseDate(adjacent.group(1)!);
    if (adjacentDate != null) return adjacentDate;

    // No laudo Unilab o rótulo fica numa coluna e o valor noutra.
    final label = RegExp(
      r'Data\s+atend',
      caseSensitive: false,
    ).firstMatch(text);
    if (label != null) {
      final dated = RegExp(
        r'(\d{2}/\d{2}/\d{4})\s*-\s*\d{2}:\d{2}',
      ).firstMatch(text.substring(label.end));
      final parsed = dated == null ? null : _tryParseDate(dated.group(1)!);
      if (parsed != null) return parsed;
    }

    final coleta = RegExp(
      r'Coleta:\s*(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (coleta == null) return null;
    return _tryParseDate(coleta.group(1)!);
  }

  String? _extractPatientName(String text) {
    final m = RegExp(r'Nome\s*:\s*([A-ZÁÉÍÓÚÂÊÔÃÕÇ ]{5,})').firstMatch(text);
    return m?.group(1)?.trim();
  }

  List<ExamMarker> _parseHemogram(String text, DateTime collectedAt) {
    final markers = <ExamMarker>[];
    const category = 'Hemograma';

    void add(
      String name,
      String pattern,
      String unit, {
      double? min,
      double? max,
      String? refText,
    }) {
      final m = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (m == null) return;
      final value = _parseNumber(m.group(1)!);
      if (value == null) return;
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: name,
          value: value,
          unit: unit,
          collectedAt: _dateNear(text, m.end, collectedAt),
          category: category,
          referenceMin: min,
          referenceMax: max,
          referenceText: refText,
          previousValues: _extractPreviousNear(text, name),
        ),
      );
    }

    add('Hemácias', r'Hem[aá]cias[.\s]*:\s*([\d.,]+)', 'milhões/mm³',
        min: 4.5, max: 6.0, refText: '4,5 a 6,0 milhões/mm³');
    add('Hemoglobina', r'Hemoglobina[.\s]*:\s*([\d.,]+)\s*g/dL', 'g/dL',
        min: 13.0, max: 17.0, refText: '13,0 a 17,0 g/dL');
    add('Hematócrito', r'Hemat[oó]crito[.\s]*:\s*([\d.,]+)', '%',
        min: 38, max: 52, refText: '38 a 52 %');
    add('V.C.M', r'V\.?C\.?M[.\s]*:\s*([\d.,]+)', 'fL', min: 82, max: 98);
    add('H.C.M', r'H\.?C\.?M[.\s]*:\s*([\d.,]+)', 'pg', min: 27, max: 32);
    add('C.H.C.M', r'(?:C\.?H\.?C\.?M|CHCM)[.\s]*:\s*([\d.,]+)', 'g/dL',
        min: 32, max: 36);
    add('R.D.W', r'R\.?D\.?W[.\s]*:\s*([\d.,]+)', '%', max: 14.5);
    add(
      'Leucócitos',
      r'Leuc[oó]citos(?:[\s\S]{0,24}?TOTAIS)?[.\s]*:\s*([\d.]+)',
      '/mm³',
      min: 4500,
      max: 11000,
      refText: '4.500 a 11.000 /mm³',
    );
    add(
      'Plaquetas',
      r'(?:Contagem de plaquetas|Plaquetas)[.\s]*:\s*([\d.]+)',
      '/mm³',
      min: 150000,
      max: 450000,
      refText: '150.000 a 450.000 /mm³',
    );
    add('Segmentados', r'Segmentados[.\s]*:\s*([\d.,]+)\s*%', '%',
        min: 50, max: 67);
    add('Linfócitos', r'Linf[oó]citos[.\s]*:\s*([\d.,]+)\s*%', '%',
        min: 20, max: 40);
    add('Monócitos', r'Mon[oó]citos[.\s]*:\s*([\d.,]+)\s*%', '%',
        min: 4, max: 10);
    add('Eosinófilos', r'Eosin[oó]filos[.\s]*:\s*([\d.,]+)\s*%', '%',
        min: 1, max: 4);
    add('Basófilos', r'Bas[oó]filos[.\s]*:\s*([\d.,]+)\s*%', '%',
        min: 0, max: 1);

    return markers;
  }

  List<ExamMarker> _parseCoagulation(String text, DateTime collectedAt) {
    final markers = <ExamMarker>[];
    const category = 'Coagulação';

    void tryAdd(String name, RegExp pattern, String unit,
        {double? min, double? max, String? refText}) {
      final m = pattern.firstMatch(text);
      if (m == null) return;
      final value = _parseNumber(m.group(1)!);
      if (value == null) return;
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: name,
          value: value,
          unit: unit,
          collectedAt: _dateNear(text, m.end, collectedAt),
          category: category,
          referenceMin: min,
          referenceMax: max,
          referenceText: refText,
          previousValues: _extractPreviousBlock(text, name),
        ),
      );
    }

    tryAdd(
      'Tempo de Protrombina',
      RegExp(r'Tempo de Protrombina:\s*([\d.,]+)\s*segundos', caseSensitive: false),
      'segundos',
      min: 10,
      max: 15,
    );
    tryAdd(
      'Atividade TAP',
      RegExp(r'Atividade:\s*([\d.,]+)\s*%', caseSensitive: false),
      '%',
      min: 70,
      max: 100,
    );
    tryAdd(
      'INR',
      RegExp(r'INR:\s*([\d.,]+)', caseSensitive: false),
      '',
      min: 1.0,
      max: 1.25,
      refText: '1,00 a 1,25 (terapêutico Varfarina: 2,5–3,5)',
    );
    tryAdd(
      'TTPA',
      RegExp(r'Tempo de Tromboplastina:\s*([\d.,]+)\s*segundos', caseSensitive: false),
      'segundos',
      min: 22,
      max: 31,
    );
    tryAdd(
      'TTPA Ratio',
      RegExp(r'Ratio:\s*([\d.,]+)', caseSensitive: false),
      '',
    );

    return markers;
  }

  List<ExamMarker> _parseLipidPanel(String text, DateTime collectedAt) {
    final markers = <ExamMarker>[];
    const category = 'Lipídico';

    void tryAdd(String name, RegExp pattern, String unit,
        {double? min, double? max, String? refText}) {
      final m = pattern.firstMatch(text);
      if (m == null) return;
      final value = _parseNumber(m.group(1)!);
      if (value == null) return;
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: name,
          value: value,
          unit: unit,
          collectedAt: _dateNear(text, m.end, collectedAt),
          category: category,
          referenceMin: min,
          referenceMax: max,
          referenceText: refText,
          previousValues: _extractPreviousBlock(text, name),
        ),
      );
    }

    tryAdd(
      'Colesterol Total',
      RegExp(
        r'(?:Colesterol Total:\s*|COLESTEROL\s+TOTAL(?!\s+e)[\s\S]{0,500}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 190,
      refText: 'Desejável inferior a 190 mg/dL',
    );
    tryAdd(
      'Colesterol HDL',
      RegExp(
        r'(?:Colesterol HDL:\s*|HDL[\s\S]{0,40}?COLESTEROL[\s\S]{0,500}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      min: 40,
      refText: 'Desejável superior a 40 mg/dL',
    );
    tryAdd(
      'Colesterol LDL',
      RegExp(
        r'(?:Colesterol LDL:\s*|COLESTEROL\s+LDL[\s\S]{0,300}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 100,
      refText: 'Ótimo: menor que 100 mg/dL',
    );
    tryAdd(
      'Colesterol VLDL',
      RegExp(
        r'(?:Colesterol VLDL:\s*|COLESTEROL\s+VLDL[\s\S]{0,300}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 30,
    );
    tryAdd(
      'Colesterol não HDL',
      RegExp(r'Colesterol n[aã]o HDL:\s*([\d.,]+)\s*mg/dL', caseSensitive: false),
      'mg/dL',
      max: 130,
    );
    tryAdd(
      'Índice de Castelli',
      RegExp(r'[ÍI]ndice de Castelli:\s*([\d.,]+)', caseSensitive: false),
      '',
      max: 3.4,
    );
    tryAdd(
      'Triglicerídeos',
      RegExp(
        r'Triglic(?:er[ií]deos|[eé]rides)[\s\S]{0,500}?Resultado[.\s]*:\s*([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 150,
      refText: 'Desejável inferior a 150 mg/dL',
    );

    return markers;
  }

  List<ExamMarker> _parseSimpleResults(String text, DateTime collectedAt) {
    final specs = <_MarkerSpec>[
      _MarkerSpec(
        name: 'Glicose',
        category: 'Metabolismo',
        pattern: RegExp(
          r'Glicose[\s\S]{0,500}?Resultado[.\s]*:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        min: 70,
        max: 99,
        refText: '70 a 99 mg/dL',
      ),
      _MarkerSpec(
        name: 'Hemoglobina glicada (HbA1c)',
        category: 'Metabolismo',
        pattern: RegExp(
          r'Hemoglobina glicada[\s\S]{0,400}?Resultado:\s*([\d.,]+)\s*%',
          caseSensitive: false,
        ),
        unit: '%',
        max: 5.7,
        refText: 'Inferior a 5,7%',
      ),
      _MarkerSpec(
        name: 'Glicemia média estimada',
        category: 'Metabolismo',
        pattern: RegExp(
          r'Glicemia m[eé]dia estimada:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
      ),
      _MarkerSpec(
        name: 'Creatinina',
        category: 'Renal',
        pattern: RegExp(
          r'Creatinina[\s\S]{0,200}?Resultado:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        min: 0.76,
        max: 1.24,
        refText: 'Homens adultos: 0,76 a 1,24 mg/dL',
      ),
      _MarkerSpec(
        name: 'Ácido úrico',
        category: 'Metabolismo',
        pattern: RegExp(
          r'[ÁA]cido[\s\S]{0,20}?[uú]rico[\s\S]{0,500}?Resultado[.\s]*:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        min: 3.4,
        max: 7.0,
        refText: 'Homens: 3,4 a 7,0 mg/dL',
      ),
      _MarkerSpec(
        name: 'Potássio',
        category: 'Eletrólitos',
        pattern: RegExp(
          r'Pot[aá]ssio[\s\S]{0,200}?Resultado:\s*([\d.,]+)\s*mmol/L',
          caseSensitive: false,
        ),
        unit: 'mmol/L',
        min: 3.5,
        max: 5.1,
      ),
      _MarkerSpec(
        name: 'AST/TGO',
        category: 'Hepático',
        pattern: RegExp(
          r'(?:AST/TGO|oxalac[eé]tica)[\s\S]{0,200}?Resultado:\s*([\d.,]+)\s*U/L',
          caseSensitive: false,
        ),
        unit: 'U/L',
        max: 40,
        refText: 'Homens: até 40 U/L',
      ),
      _MarkerSpec(
        name: 'ALT/TGP',
        category: 'Hepático',
        pattern: RegExp(
          r'(?:ALT/TGP|pir[uú]vica)[\s\S]{0,200}?Resultado:\s*([\d.,]+)\s*U/L',
          caseSensitive: false,
        ),
        unit: 'U/L',
        max: 41,
        refText: 'Homens: até 41 U/L',
      ),
      _MarkerSpec(
        name: 'Fosfatase alcalina',
        category: 'Hepático',
        pattern: RegExp(
          r'Fosfatase alcalina[\s\S]{0,300}?Resultado[.\s]*:\s*([\d.,]+)\s*U/L',
          caseSensitive: false,
        ),
        unit: 'U/L',
        min: 40,
        max: 129,
        refText: 'Homens adultos: 40 a 129 U/L',
      ),
      _MarkerSpec(
        name: 'GGT',
        category: 'Hepático',
        pattern: RegExp(
          r'(?:GGT|Gama Glutamil)[\s\S]{0,300}?Resultado[.\s]*:\s*([\d.,]+)\s*U/L',
          caseSensitive: false,
        ),
        unit: 'U/L',
        min: 10,
        max: 71,
        refText: 'Homens: 10 a 71 U/L',
      ),
      _MarkerSpec(
        name: 'Bilirrubina direta',
        category: 'Hepático',
        pattern: RegExp(
          r'Bilirrubina direta:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        max: 0.40,
        refText: 'Inferior ou igual a 0,40 mg/dL',
      ),
      _MarkerSpec(
        name: 'Bilirrubina indireta',
        category: 'Hepático',
        pattern: RegExp(
          r'Bilirrubina indireta:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        max: 0.80,
        refText: 'Inferior ou igual a 0,80 mg/dL',
      ),
      _MarkerSpec(
        name: 'Bilirrubina total',
        category: 'Hepático',
        pattern: RegExp(
          r'Bilirrubina total:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        min: 0.30,
        max: 1.20,
        refText: '0,30 a 1,20 mg/dL',
      ),
      _MarkerSpec(
        name: 'Vitamina D',
        category: 'Vitaminas',
        pattern: RegExp(
          r'Vitamina D[\s\S]{0,300}?Resultado[.\s]*:\s*([\d.,]+)\s*ng/mL',
          caseSensitive: false,
        ),
        unit: 'ng/mL',
        min: 20,
        max: 60,
        refText: 'Adequado: 20 a 60 ng/mL',
      ),
      _MarkerSpec(
        name: 'Vitamina B12',
        category: 'Vitaminas',
        pattern: RegExp(
          r'Vitamina[\s\S]{0,20}?B12[\s\S]{0,400}?Resultado[.\s]*:\s*([\d.,]+)\s*pg/mL',
          caseSensitive: false,
        ),
        unit: 'pg/mL',
        min: 181,
        max: 906,
        refText: '181 a 906 pg/mL',
      ),
      _MarkerSpec(
        name: 'Ferritina',
        category: 'Ferro',
        pattern: RegExp(
          r'Ferritina[\s\S]{0,400}?Resultado[.\s]*:\s*([\d.,]+)\s*ng/mL',
          caseSensitive: false,
        ),
        unit: 'ng/mL',
        min: 30,
        max: 400,
        refText: 'Homens: 30 a 400 ng/mL',
      ),
      _MarkerSpec(
        name: 'TSH',
        category: 'Tireoide',
        pattern: RegExp(
          r'TSH[\s\S]{0,200}?Resultado:\s*([\d.,]+)\s*microUI/mL',
          caseSensitive: false,
        ),
        unit: 'microUI/mL',
        min: 0.35,
        max: 4.94,
        refText: 'Adultos: 0,35 a 4,94 microUI/mL',
      ),
      _MarkerSpec(
        name: 'PCR ultrassensível',
        category: 'Inflamação',
        pattern: RegExp(
          r'Prote[ií]na C Reativa[\s\S]{0,250}?Resultado:\s*([\d.,]+)\s*mg/L',
          caseSensitive: false,
        ),
        unit: 'mg/L',
        max: 2.0,
        refText: 'Risco cardiovascular: inferior a 2,00 mg/L',
      ),
      _MarkerSpec(
        name: 'Lipoproteína A',
        category: 'Lipídico',
        pattern: RegExp(
          r'Lipoprote[ií]na A[\s\S]{0,200}?Resultado:\s*([\d.,]+)\s*nmol/L',
          caseSensitive: false,
        ),
        unit: 'nmol/L',
        max: 75,
        refText: 'Inferior a 75 nmol/L',
      ),
    ];

    final markers = <ExamMarker>[];
    for (final spec in specs) {
      final m = spec.pattern.firstMatch(text);
      if (m == null) continue;
      final value = _parseNumber(m.group(1)!);
      if (value == null) continue;
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: spec.name,
          value: value,
          unit: spec.unit,
          collectedAt: _dateNear(text, m.end, collectedAt),
          category: spec.category,
          referenceMin: spec.min,
          referenceMax: spec.max,
          referenceText: spec.refText,
          previousValues: _extractPreviousBlock(text, spec.name),
        ),
      );
    }
    return markers;
  }

  /// Captura "Resultados anteriores: 10/01/2026 - 98" próximos ao marcador.
  List<HistoricalValue> _extractPreviousBlock(String text, String markerName) {
    final escaped = RegExp.escape(markerName.split('(').first.trim());
    final block = RegExp(
      '$escaped[\\s\\S]{0,500}?Resultados anteriores:\\s*([^\\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (block == null) return [];
    return _parsePreviousLine(block.group(1)!);
  }

  List<HistoricalValue> _extractPreviousNear(String text, String markerName) {
    // Hemograma lista anteriores no final do bloco.
    final map = <String, String>{
      'Hemoglobina': r'Hemoglobina:\s*(\d{2}/\d{2}/\d{4})\s*-\s*([\d.,]+)',
      'Hematócrito': r'Hematocrito:\s*(\d{2}/\d{2}/\d{4})\s*-\s*([\d.,]+)',
      'Leucócitos': r'Leuc[oó]citos:\s*(\d{2}/\d{2}/\d{4})\s*-\s*([\d.]+)',
      'Plaquetas': r'Plaquetas:\s*(\d{2}/\d{2}/\d{4})\s*-\s*([\d.]+)',
    };
    final pattern = map[markerName];
    if (pattern == null) return _extractPreviousBlock(text, markerName);
    final m = RegExp(pattern, caseSensitive: false).firstMatch(text);
    if (m == null) return [];
    final date = _tryParseDate(m.group(1)!);
    final value = _parseNumber(m.group(2)!);
    if (date == null || value == null) return [];
    return [HistoricalValue(date: date, value: value)];
  }

  List<HistoricalValue> _parsePreviousLine(String line) {
    final results = <HistoricalValue>[];
    // Formatos: "10/01/2026 - 98" ou "30/03/2026 - 28 | 10/01/2026 - 25"
    final matches = RegExp(r'(\d{2}/\d{2}/\d{4})\s*-\s*([\d.,]+)').allMatches(line);
    for (final m in matches) {
      final date = _tryParseDate(m.group(1)!);
      final value = _parseNumber(m.group(2)!);
      if (date != null && value != null) {
        results.add(HistoricalValue(date: date, value: value));
      }
    }
    return results;
  }

  double? _parseNumber(String raw) {
    var s = raw.trim().replaceAll(' ', '');
    // 4.970 (milhar BR) ou 16,1 (decimal BR) ou 161.000
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    return double.tryParse(s);
  }

  DateTime? _tryParseDate(String raw) {
    try {
      return _dateFmt.parseStrict(raw);
    } catch (_) {
      return null;
    }
  }
}

class _MarkerSpec {
  const _MarkerSpec({
    required this.name,
    required this.category,
    required this.pattern,
    required this.unit,
    this.min,
    this.max,
    this.refText,
  });

  final String name;
  final String category;
  final RegExp pattern;
  final String unit;
  final double? min;
  final double? max;
  final String? refText;
}
