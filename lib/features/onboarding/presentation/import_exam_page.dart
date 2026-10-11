import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../exams/domain/exam_marker.dart';
import '../../exams/domain/exam_report.dart';
import '../../exams/domain/patient_profile.dart';
import '../../exams/presentation/widgets/report_heading.dart';
import '../../exams/presentation/widgets/status_chip.dart';

class ImportExamPage extends ConsumerStatefulWidget {
  const ImportExamPage({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<ImportExamPage> createState() => _ImportExamPageState();
}

class _ImportExamPageState extends ConsumerState<ImportExamPage> {
  var _loading = false;
  var _saving = false;
  String? _error;
  ExamReport? _draft;
  final Set<String> _excluded = {};

  Future<void> _pickPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final repo = ref.read(examsRepositoryProvider);
      final ExamReport draft;
      if (file.bytes != null) {
        draft = await repo.readPdfBytes(
          file.bytes!,
          fileName: file.name,
          patient: _patient(),
        );
      } else if (file.path != null) {
        draft = await repo.readPdfFile(File(file.path!), patient: _patient());
      } else {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }
      _showDraft(draft);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _loadSample() {
    setState(() {
      _error = null;
    });
    try {
      _showDraft(
        ref.read(examsRepositoryProvider).readSample(patient: _patient()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  PatientProfile? _patient() {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    return PatientProfile(sex: user.sex, birthDate: user.birthDate);
  }

  void _showDraft(ExamReport draft) {
    setState(() {
      _draft = draft;
      _excluded.clear();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final kept = draft.markers.where((m) => !_excluded.contains(m.id)).toList();
    if (kept.isEmpty) {
      setState(() => _error = 'Marque ao menos um resultado para salvar.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(examsRepositoryProvider).saveReport(draft.withMarkers(kept));
      ref.read(examsRevisionProvider.notifier).bump();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laudo salvo com ${kept.length} resultados.')),
      );
      context.go('/app');
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _discard() {
    setState(() {
      _draft = null;
      _excluded.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          draft != null
              ? 'Conferir laudo'
              : widget.isOnboarding
              ? 'Seu primeiro exame'
              : 'Importar PDF',
        ),
        leading: widget.isOnboarding && draft == null
            ? null
            : IconButton(
                icon: Icon(draft != null ? Icons.arrow_back : Icons.close),
                onPressed: draft != null ? _discard : () => context.pop(),
              ),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: draft == null ? _picker(context) : _review(context, draft),
      bottomNavigationBar: draft == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _discard,
                        child: const Text('Descartar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          'Salvar ${draft.markers.length - _excluded.length} resultados',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _review(BuildContext context, ExamReport draft) {
    final text = Theme.of(context).textTheme;
    final duplicate = ref.read(examsRepositoryProvider).findDuplicate(draft);
    final user = ref.watch(currentUserProvider);
    final byCategory = <String, List<ExamMarker>>{};
    for (final m in draft.markers) {
      byCategory.putIfAbsent(m.category, () => []).add(m);
    }
    final categories = byCategory.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ReportHeading(report: draft),
        if (user != null && (user.birthDate == null || user.sex == null))
          _Notice(
            color: AppColors.info,
            icon: Icons.person_outline,
            message:
                'Preencha data de nascimento e sexo no Perfil. Quando o PDF '
                'não traz esses dados, o app usa o seu perfil para escolher '
                'a faixa de referência.',
          ),
        if (duplicate != null)
          _Notice(
            color: AppColors.warning,
            icon: Icons.content_copy_outlined,
            message:
                'Este PDF já está no Histórico com a mesma data de coleta. '
                'Salvar de novo cria um laudo repetido.',
          ),
        Text(
          'Confira os valores lidos. Desmarque o que estiver errado; '
          'só o que ficar marcado vai para o Painel e a Evolução.',
          style: text.bodyMedium,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.error)),
        ],
        ...categories.expand((cat) {
          return [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(cat, style: text.titleMedium),
            ),
            ...byCategory[cat]!.map((m) {
              final kept = !_excluded.contains(m.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Material(
                  color: kept ? AppColors.surface : AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: CheckboxListTile(
                    value: kept,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _excluded.remove(m.id);
                      } else {
                        _excluded.add(m.id);
                      }
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      m.name,
                      style: kept
                          ? null
                          : const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textMuted,
                            ),
                    ),
                    subtitle: Text(
                      m.resultLabel +
                          (m.referenceText != null
                              ? '\nRef: ${m.referenceText}'
                              : ''),
                    ),
                    isThreeLine: m.referenceText != null,
                    secondary: StatusChip(status: m.status),
                  ),
                ),
              );
            }),
          ];
        }),
        if (draft.unrecognized.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Não interpretado', style: text.titleMedium),
          ...draft.unrecognized.map(
            (line) => Text('• $line', style: text.bodySmall),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _picker(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.heroWash,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 40, color: AppColors.teal),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.isOnboarding
                    ? 'Envie o PDF do seu exame de sangue'
                    : 'Adicionar novo laudo',
                style: text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'O app lê o PDF e mostra o que encontrou antes de salvar. '
                'Você confere os valores e desmarca o que estiver errado.',
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _loading ? null : _pickPdf,
          icon: const Icon(Icons.upload_file),
          label: const Text('Selecionar PDF do exame'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadSample,
          icon: const Icon(Icons.science_outlined),
          label: const Text('Carregar exame de exemplo'),
        ),
        if (widget.isOnboarding) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _loading ? null : () => context.go('/app'),
            child: const Text('Pular por agora'),
          ),
        ],
        if (_loading) ...[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Lendo o PDF e extraindo os resultados…',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Dica: use o PDF completo do laboratório. '
          'A interpretação dos resultados continua sendo responsabilidade do seu médico.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
