import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';

/// Data de nascimento e sexo, usados para escolher a faixa de referência.
class HealthFields extends StatefulWidget {
  const HealthFields({
    super.key,
    required this.birthDate,
    required this.sex,
    required this.onBirthDate,
    required this.onSex,
  });

  final DateTime? birthDate;
  final String? sex;
  final ValueChanged<DateTime?> onBirthDate;
  final ValueChanged<String?> onSex;

  @override
  State<HealthFields> createState() => _HealthFieldsState();
}

class _HealthFieldsState extends State<HealthFields> {
  late final TextEditingController _date;

  @override
  void initState() {
    super.initState();
    _date = TextEditingController(text: _format(widget.birthDate));
  }

  @override
  void didUpdateWidget(HealthFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.birthDate == oldWidget.birthDate) return;
    final formatted = _format(widget.birthDate);
    if (_date.text == formatted) return;
    _date.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.birthDate ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: 'Data de nascimento',
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    widget.onBirthDate(picked);
  }

  void _onTyped(String value) {
    widget.onBirthDate(parseBirthDate(value));
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseBirthDate(_date.text);
    final complete = _date.text.length == 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _date,
          keyboardType: TextInputType.number,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.birthday],
          inputFormatters: const [BirthDateInputFormatter()],
          onChanged: _onTyped,
          decoration: InputDecoration(
            labelText: 'Data de nascimento',
            hintText: 'dd/mm/aaaa',
            helperText: complete && parsed == null
                ? 'Essa data não existe. Use dia, mês e ano.'
                : 'Digite no formato dd/mm/aaaa ou escolha no calendário',
            suffixIcon: IconButton(
              onPressed: _pickDate,
              tooltip: 'Escolher no calendário',
              icon: const Icon(Icons.calendar_today_outlined),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownMenu<String>(
          initialSelection: widget.sex,
          label: const Text('Sexo biológico'),
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'M', label: 'Masculino'),
            DropdownMenuEntry(value: 'F', label: 'Feminino'),
          ],
          onSelected: widget.onSex,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Os laudos trazem faixas diferentes por sexo e idade. '
          'O app usa estes dados para dizer se o resultado está baixo, normal ou alto.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Aceita só uma data real, de 1900 até hoje, no formato dd/mm/aaaa.
DateTime? parseBirthDate(String text) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  if (month < 1 || month > 12) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  if (date.isAfter(end) || year < 1900) return null;
  return date;
}

String _format(DateTime? date) =>
    date == null ? '' : DateFormat('dd/MM/yyyy').format(date);

/// Insere as barras enquanto a pessoa digita: 12111995 vira 12/11/1995.
class BirthDateInputFormatter extends TextInputFormatter {
  const BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
