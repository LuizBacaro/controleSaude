import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Image.asset(
                      'assets/brand/app_icon.png',
                      width: 88,
                      height: 88,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Controle Saúde',
                  style: text.displayMedium?.copyWith(color: AppColors.teal),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Importe o PDF dos seus exames de sangue e acompanhe a evolução de cada marcador ao longo do tempo.',
                  style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.push('/criar-conta'),
                  child: const Text('Criar conta'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push('/entrar'),
                  child: const Text('Já tenho conta'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Os dados ficam neste aparelho. A interpretação clínica é ato médico.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
