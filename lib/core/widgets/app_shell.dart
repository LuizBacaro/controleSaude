import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_colors.dart';

/// Monta só a aba já visitada. O [IndexedStack] padrão construía Painel,
/// Evolução, Histórico e Perfil juntos na primeira abertura.
class LazyBranchStack extends StatefulWidget {
  const LazyBranchStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<LazyBranchStack> createState() => _LazyBranchStackState();
}

class _LazyBranchStackState extends State<LazyBranchStack> {
  late final Set<int> _visited = {widget.currentIndex};
  int? _epoch;

  @override
  void didUpdateWidget(LazyBranchStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final epoch = ShellEpochScope.of(context);
    if (_epoch != null && _epoch != epoch) {
      _visited
        ..clear()
        ..add(widget.currentIndex);
    }
    _epoch = epoch;

    return IndexedStack(
      index: widget.currentIndex,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited.contains(i)
              ? TickerMode(
                  enabled: i == widget.currentIndex,
                  child: widget.children[i],
                )
              : const SizedBox.shrink(),
      ],
    );
  }
}

class ShellEpochScope extends InheritedWidget {
  const ShellEpochScope({super.key, required this.epoch, required super.child});

  final int epoch;

  static int of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellEpochScope>();
    return scope?.epoch ?? 0;
  }

  @override
  bool updateShouldNotify(ShellEpochScope oldWidget) => epoch != oldWidget.epoch;
}

Widget lazyBranchContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  return LazyBranchStack(
    currentIndex: navigationShell.currentIndex,
    children: children,
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _NavItem('Painel', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _NavItem('Evolução', Icons.timeline_outlined, Icons.timeline),
    _NavItem('Histórico', Icons.folder_outlined, Icons.folder_rounded),
    _NavItem(
      'Médicos',
      Icons.medical_services_outlined,
      Icons.medical_services,
    ),
    _NavItem('Perfil', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(shellEpochProvider);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final fab = navigationShell.currentIndex == 2
        ? FloatingActionButton.extended(
            onPressed: () => context.push('/importar'),
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.upload_file),
            label: const Text('Novo PDF'),
          )
        : null;

    final scaffold = wide
        ? Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: navigationShell.goBranch,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selected),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
            floatingActionButton: fab,
          )
        : Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selected),
                    label: item.label,
                  ),
              ],
              indicatorColor: AppColors.surfaceElevated,
            ),
            floatingActionButton: fab,
          );

    return ShellEpochScope(epoch: epoch, child: scaffold);
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selected);

  final String label;
  final IconData icon;
  final IconData selected;
}
