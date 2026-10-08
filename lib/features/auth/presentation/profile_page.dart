import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              (user?.displayName.isNotEmpty == true
                      ? user!.displayName[0]
                      : '?')
                  .toUpperCase(),
              style: text.headlineMedium?.copyWith(color: AppColors.teal),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(user?.displayName ?? '', style: text.headlineSmall),
          Text(user?.email ?? '', style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text('${summary.reportCount} laudos salvos'),
            subtitle: Text('${summary.totalMarkers} marcadores acompanhados'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: const Text('Importar novo PDF'),
            onTap: () => context.push('/importar'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            subtitle: const Text(
              'ExameFácil não substitui consulta médica. '
              'Dados armazenados localmente neste aparelho.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(authRevisionProvider.notifier).bump();
              if (context.mounted) context.go('/');
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
