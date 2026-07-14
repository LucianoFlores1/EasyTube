import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/extractor/presentation/extractor_sheet.dart';
import '../../features/library/presentation/mini_player.dart';
import '../../features/spotify/data/spotify_resolver.dart';
import '../../features/spotify/presentation/spotify_import_page.dart';
import '../../shared/providers/shared_url_provider.dart';
import '../../shared/youtube_ids.dart';

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
    final onFirstTab = navigationShell.currentIndex == 0;

    // A link shared into the app opens the download sheet directly.
    ref.listen(sharedUrlProvider, (_, url) {
      if (url == null) return;
      ref.read(sharedUrlProvider.notifier).clear();
      final link = RegExp(r'https?://\S+').firstMatch(url)?.group(0) ?? url;

      // Spotify link -> import flow.
      if (SpotifyResolver.isSpotifyUrl(link)) {
        navigationShell.goBranch(0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => SpotifyImportPage(url: link)),
          );
        });
        return;
      }

      final videoId = YoutubeIds.videoId(link);
      if (videoId == null) return;
      final playlistId = YoutubeIds.playlistId(link);
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
      // Back exits only from the first tab; otherwise jump back to it.
      canPop: onFirstTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !onFirstTab) navigationShell.goBranch(0);
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
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Buscar',
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
