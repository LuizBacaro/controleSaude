import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../billing/data/doctor_plan_repository.dart';
import '../../../core/providers.dart';
import '../../../core/router/home_location.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/crm.dart';
import 'widgets/health_fields.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.planCheckout = false});

  /// No site, a conta de médico segue para o pagamento em vez de abrir o consultório.
  final bool planCheckout;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _crmNumber = TextEditingController();
  String? _role;
  String? _crmUf;
  String? _sex;
  DateTime? _birthDate;
  var _loading = false;
  var _showPassword = false;
  var _showPasswordConfirm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.planCheckout) _role = 'doctor';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _crmNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _role;
    if (role == null) {
      setState(() => _error = 'Escolha se a conta é de paciente ou de médico.');
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      setState(
        () => _error =
            'As senhas não são iguais. Digite a mesma nos dois campos.',
      );
      return;
    }
    if (_birthDate == null || _sex == null) {
      setState(
        () => _error =
            'Informe data de nascimento e sexo para avaliar os exames.',
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
      if (widget.planCheckout) {
        final url = await ref
            .read(doctorPlanRepositoryProvider)
            .startWebCheckout();
        if (!mounted) return;
        final opened = await launchUrl(
          Uri.parse(url),
          webOnlyWindowName: '_self',
        );
        if (!opened && mounted) {
          setState(() => _error = 'Não foi possível abrir o pagamento.');
        }
        return;
      }
      TextInput.finishAutofillContext();
      final hasExams = ref.read(examsRepositoryProvider).hasReports;
      context.go(homeLocation(isDoctor: role == 'doctor', hasExams: hasExams));
    } catch (e) {
      setState(() => _error = AppException.messageOf(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return AutofillGroup(
              child: wide ? _wideForm(context) : _narrowForm(context),
            );
          },
        ),
      ),
    );
  }

  Widget _narrowForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _intro(context),
        if (!widget.planCheckout) ...[
          const SizedBox(height: AppSpacing.lg),
          _roleLabel(context),
          const SizedBox(height: AppSpacing.sm),
          _rolePicker(),
        ],
        const SizedBox(height: AppSpacing.lg),
        _nameField(),
        const SizedBox(height: AppSpacing.md),
        _emailField(),
        const SizedBox(height: AppSpacing.md),
        _passwordField(),
        const SizedBox(height: AppSpacing.md),
        _confirmField(),
        const SizedBox(height: AppSpacing.md),
        _healthFields(),
        ..._crmFields(),
        ..._errorLine(context),
        const SizedBox(height: AppSpacing.lg),
        _submitButton(),
      ],
    );
  }

  Widget _wideForm(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _intro(context),
                    if (!widget.planCheckout) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _roleLabel(context),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _rolePicker(),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _nameField(),
                              const SizedBox(height: AppSpacing.md),
                              _emailField(),
                              const SizedBox(height: AppSpacing.md),
                              _passwordField(),
                              const SizedBox(height: AppSpacing.md),
                              _confirmField(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _healthFields(),
                              ..._crmFields(),
                              ..._errorLine(context),
                              const SizedBox(height: AppSpacing.lg),
                              _submitButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final plan = widget.planCheckout;
    return Text(
      plan
          ? 'O consultório é uma assinatura mensal. A conta de paciente continua gratuita. Ao continuar, a conta de médico é criada e o pagamento abre em seguida.'
          : 'A conta fica salva. Se reinstalar o app, entre de novo com o mesmo e-mail e senha.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _roleLabel(BuildContext context) {
    return Text(
      'Esta conta é de',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _rolePicker() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'patient', label: Text('Paciente')),
        ButtonSegment(value: 'doctor', label: Text('Médico')),
      ],
      selected: {?_role},
      emptySelectionAllowed: true,
      onSelectionChanged: (value) {
        final next = value.first;
        if (kIsWeb && next == 'doctor' && !widget.planCheckout) {
          context.go('/plano');
          return;
        }
        setState(() => _role = next);
      },
      showSelectedIcon: false,
    );
  }

  Widget _nameField() {
    return TextField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.name],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'Nome'),
    );
  }

  Widget _emailField() {
    return TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'E-mail'),
    );
  }

  Widget _passwordField() {
    return TextField(
      controller: _password,
      obscureText: !_showPassword,
      autocorrect: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Senha',
        helperText: 'Mínimo de 6 caracteres',
        suffixIcon: IconButton(
          tooltip: _showPassword ? 'Esconder senha' : 'Mostrar senha',
          onPressed: () => setState(() => _showPassword = !_showPassword),
          icon: Icon(
            _showPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  Widget _confirmField() {
    return TextField(
      controller: _passwordConfirm,
      obscureText: !_showPasswordConfirm,
      autocorrect: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Confirmar senha',
        suffixIcon: IconButton(
          tooltip: _showPasswordConfirm ? 'Esconder senha' : 'Mostrar senha',
          onPressed: () =>
              setState(() => _showPasswordConfirm = !_showPasswordConfirm),
          icon: Icon(
            _showPasswordConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  Widget _healthFields() {
    return HealthFields(
      birthDate: _birthDate,
      sex: _sex,
      onBirthDate: (date) => setState(() => _birthDate = date),
      onSex: (value) => setState(() => _sex = value),
    );
  }

  List<Widget> _crmFields() {
    if (_role != 'doctor') return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      DropdownMenu<String>(
        initialSelection: _crmUf,
        label: const Text('UF do CRM'),
        expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries: [
          for (final uf in brazilianUfs) DropdownMenuEntry(value: uf, label: uf),
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
    ];
  }

  List<Widget> _errorLine(BuildContext context) {
    final error = _error;
    if (error == null) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ];
  }

  Widget _submitButton() {
    return FilledButton(
      onPressed: _loading ? null : _submit,
      child: _loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              widget.planCheckout
                  ? 'Continuar para o pagamento'
                  : 'Continuar',
            ),
    );
  }
}
