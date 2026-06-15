import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/browser/application/browser_notifier.dart';
import '../../features/library/presentation/mini_player.dart';

/// Hosts the four primary tabs and the persistent audio mini-player.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGoBackWeb = ref.watch(browserProvider.select((s) => s.canGoBack));
    final onBrowser = navigationShell.currentIndex == 0;

    return PopScope(
      // Only let the OS pop (exit) when we're on the browser tab with no web
      // history left; otherwise we handle back ourselves.
      canPop: onBrowser && !canGoBackWeb,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!onBrowser) {
          navigationShell.goBranch(0);
        } else if (canGoBackWeb) {
          ref.read(browserProvider.notifier).controller?.goBack();
        }
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public),
                label: 'Explorar',
              ),
              NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: 'Descargas',
              ),
              NavigationDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library),
                label: 'Biblioteca',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
