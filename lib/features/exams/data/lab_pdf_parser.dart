import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../domain/exam_marker.dart';
import '../domain/exam_report.dart';

/// Extrai marcadores de laudos no formato Unilab / laboratórios BR.
class LabPdfParser {
  LabPdfParser({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  ExamReport parse(String text, {String? sourceFileName}) {
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
    final header = _extractHeader(cleaned);
    final urine = _parseUrine(cleaned, collectedAt);
    final body = _stripUrine(cleaned);

    final markers = <ExamMarker>[
      ..._parseHemogram(body, collectedAt),
      ..._parseSimpleResults(body, collectedAt),
      ..._parseLipidPanel(body, collectedAt),
      ..._parseCoagulation(body, collectedAt),
      ...urine,
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

    final enriched = _attachColumnHistory(body, unique);
    final generic = _parseGeneric(body, collectedAt, enriched);
    final markersOut = [...enriched, ...generic.markers];

    var reportDate = collectedAt;
    for (final marker in markersOut) {
      if (marker.collectedAt.isAfter(reportDate)) {
        reportDate = marker.collectedAt;
      }
    }

    return ExamReport(
      id: _uuid.v4(),
      collectedAt: reportDate,
      importedAt: DateTime.now(),
      markers: markersOut,
      patientName: header.patient,
      labName: header.lab,
      doctorName: header.doctor,
      insuranceName: header.insurance,
      sourceFileName: sourceFileName,
      unrecognized: generic.unrecognized,
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

  static const _headerKeys = {
    'nome': 'nome',
    'medico dr a': 'medico',
    'medico': 'medico',
    'dr a': 'medico',
    'solicitante': 'medico',
    'convenio': 'convenio',
    'origem': 'origem',
    'unidade': 'origem',
    'destino': 'origem',
  };

  ({String? patient, String? doctor, String? insurance, String? lab})
  _extractHeader(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    String? patient;
    String? doctor;
    String? insurance;
    String? origin;

    void assign(String key, String value) {
      final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isEmpty) return;
      switch (key) {
        case 'nome':
          patient ??= clean;
        case 'medico':
          doctor ??= clean;
        case 'convenio':
          insurance ??= clean;
        case 'origem':
          origin ??= clean;
      }
    }

    var i = 0;
    while (i < lines.length) {
      final field = _headerField(lines[i]);
      if (field == null) {
        i++;
        continue;
      }
      if (field.value != null) {
        assign(field.key, field.value!);
        i++;
        continue;
      }

      final keys = <String>[field.key];
      var j = i + 1;
      while (j < lines.length) {
        final next = _headerField(lines[j]);
        if (next == null || next.value != null) break;
        keys.add(next.key);
        j++;
      }
      for (final key in keys) {
        if (j >= lines.length || _headerField(lines[j]) != null) break;
        final read = _readHeaderValue(lines, j);
        assign(key, read.$1);
        j = read.$2;
      }
      i = j > i ? j : i + 1;
    }

    return (
      patient: patient,
      doctor: doctor,
      insurance: insurance,
      lab: _prettyLab(origin, text),
    );
  }

  ({String key, String? value})? _headerField(String line) {
    final colon = line.indexOf(':');
    final label = colon >= 0 ? line.substring(0, colon) : line;
    final key = _headerKeys[_foldLabel(label)];
    if (key == null) return null;
    if (colon < 0) return (key: key, value: null);
    final after = line.substring(colon + 1).trim();
    return (key: key, value: after.isEmpty ? null : after);
  }

  (String, int) _readHeaderValue(List<String> lines, int start) {
    final parts = <String>[];
    var index = start;
    while (index < lines.length) {
      final line = lines[index];
      if (parts.isNotEmpty &&
          (_headerField(line) != null || !_headerValueContinues(line))) {
        break;
      }
      parts.add(line);
      index++;
      if (RegExp(r'\s').hasMatch(line) && !line.endsWith('-')) break;
    }
    final joined = parts
        .join(' ')
        .replaceAll(RegExp(r'\s*-\s*'), ' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return (joined, index);
  }

  bool _headerValueContinues(String line) {
    if (line == '-' || line == '–') return true;
    if (RegExp(r'\d').hasMatch(line)) return false;
    return RegExp(r'^[A-ZÁÉÍÓÚÂÊÔÃÕÇ]{2,}$').hasMatch(line);
  }

  String? _prettyLab(String? origin, String text) {
    final source = origin?.trim() ?? '';
    final folded = _foldLabel(source);
    if (folded.contains('unilab')) return 'Unilab';
    if (folded.contains('ipc')) return source.replaceAll(RegExp(r'\s+'), ' ');
    if (source.isNotEmpty) return source;
    if (RegExp(r'unilab', caseSensitive: false).hasMatch(text)) return 'Unilab';
    return null;
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

    add(
      'Hemácias',
      r'(?:Hem[aá]cias|Eritr[oó]citos)[.\s]*:\s*([\d.,]+)[\s\S]{0,40}?milh',
      'milhões/mm³',
      min: 4.5,
      max: 6.0,
      refText: '4,5 a 6,0 milhões/mm³',
    );
    add(
      'Hemoglobina',
      r'Hemoglobina[.\s]*:\s*([\d.,]+)\s*g/dL',
      'g/dL',
      min: 13.0,
      max: 17.0,
      refText: '13,0 a 17,0 g/dL',
    );
    add(
      'Hematócrito',
      r'Hemat[oó]crito[.\s]*:\s*([\d.,]+)',
      '%',
      min: 38,
      max: 52,
      refText: '38 a 52 %',
    );
    add('V.C.M', r'V\.?C\.?M[.\s]*:\s*([\d.,]+)', 'fL', min: 82, max: 98);
    add('H.C.M', r'H\.?C\.?M[.\s]*:\s*([\d.,]+)', 'pg', min: 27, max: 32);
    add(
      'C.H.C.M',
      r'(?:C\.?H\.?C\.?M|CHCM)[.\s]*:\s*([\d.,]+)',
      'g/dL',
      min: 32,
      max: 36,
    );
    add('R.D.W', r'R\.?D\.?W[.\s]*:\s*([\d.,]+)', '%', max: 14.5);
    add(
      'Leucócitos',
      r'Leuc[oó]citos(?:[\s\S]{0,24}?TOTAIS)?[.\s]*:\s*([\d.]+)(?!\s*[µuU]L)',
      '/mm³',
      min: 4500,
      max: 11000,
      refText: '4.500 a 11.000 /mm³',
    );
    add(
      'Plaquetas',
      r'(?:Contagem de plaquetas[.\s]*:\s*|Plaquetas[\s\S]{0,180}?Resultado:\s*|Plaquetas[.\s]*:\s*)([\d.]+)',
      '/mm³',
      min: 150000,
      max: 450000,
      refText: '150.000 a 450.000 /mm³',
    );
    add(
      'Segmentados',
      r'Segmentados[.\s]*:\s*([\d.,]+)\s*%',
      '%',
      min: 50,
      max: 67,
    );
    add(
      'Linfócitos',
      r'Linf[oó]citos[.\s]*:\s*([\d.,]+)\s*%',
      '%',
      min: 20,
      max: 40,
    );
    add(
      'Monócitos',
      r'Mon[oó]citos[.\s]*:\s*([\d.,]+)\s*%',
      '%',
      min: 4,
      max: 10,
    );
    add(
      'Eosinófilos',
      r'Eosin[oó]filos[.\s]*:\s*([\d.,]+)\s*%',
      '%',
      min: 1,
      max: 4,
    );
    add(
      'Basófilos',
      r'Bas[oó]filos[.\s]*:\s*([\d.,]+)\s*%',
      '%',
      min: 0,
      max: 1,
    );

    return markers;
  }

  List<ExamMarker> _parseCoagulation(String text, DateTime collectedAt) {
    final markers = <ExamMarker>[];
    const category = 'Coagulação';

    void tryAdd(
      String name,
      RegExp pattern,
      String unit, {
      double? min,
      double? max,
      String? refText,
    }) {
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
      RegExp(
        r'Tempo de Protrombina:\s*([\d.,]+)\s*segundos',
        caseSensitive: false,
      ),
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
      RegExp(
        r'Tempo de Tromboplastina:\s*([\d.,]+)\s*segundos',
        caseSensitive: false,
      ),
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

    void tryAdd(
      String name,
      RegExp pattern,
      String unit, {
      double? min,
      double? max,
      String? refText,
    }) {
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
        r'(?:Colesterol\s+HDL:\s*|(?<!o )HDL\s+Colesterol:\s*|HDL[\s\S]{0,40}?COLESTEROL[\s\S]{0,500}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      min: 40,
      refText: 'Desejável superior a 40 mg/dL',
    );
    tryAdd(
      'Colesterol LDL',
      RegExp(
        r'(?:Colesterol\s+LDL:\s*|(?<![Vv])LDL\s+Colesterol:\s*|COLESTEROL\s+LDL[\s\S]{0,300}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 100,
      refText: 'Ótimo: menor que 100 mg/dL',
    );
    tryAdd(
      'Colesterol VLDL',
      RegExp(
        r'(?:Colesterol\s+VLDL:\s*|VLDL\s+Colesterol:\s*|COLESTEROL\s+VLDL[\s\S]{0,300}?RESULTADO[.\s]*:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 30,
    );
    tryAdd(
      'Colesterol não HDL',
      RegExp(
        r'(?:Colesterol\s+n[aã]o\s+HDL:\s*|N[aã]o\s+HDL\s+Colesterol:\s*)([\d.,]+)\s*mg/dL',
        caseSensitive: false,
      ),
      'mg/dL',
      max: 130,
    );
    tryAdd(
      'Índice de Castelli',
      RegExp(
        r'[ÍI]ndice de Castelli(?:\s*\d+)?\s*:\s*([\d.,]+)',
        caseSensitive: false,
      ),
      '',
      max: 3.4,
    );
    tryAdd(
      'Triglicerídeos',
      RegExp(
        r'Triglic(?:er[ií]deos|[eé]rides)[\s\S]{0,800}?Resultados?[.\s]*:\s*([\d.,]+)\s*mg/dL',
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
          r'Hemoglobina glicada[\s\S]{0,800}?Resultados?[.\s]*:\s*([\d.,]+)\s*%',
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
          r'Creatinina[\s\S]{0,900}?Resultados?[.\s]*:\s*([\d.,]+)\s*mg/dL',
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
          r'Pot[aá]ssio[\s\S]{0,800}?Resultados?[.\s]*:\s*([\d.,]+)\s*mmol/L',
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
          r'(?:AST/TGO|oxalac[eé]tica)[\s\S]{0,900}?Resultados?[.\s]*:\s*([\d.,]+)\s*U/L',
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
          r'(?:ALT/TGP|pir[uú]vica)[\s\S]{0,900}?Resultados?[.\s]*:\s*([\d.,]+)\s*U/L',
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
          r'Fosfatase alcalina[\s\S]{0,900}?Resultados?[.\s]*:\s*([\d.,]+)\s*U/L',
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
          r'(?:GGT|Gama Glutamil)[\s\S]{0,900}?Resultados?[.\s]*:\s*([\d.,]+)\s*U/L',
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
          r'TSH[\s\S]{0,800}?Resultados?[.\s]*:\s*([\d.,]+)\s*microUI/mL',
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
          r'Prote[ií]na C Reativa[\s\S]{0,800}?Resultados?[.\s]*:\s*([\d.,]+)\s*mg/L',
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
          r'Lipoprote[ií]na A[\s\S]{0,800}?Resultados?[.\s]*:\s*([\d.,]+)\s*nmol/L',
          caseSensitive: false,
        ),
        unit: 'nmol/L',
        max: 75,
        refText: 'Inferior a 75 nmol/L',
      ),
      _MarkerSpec(
        name: 'Ureia',
        category: 'Renal',
        pattern: RegExp(
          r'Ur[eé]ia[\s\S]{0,900}?Resultados?[.\s]*:\s*([\d.,]+)\s*mg/dL',
          caseSensitive: false,
        ),
        unit: 'mg/dL',
        max: 50,
        refText: 'Adultos até 65 anos: menor que 50 mg/dL',
      ),
      _MarkerSpec(
        name: 'PSA',
        category: 'Próstata',
        pattern: RegExp(
          r'PSA(?:\s+Ultra\s+Sens[ií]vel)?[\s\S]{0,500}?Resultados?[.\s]*:\s*([\d.,]+)\s*ng/mL',
          caseSensitive: false,
        ),
        unit: 'ng/mL',
        max: 2.5,
        refText: 'Homem: inferior ou igual a 2,50 ng/mL',
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
    final matches = RegExp(
      r'(\d{2}/\d{2}/\d{4})\s*-\s*([\d.,]+)',
    ).allMatches(line);
    for (final m in matches) {
      final date = _tryParseDate(m.group(1)!);
      final value = _parseNumber(m.group(2)!);
      if (date != null && value != null) {
        results.add(HistoricalValue(date: date, value: value));
      }
    }
    return results;
  }

  static const _units =
      r'mg/dL|g/dL|µg/dL|ug/dL|ng/mL|pg/mL|nmol/L|mmol/L|microUI/mL|mUI/mL|UI/mL|U/L|milhões/mm³|milhoes/mm3|/mm³|/mm3|/µL|/uL|céls/mm³|cels/mm3|segundos|mm/h|fL|fl|pg|mL|%';

  static const _aliases = <String, (String, String)>{
    'hemacias': ('Hemácias', 'Hemograma'),
    'eritrocitos': ('Hemácias', 'Hemograma'),
    'hemoglobina': ('Hemoglobina', 'Hemograma'),
    'hematocrito': ('Hematócrito', 'Hemograma'),
    'v c m': ('V.C.M', 'Hemograma'),
    'vcm': ('V.C.M', 'Hemograma'),
    'h c m': ('H.C.M', 'Hemograma'),
    'hcm': ('H.C.M', 'Hemograma'),
    'c h c m': ('C.H.C.M', 'Hemograma'),
    'chcm': ('C.H.C.M', 'Hemograma'),
    'r d w': ('R.D.W', 'Hemograma'),
    'rdw': ('R.D.W', 'Hemograma'),
    'leucocitos': ('Leucócitos', 'Hemograma'),
    'leucocitos totais': ('Leucócitos', 'Hemograma'),
    'plaquetas': ('Plaquetas', 'Hemograma'),
    'contagem de plaquetas': ('Plaquetas', 'Hemograma'),
    'segmentados': ('Segmentados', 'Hemograma'),
    'linfocitos': ('Linfócitos', 'Hemograma'),
    'monocitos': ('Monócitos', 'Hemograma'),
    'eosinofilos': ('Eosinófilos', 'Hemograma'),
    'basofilos': ('Basófilos', 'Hemograma'),
    'glicose': ('Glicose', 'Metabolismo'),
    'hemoglobina glicada': ('Hemoglobina glicada (HbA1c)', 'Metabolismo'),
    'glicemia media estimada': ('Glicemia média estimada', 'Metabolismo'),
    'creatinina': ('Creatinina', 'Renal'),
    'ureia': ('Ureia', 'Renal'),
    'acido urico': ('Ácido úrico', 'Metabolismo'),
    'potassio': ('Potássio', 'Eletrólitos'),
    'ast tgo': ('AST/TGO', 'Hepático'),
    'tgo': ('AST/TGO', 'Hepático'),
    'ast': ('AST/TGO', 'Hepático'),
    'alt tgp': ('ALT/TGP', 'Hepático'),
    'tgp': ('ALT/TGP', 'Hepático'),
    'alt': ('ALT/TGP', 'Hepático'),
    'fosfatase alcalina': ('Fosfatase alcalina', 'Hepático'),
    'ggt': ('GGT', 'Hepático'),
    'gama glutamil transferase': ('GGT', 'Hepático'),
    'bilirrubina direta': ('Bilirrubina direta', 'Hepático'),
    'bilirrubina indireta': ('Bilirrubina indireta', 'Hepático'),
    'bilirrubina total': ('Bilirrubina total', 'Hepático'),
    'vitamina d': ('Vitamina D', 'Vitaminas'),
    'vitamina b12': ('Vitamina B12', 'Vitaminas'),
    'ferritina': ('Ferritina', 'Ferro'),
    'tsh': ('TSH', 'Tireoide'),
    'proteina c reativa': ('PCR ultrassensível', 'Inflamação'),
    'pcr ultrassensivel': ('PCR ultrassensível', 'Inflamação'),
    'lipoproteina a': ('Lipoproteína A', 'Lipídico'),
    'colesterol total': ('Colesterol Total', 'Lipídico'),
    'colest total': ('Colesterol Total', 'Lipídico'),
    'colesterol hdl': ('Colesterol HDL', 'Lipídico'),
    'hdl colesterol': ('Colesterol HDL', 'Lipídico'),
    'hdl': ('Colesterol HDL', 'Lipídico'),
    'colesterol ldl': ('Colesterol LDL', 'Lipídico'),
    'ldl colesterol': ('Colesterol LDL', 'Lipídico'),
    'ldl': ('Colesterol LDL', 'Lipídico'),
    'colesterol vldl': ('Colesterol VLDL', 'Lipídico'),
    'vldl colesterol': ('Colesterol VLDL', 'Lipídico'),
    'vldl': ('Colesterol VLDL', 'Lipídico'),
    'colesterol nao hdl': ('Colesterol não HDL', 'Lipídico'),
    'nao hdl colesterol': ('Colesterol não HDL', 'Lipídico'),
    'triglicerideos': ('Triglicerídeos', 'Lipídico'),
    'triglicerides': ('Triglicerídeos', 'Lipídico'),
    'indice de castelli': ('Índice de Castelli', 'Lipídico'),
    'indice de castelli 1': ('Índice de Castelli', 'Lipídico'),
    'psa': ('PSA', 'Próstata'),
    'psa ultra sensivel': ('PSA', 'Próstata'),
    'tempo de protrombina': ('Tempo de Protrombina', 'Coagulação'),
    'atividade': ('Atividade TAP', 'Coagulação'),
    'inr': ('INR', 'Coagulação'),
    'tempo de tromboplastina': ('TTPA', 'Coagulação'),
    'ttpa': ('TTPA', 'Coagulação'),
    'ratio': ('TTPA Ratio', 'Coagulação'),
  };

  ({List<ExamMarker> markers, List<String> unrecognized}) _parseGeneric(
    String text,
    DateTime collectedAt,
    List<ExamMarker> knownMarkers,
  ) {
    final known = knownMarkers.map((m) => _foldLabel(m.name)).toSet();
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final markers = <ExamMarker>[];
    final unrecognized = <String>[];
    final sameLine = RegExp(
      '^([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .()/]{2,48}?)\\s*:\\s*([\\d.,]+)\\s*($_units)\\b',
      caseSensitive: false,
    );
    final bareLabel = RegExp(r'^([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .()/]{2,48}):?\s*$');
    final valueLine = RegExp(
      '^([\\d.,]+)\\s*($_units)?\$',
      caseSensitive: false,
    );
    final qualitative = RegExp(
      r'^(ausentes?|presentes?|negativ[oa]|positiv[oa]|reagente|n[aã]o\s+reagente|normal|l[ií]mpido|turvo|amarelo)$',
      caseSensitive: false,
    );
    final sameQualitative = RegExp(
      r'^([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .()/]{1,48}?)\s*:\s*(ausentes?|presentes?|negativ[oa]|positiv[oa]|reagente|n[aã]o\s+reagente|normal|l[ií]mpido|turvo|amarelo)$',
      caseSensitive: false,
    );

    bool already(String label) {
      final folded = _foldLabel(label);
      if (known.contains(folded)) return true;
      final alias = _aliases[folded];
      return alias != null && known.contains(_foldLabel(alias.$1));
    }

    void addMarker({
      required String label,
      required int at,
      double? value,
      String? textValue,
      String unit = '',
      double? min,
      double? max,
      String? refText,
    }) {
      final folded = _foldLabel(label);
      final alias = _aliases[folded];
      final name = alias?.$1 ?? _displayName(label);
      final category = alias?.$2 ?? 'Não classificado';
      if (known.contains(_foldLabel(name))) return;
      if (textValue == null && value == null) return;
      known.add(_foldLabel(name));
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: name,
          value: value ?? 0,
          textValue: textValue,
          unit: unit,
          collectedAt: _dateNear(text, at < 0 ? 0 : at, collectedAt),
          category: category,
          referenceMin: min,
          referenceMax: max,
          referenceText: refText,
        ),
      );
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final inline = sameLine.firstMatch(line);
      if (inline != null) {
        final label = inline.group(1)!.trim();
        final rest = line.substring(inline.end);
        if (_isNotExam(label) ||
            already(label) ||
            RegExp(r'^\s*[-–a]\s*\d', caseSensitive: false).hasMatch(rest)) {
          continue;
        }
        final value = _parseLoose(inline.group(2)!);
        if (value == null) continue;
        final ref = _referenceNear(lines, i);
        addMarker(
          label: label,
          at: text.indexOf(line),
          value: value,
          unit: inline.group(3) ?? '',
          min: ref?.min,
          max: ref?.max,
          refText: ref?.text,
        );
        continue;
      }

      final inlineText = sameQualitative.firstMatch(line);
      if (inlineText != null) {
        final label = inlineText.group(1)!.trim();
        if (_isNotExam(label) || already(label)) continue;
        addMarker(
          label: label,
          at: text.indexOf(line),
          textValue: inlineText.group(2)!.trim(),
        );
        continue;
      }

      final bare = bareLabel.firstMatch(line);
      if (bare == null) continue;
      final label = bare.group(1)!.trim();
      if (_isNotExam(label) || already(label)) continue;

      var consumed = 0;
      double? value;
      String? unit;
      String? words;
      for (var step = 1; step <= 4 && i + step < lines.length; step++) {
        final next = lines[i + step];
        if (next == ':') {
          consumed = step;
          continue;
        }
        final numeric = valueLine.firstMatch(next);
        final continuesRange =
            i + step + 1 < lines.length &&
            RegExp(r'^[-–]\s*\d').hasMatch(lines[i + step + 1].trim());
        if (numeric != null && !continuesRange) {
          value = _parseLoose(numeric.group(1)!);
          unit = numeric.group(2) ?? '';
          consumed = step;
          break;
        }
        if (qualitative.hasMatch(next)) {
          words = next.trim();
          consumed = step;
          break;
        }
        if (bareLabel.hasMatch(next)) break;
      }

      if (value == null && words == null) continue;
      if (words == null && (unit == null || unit.isEmpty)) continue;

      final ref = _referenceNear(lines, i + consumed);
      addMarker(
        label: label,
        at: text.indexOf(line),
        value: value,
        textValue: words,
        unit: unit ?? '',
        min: ref?.min,
        max: ref?.max,
        refText: ref?.text,
      );
      i += consumed;
    }

    return (markers: markers, unrecognized: unrecognized);
  }

  String _displayName(String label) {
    final trimmed = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed
        .split(' ')
        .map((word) {
          final letters = word.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
          if (letters.isEmpty || letters != letters.toUpperCase()) return word;
          if (letters.length <= 4) return word;
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  String _foldLabel(String raw) {
    const from = 'áàâãéêíóôõúüç';
    const to = 'aaaaeeiooouuc';
    final buffer = StringBuffer();
    for (final char in raw.toLowerCase().split('')) {
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer
        .toString()
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isNoise(String label) {
    final folded = _foldLabel(label);
    const noise = {
      'resultado',
      'resultados',
      'valor de referencia',
      'valores de referencia',
      'metodo',
      'material',
      'nota',
      'observacao',
      'obs',
      'liberado',
      'liberado por',
      'nome',
      'nome social',
      'origem',
      'convenio',
      'medico',
      'sexo',
      'idade',
      'data',
      'hora',
      'coleta',
      'paciente',
      'cpf',
      'unidade',
      'pagina',
      'desejavel',
      'otimo',
      'homens',
      'mulheres',
      'adultos',
      'criancas',
      'referencia',
      'anterior',
      'anteriores',
      'dosagem de',
    };
    if (noise.contains(folded)) return true;
    if (folded.startsWith('nota ')) return true;
    if (folded.startsWith('menores ') || folded.startsWith('maiores ')) {
      return true;
    }
    if (folded.contains('referencia') || folded.contains('liberad')) {
      return true;
    }
    if (folded.contains('jejum') || folded.contains('coleta')) return true;
    if (folded.contains('data') || folded.contains('hora')) return true;
    if (folded.contains('impress') || folded.contains('cadastro')) return true;
    if (folded.contains('nascimento') || folded.contains('convenio')) {
      return true;
    }
    if (folded.contains('medico') || folded.contains('sexo')) return true;
    if (folded.contains('assinatura') || folded.contains('crm')) return true;
    return false;
  }

  /// Rótulo de faixa etária, documento ou texto corrido. Não é exame coletado.
  bool _isNotExam(String label) {
    if (_isNoise(label)) return true;
    final folded = _foldLabel(label);
    if (_isSection(folded)) return true;
    final words = folded.split(' ').where((word) => word.isNotEmpty).toList();
    const banned = {
      'mes',
      'meses',
      'ano',
      'anos',
      'dia',
      'dias',
      'adulto',
      'adultos',
      'nascido',
      'nascidos',
      'recem',
      'homem',
      'homens',
      'mulher',
      'mulheres',
      'crianca',
      'criancas',
      'adolescente',
      'adolescentes',
      'jejum',
      'bebe',
      'rn',
      'idade',
      'anterior',
      'anteriores',
      'procedimento',
      'pagina',
      'paginas',
      'cnes',
      'relativo',
      'absoluto',
      'referencia',
      'formula',
      'responsavel',
      'dr',
      'dra',
    };
    for (final word in words) {
      if (banned.contains(word)) return true;
    }
    if (folded.contains('anterior') || folded.contains('procedimento')) {
      return true;
    }
    if (folded.contains('pagina') || folded.contains('cnes')) return true;
    if (words.isNotEmpty && words.every((word) => word.length <= 1)) {
      return true;
    }
    final letters = label.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    final uppers = letters.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÂÊÔÃÕÇ]'), '');
    if (words.length >= 3 &&
        letters.isNotEmpty &&
        uppers.length / letters.length > 0.8) {
      return true;
    }
    if (_aliases.containsKey(folded)) return false;
    final letterCount = folded.replaceAll(RegExp(r'[^a-z]'), '').length;
    return letterCount < 3;
  }

  bool _isSection(String folded) {
    if (folded.contains('continuacao') || folded.contains('frac')) return true;
    if (folded.contains('analise') || folded.contains('completo')) return true;
    return folded == 'eritrograma' || folded == 'leucograma';
  }

  double? _parseLoose(String raw) {
    if (RegExp(r'^\d\.\d{3}$').hasMatch(raw)) return _parsePlainDecimal(raw);
    return _parseNumber(raw);
  }

  ({double? min, double? max, String? text})? _referenceNear(
    List<String> lines,
    int index,
  ) {
    if (index + 1 >= lines.length) return null;
    final next = lines[index + 1].trim();
    if (!RegExp(r'\d').hasMatch(next)) return null;
    final lowerCue = next.toLowerCase();
    final looksRef = RegExp(
      r'\ba\b|menor|maior|até|ate|referên|<|>|inferior|superior',
    ).hasMatch(lowerCue);
    if (!looksRef) return null;
    final chunk = next.length > 90 ? next.substring(0, 90) : next;
    final lower = chunk.toLowerCase();
    final ambiguous =
        lower.contains('homem') ||
        lower.contains('mulher') ||
        lower.contains('anos') ||
        lower.contains('crian');
    double? min;
    double? max;
    if (!ambiguous) {
      final between = RegExp(
        r'([\d.,]+)\s*(?:a|-)\s*([\d.,]+)',
      ).firstMatch(chunk);
      if (between != null) {
        min = _parseNumber(between.group(1)!);
        max = _parseNumber(between.group(2)!);
      } else {
        final menor = RegExp(
          r'(?:menor que|<|até|ate)\s*([\d.,]+)',
          caseSensitive: false,
        ).firstMatch(chunk);
        final maior = RegExp(
          r'(?:maior que|>)\s*([\d.,]+)',
          caseSensitive: false,
        ).firstMatch(chunk);
        if (menor != null) max = _parseNumber(menor.group(1)!);
        if (maior != null) min = _parseNumber(maior.group(1)!);
      }
    }
    if (min == null &&
        max == null &&
        _foldLabel(chunk).contains('referencia')) {
      return null;
    }
    if (min == null && max == null && !RegExp(r'\d').hasMatch(chunk)) {
      return null;
    }
    return (min: min, max: max, text: chunk);
  }

  static final _urinePanel = RegExp(
    r'Urina tipo I[\s\S]*?(?=\n\s*(?:Creatinina|PSA(?:\s+Ultra\s+Sens[ií]vel)?|Hemograma|Colesterol|Ur[eé]ia|Ferritina|Transaminase|Fosfatase|Vitamina|TSH|Glicose)\s*\n|$)',
    caseSensitive: false,
  );

  String _stripUrine(String text) => text.replaceAll(_urinePanel, '\n');

  List<ExamMarker> _parseUrine(String text, DateTime fallback) {
    final panel = _urinePanel.firstMatch(text);
    if (panel == null) return [];
    final block = panel.group(0)!;
    final collectedAt = _extractCollectionDate(block) ?? fallback;
    final markers = <ExamMarker>[];

    void addNumber(
      String name,
      String pattern, {
      String unit = '',
      double? min,
      double? max,
      String? refText,
      bool plainDecimal = false,
    }) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(block);
      if (match == null) return;
      final value = plainDecimal
          ? _parsePlainDecimal(match.group(1)!)
          : _parseNumber(match.group(1)!);
      if (value == null) return;
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: 'Urina: $name',
          value: value,
          unit: unit,
          collectedAt: collectedAt,
          category: 'Urina tipo I',
          referenceMin: min,
          referenceMax: max,
          referenceText: refText,
        ),
      );
    }

    void addText(String name, String pattern, {String? expected}) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(block);
      if (match == null) return;
      final word = match.group(1)!.trim();
      if (word.isEmpty) return;
      markers.add(
        ExamMarker(
          id: _uuid.v4(),
          name: 'Urina: $name',
          value: 0,
          textValue: word,
          unit: '',
          collectedAt: collectedAt,
          category: 'Urina tipo I',
          referenceText: expected,
        ),
      );
    }

    addNumber('Volume', r'Volume:\s*([\d.,]+)', unit: 'mL');
    addText('Cor', r'Cor:\s*([A-Za-zÀ-ÿ]+)');
    addText('Aspecto', r'Aspecto:\s*([A-Za-zÀ-ÿ]+)');
    addNumber(
      'Densidade',
      r'Densidade:\s*([\d.,]+)',
      min: 1.010,
      max: 1.025,
      refText: '1,010 a 1,025',
      plainDecimal: true,
    );
    addNumber(
      'pH',
      r'pH:\s*([\d.,]+)',
      min: 5.5,
      max: 7.0,
      refText: '5,5 a 7,0',
      plainDecimal: true,
    );
    addText(
      'Proteínas',
      r'Prote[ií]nas:\s*([A-Za-zÀ-ÿ]+)',
      expected: 'Ausentes',
    );
    addNumber(
      'Glicose',
      r'Glicose:\s*([\d.,]+)',
      max: 0,
      refText: 'Ausente',
      plainDecimal: true,
    );
    addText('Cetona', r'Cetona:\s*([A-Za-zÀ-ÿ]+)', expected: 'Ausentes');
    addText(
      'Bilirrubinas',
      r'Bilirrubinas:\s*([A-Za-zÀ-ÿ]+)',
      expected: 'Ausentes',
    );
    addText(
      'Urobilinogênio',
      r'Urobilinog[eê]nio:\s*([A-Za-zÀ-ÿ]+)',
      expected: 'Normal',
    );
    addNumber(
      'Hemoglobina',
      r'Hemoglobina Livre:\s*([\d.,]+)',
      unit: '/µL',
      max: 0,
      refText: '0/µL',
      plainDecimal: true,
    );
    addText('Nitrito', r'Nitrito:\s*([A-Za-zÀ-ÿ]+)', expected: 'Negativo');
    addNumber(
      'Hemácias',
      r'Hem[aá]cias:\s*([\d.,]+)',
      unit: '/µL',
      max: 23,
      refText: 'Menor que 23/µL',
      plainDecimal: true,
    );
    addNumber(
      'Leucócitos',
      r'Leuc[oó]citos:\s*([\d.,]+)',
      unit: '/µL',
      max: 25,
      refText: 'Menor que 25/µL',
      plainDecimal: true,
    );
    addNumber(
      'Células epiteliais',
      r'C[eé]lulas Epiteliais:\s*([\d.,]+)',
      unit: '/µL',
      max: 31,
      refText: 'Menor que 31/µL',
      plainDecimal: true,
    );
    addNumber(
      'Escamosas',
      r'Escamosas:\s*([\d.,]+)',
      unit: '/µL',
      max: 31,
      refText: 'Menor que 31/µL',
      plainDecimal: true,
    );
    addNumber(
      'Não escamosas',
      r'N[aã]o Escamosas:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );
    addNumber(
      'Transicionais',
      r'Transicionais:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );
    addNumber(
      'Tubular renal',
      r'Tubular Renal:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );
    addNumber(
      'Cilindros hialinos',
      r'Cilindros Hialinos:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );
    addNumber(
      'Cilindros patológicos',
      r'Cilindros Patol[oó]gicos:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );
    addNumber(
      'Bactérias',
      r'Bact[eé]rias:\s*([\d.,]+)',
      unit: '/µL',
      max: 1200,
      refText: 'Menor que 1.200/µL',
      plainDecimal: true,
    );
    addNumber(
      'Cristais',
      r'Cristais:\s*([\d.,]+)',
      unit: '/µL',
      max: 10,
      refText: 'Menor que 10/µL',
      plainDecimal: true,
    );
    addNumber(
      'Leveduras',
      r'Leveduras:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );
    addNumber(
      'Espermatozoides',
      r'Espermatoz[oó]ides:\s*([\d.,]+)',
      unit: '/µL',
      max: 50,
      refText: 'Menor que 50/µL',
      plainDecimal: true,
    );
    addNumber(
      'Muco',
      r'Muco:\s*([\d.,]+)',
      unit: '/µL',
      max: 0.999,
      refText: 'Menor que 1/µL',
      plainDecimal: true,
    );

    return markers;
  }

  List<ExamMarker> _attachColumnHistory(String text, List<ExamMarker> markers) {
    final header = RegExp(
      r'Resultados?\s*\(?s\)?\s*anterior(?:es|\(es\))?[.\s]*:',
      caseSensitive: false,
    );
    final extras = <String, List<HistoricalValue>>{};

    for (final match in header.allMatches(text)) {
      final window = text.substring(
        match.end,
        (match.end + 1600).clamp(0, text.length),
      );
      final block = _parseAnteriorBlock(window);
      final unlabeled = block.remove('');
      if (unlabeled != null && unlabeled.isNotEmpty) {
        final head = text.substring(
          (match.start - 2500).clamp(0, text.length),
          match.start,
        );
        final owner = _examBefore(head);
        if (owner != null) {
          extras.putIfAbsent(owner.toLowerCase(), () => []).addAll(unlabeled);
        }
      }
      for (final entry in block.entries) {
        extras
            .putIfAbsent(entry.key.toLowerCase(), () => [])
            .addAll(entry.value);
      }
    }

    if (extras.isEmpty) return markers;
    return [
      for (final marker in markers)
        _mergeHistory(marker, extras[marker.name.toLowerCase()] ?? const []),
    ];
  }

  ExamMarker _mergeHistory(ExamMarker marker, List<HistoricalValue> extra) {
    if (extra.isEmpty) return marker;
    final merged = [...marker.previousValues];
    for (final point in extra) {
      final exists = merged.any(
        (current) =>
            current.date.year == point.date.year &&
            current.date.month == point.date.month &&
            current.date.day == point.date.day &&
            current.value == point.value,
      );
      if (!exists) merged.add(point);
    }
    return marker.copyWith(previousValues: merged);
  }

  String? _examBefore(String head) {
    const aliases = <(String, String)>[
      ('triglic', 'Triglicerídeos'),
      ('creatinina', 'Creatinina'),
      ('uréia', 'Ureia'),
      ('ureia', 'Ureia'),
      ('glicose', 'Glicose'),
      ('ferritina', 'Ferritina'),
      ('fosfatase', 'Fosfatase alcalina'),
      ('glutamil', 'GGT'),
      ('oxalac', 'AST/TGO'),
      ('pirúvica', 'ALT/TGP'),
      ('piruvica', 'ALT/TGP'),
      ('psa', 'PSA'),
    ];
    String? name;
    var best = -1;
    final lower = head.toLowerCase();
    for (final alias in aliases) {
      final index = lower.lastIndexOf(alias.$1);
      if (index > best) {
        best = index;
        name = alias.$2;
      }
    }
    return name;
  }

  Map<String, List<HistoricalValue>> _parseAnteriorBlock(String body) {
    final lines = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(48)
        .toList();
    final result = <String, List<HistoricalValue>>{};
    var index = 0;
    final dates = <DateTime>[];
    while (index < lines.length) {
      final date = _lineDate(lines[index]);
      if (date == null) break;
      dates.add(date);
      index++;
    }
    if (dates.isEmpty) return result;

    final valueLine = RegExp(r'^([\d.,]+)(?:\s|$)');

    List<HistoricalValue>? readValues() {
      final values = <HistoricalValue>[];
      for (var slot = 0; slot < dates.length && index < lines.length; slot++) {
        final match = valueLine.firstMatch(lines[index]);
        if (match == null) return values.length == dates.length ? values : null;
        final value = _parseNumber(match.group(1)!);
        if (value == null) return null;
        values.add(HistoricalValue(date: dates[slot], value: value));
        index++;
      }
      return values.length == dates.length ? values : null;
    }

    if (index < lines.length && valueLine.hasMatch(lines[index])) {
      final values = readValues();
      if (values != null) result[''] = values;
      return result;
    }

    while (index < lines.length && lines[index].endsWith(':')) {
      final canonical = _historyLabel(lines[index]);
      if (canonical == null) break;
      index++;
      final values = readValues();
      if (values == null) break;
      result[canonical] = values;
    }
    return result;
  }

  DateTime? _lineDate(String line) {
    final match = RegExp(r'^(\d{2}/\d{2}/\d{4})$').firstMatch(line.trim());
    if (match == null) return null;
    return _tryParseDate(match.group(1)!);
  }

  String? _historyLabel(String line) {
    final raw = line.replaceAll(RegExp(r':\s*$'), '').trim().toLowerCase();
    if (raw.startsWith('colest')) return 'Colesterol Total';
    if (raw == 'hdl') return 'Colesterol HDL';
    if (raw == 'ldl') return 'Colesterol LDL';
    if (raw.startsWith('hemoglobina')) return 'Hemoglobina';
    if (raw.startsWith('hemat')) return 'Hematócrito';
    if (raw.startsWith('leuco')) return 'Leucócitos';
    if (raw.startsWith('plaqueta')) return 'Plaquetas';
    return null;
  }

  double? _parsePlainDecimal(String raw) {
    var s = raw.trim().replaceAll(' ', '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(s);
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
