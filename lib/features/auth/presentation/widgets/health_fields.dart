import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';

/// Data de nascimento e sexo, usados para escolher a faixa de referência.
class HealthFields extends StatelessWidget {
  const HealthFields({
    super.key,
    required this.birthDate,
    required this.sex,
    required this.onBirthDate,
    required this.onSex,
  });

  final DateTime? birthDate;
  final String? sex;
  final ValueChanged<DateTime> onBirthDate;
  final ValueChanged<String?> onSex;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Data de nascimento',
      fieldLabelText: 'dd/mm/aaaa',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) onBirthDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _pickDate(context),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Data de nascimento',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              birthDate == null
                  ? 'Toque para escolher'
                  : DateFormat('dd/MM/yyyy').format(birthDate!),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownMenu<String>(
          initialSelection: sex,
          label: const Text('Sexo biológico'),
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'M', label: 'Masculino'),
            DropdownMenuEntry(value: 'F', label: 'Feminino'),
          ],
          onSelected: onSex,
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
