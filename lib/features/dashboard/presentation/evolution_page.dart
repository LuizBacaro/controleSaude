import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/marker_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../exams/presentation/widgets/status_chip.dart';

class EvolutionPage extends ConsumerStatefulWidget {
  const EvolutionPage({super.key});

  @override
  ConsumerState<EvolutionPage> createState() => _EvolutionPageState();
}

class _EvolutionPageState extends ConsumerState<EvolutionPage> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(markerSeriesProvider);
    final categories = series.map((s) => s.category).toSet().toList()..sort();

    final filtered = series.where((s) {
      final matchQuery =
          _query.isEmpty || s.name.toLowerCase().contains(_query.toLowerCase());
      final matchCat = _category == null || s.category == _category;
      return matchQuery && matchCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar marcador…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: const Text('Todos'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                    selectedColor: AppColors.surfaceElevated,
                  ),
                ),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                      selectedColor: AppColors.surfaceElevated,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum marcador encontrado',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final s = filtered[index];
                      final latest = s.latest;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        tileColor: AppColors.surface,
                        title: Text(s.name),
                        subtitle: Text(
                          latest == null
                              ? s.category
                              : '${latest.value} ${s.unit} · ${s.points.length} pontos',
                        ),
                        trailing: StatusChip(status: s.latestStatus),
                        onTap: () => context.push(markerRoute(s.name)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
