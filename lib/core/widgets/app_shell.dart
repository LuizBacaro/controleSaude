import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void didUpdateWidget(LazyBranchStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
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

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Painel',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Evolução',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        indicatorColor: AppColors.surfaceElevated,
      ),
      floatingActionButton: navigationShell.currentIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/importar'),
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file),
              label: const Text('Novo PDF'),
            )
          : null,
    );
  }
}
