import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/home_location.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/crm.dart';
import 'widgets/health_fields.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _crmNumber = TextEditingController();
  String? _role;
  String? _crmUf;
  String? _sex;
  DateTime? _birthDate;
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _crmNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _role;
    if (role == null) {
      setState(() => _error = 'Escolha se a conta é de paciente ou de médico.');
      return;
    }
    if (_birthDate == null || _sex == null) {
      setState(
        () => _error = 'Informe data de nascimento e sexo para avaliar os exames.',
      );
      return;
    }
    String? crmUf;
    String? crmNumber;
    if (role == 'doctor') {
      final crmError = validateCrm(uf: _crmUf, number: _crmNumber.text);
      if (crmError != null) {
        setState(() => _error = crmError);
        return;
      }
      crmUf = _crmUf;
      crmNumber = crmDigits(_crmNumber.text);
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            role: role,
            sex: _sex,
            birthDate: _birthDate,
            crmUf: crmUf,
            crmNumber: crmNumber,
          );
      await ref.read(examsRepositoryProvider).load();
      ref.read(authRevisionProvider.notifier).bump();
      ref.read(examsRevisionProvider.notifier).bump();
      if (!mounted) return;
      final hasExams = ref.read(examsRepositoryProvider).hasReports;
      context.go(homeLocation(isDoctor: role == 'doctor', hasExams: hasExams));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _role == 'doctor';
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'A conta fica salva. Se reinstalar o app, entre de novo com o mesmo e-mail e senha.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Esta conta é de', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'patient', label: Text('Paciente')),
              ButtonSegment(value: 'doctor', label: Text('Médico')),
            ],
            selected: {?_role},
            emptySelectionAllowed: true,
            onSelectionChanged: (value) => setState(() => _role = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha',
              helperText: 'Mínimo de 6 caracteres',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          HealthFields(
            birthDate: _birthDate,
            sex: _sex,
            onBirthDate: (date) => setState(() => _birthDate = date),
            onSex: (value) => setState(() => _sex = value),
          ),
          if (isDoctor) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownMenu<String>(
              initialSelection: _crmUf,
              label: const Text('UF do CRM'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (final uf in brazilianUfs)
                  DropdownMenuEntry(value: uf, label: uf),
              ],
              onSelected: (value) => setState(() => _crmUf = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _crmNumber,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número do CRM',
                helperText: 'De 4 a 7 dígitos, sem a UF',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
