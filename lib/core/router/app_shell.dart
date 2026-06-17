import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/browser/application/browser_notifier.dart';
import '../../features/extractor/presentation/extractor_sheet.dart';
import '../../features/library/presentation/mini_player.dart';
import '../../shared/providers/shared_url_provider.dart';

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

    // A link shared into the app opens the download sheet directly.
    ref.listen(sharedUrlProvider, (_, url) {
      if (url == null) return;
      ref.read(sharedUrlProvider.notifier).clear();
      final link = RegExp(r'https?://\S+').firstMatch(url)?.group(0) ?? url;
      final videoId = BrowserNotifier.extractVideoId(link);
      if (videoId == null) return;
      final playlistId = BrowserNotifier.extractPlaylistId(link);
      navigationShell.goBranch(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              ExtractorSheet(videoId: videoId, playlistId: playlistId),
        );
      });
    });

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

/// Swipeable container for the shell branches. Renders all branches in a
/// [PageView] (kept alive so the WebView never reloads) and keeps the
/// PageView, the bottom nav and go_router's branch index in sync.
class ShellPageView extends StatefulWidget {
  const ShellPageView({
    required this.navigationShell,
    required this.children,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<ShellPageView> createState() => _ShellPageViewState();
}

class _ShellPageViewState extends State<ShellPageView> {
  late final PageController _controller =
      PageController(initialPage: widget.navigationShell.currentIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    // Sync PageView when the index changed via a tab tap.
    if (_controller.hasClients && _controller.page?.round() != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    return PageView(
      controller: _controller,
      onPageChanged: (i) => widget.navigationShell.goBranch(
        i,
        initialLocation: i == widget.navigationShell.currentIndex,
      ),
      children: [
        for (final child in widget.children) _KeepAlive(child: child),
      ],
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
