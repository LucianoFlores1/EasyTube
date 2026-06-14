import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/browser/presentation/browser_page.dart';
import '../../features/downloader/presentation/downloads_page.dart';
import '../../features/library/domain/media_item.dart';
import '../../features/library/presentation/audio_player_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/library/presentation/video_player_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import 'app_shell.dart';

/// Route names used across the app for type-safe navigation.
class Routes {
  Routes._();
  static const browser = '/browser';
  static const downloads = '/downloads';
  static const library = '/library';
  static const settings = '/settings';
  static const videoPlayer = '/player/video';
  static const audioPlayer = '/player/audio';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.browser,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellKey,
          routes: [
            GoRoute(
              path: Routes.browser,
              builder: (context, state) => const BrowserPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.downloads,
              builder: (context, state) => const DownloadsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.library,
              builder: (context, state) => const LibraryPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.settings,
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.videoPlayer,
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          VideoPlayerPage(item: state.extra as MediaItem),
    ),
    GoRoute(
      path: Routes.audioPlayer,
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          AudioPlayerPage(item: state.extra as MediaItem),
    ),
  ],
);
