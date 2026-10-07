import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ImportExamPage extends ConsumerStatefulWidget {
  const ImportExamPage({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<ImportExamPage> createState() => _ImportExamPageState();
}

class _ImportExamPageState extends ConsumerState<ImportExamPage> {
  var _loading = false;
  String? _error;
  String? _success;

  Future<void> _pickPdf() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
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
      if (file.bytes != null) {
        await repo.importPdfBytes(file.bytes!, fileName: file.name);
      } else if (file.path != null) {
        await repo.importPdfFile(File(file.path!));
      } else {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }

      ref.read(examsRevisionProvider.notifier).bump();
      if (!mounted) return;
      _goAfterImport(file.name);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadSample() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final report = await ref.read(examsRepositoryProvider).importSample();
      ref.read(examsRevisionProvider.notifier).bump();
      if (!mounted) return;
      _goAfterImport(report.sourceFileName ?? 'exemplo');
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _goAfterImport(String name) {
    setState(() {
      _loading = false;
      _success = 'Exame "$name" importado com sucesso.';
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      context.go('/app');
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Seu primeiro exame' : 'Importar PDF'),
        leading: widget.isOnboarding
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: ListView(
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
                  'O app lê os resultados (hemograma, glicose, lipídico, INR, etc.), gera o painel e guarda o histórico para comparar a evolução.',
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
              'Lendo o PDF e extraindo os marcadores…',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.error)),
          ],
          if (_success != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(_success!, style: text.bodyMedium?.copyWith(color: AppColors.success)),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Dica: use o PDF completo do laboratório (como o laudo Unilab). '
            'A interpretação dos resultados continua sendo responsabilidade do seu médico.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
