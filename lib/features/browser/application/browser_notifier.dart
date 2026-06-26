import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../domain/browser_state.dart';

final browserProvider =
    NotifierProvider<BrowserNotifier, BrowserState>(BrowserNotifier.new);

/// Whether the browser tab is the visible one. The shell updates it; the
/// browser pauses media when it turns false.
final browserActiveProvider = StateProvider<bool>((ref) => true);

class BrowserNotifier extends Notifier<BrowserState> {
  /// Set by [BrowserPage] so the app shell can drive WebView history (e.g. the
  /// Android back button) without owning the controller.
  WebViewController? controller;

  @override
  BrowserState build() => const BrowserState();

  /// Called on every URL change (including YouTube SPA `pushState`
  /// navigations). Re-derives the watchable video id from the URL.
  void onUrlChanged(String url) {
    state = state.copyWith(
      url: url,
      currentVideoId: () => extractVideoId(url),
      playlistId: () => extractPlaylistId(url),
    );
  }

  /// A real, downloadable playlist id. Excludes auto-generated radio mixes
  /// (`RD...`) which are effectively infinite.
  static String? extractPlaylistId(String url) {
    final id = Uri.tryParse(url)?.queryParameters['list'];
    if (id == null || id.isEmpty || id.startsWith('RD')) return null;
    return id;
  }

  void setTitle(String title) => state = state.copyWith(title: title);

  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);

  /// Throttled: only rebuild on coarse changes (every ~10%, plus 0 and 100) so
  /// page loads don't trigger dozens of widget rebuilds.
  void setProgress(int progress) {
    final next = progress / 100;
    final current = (state.progress * 100).round();
    if (progress == 0 || progress == 100 || (progress - current).abs() >= 10) {
      state = state.copyWith(progress: next);
    }
  }

  void setNavState({required bool canGoBack, required bool canGoForward}) =>
      state = state.copyWith(canGoBack: canGoBack, canGoForward: canGoForward);

  /// Extracts an 11-char YouTube video id from any of the URL shapes the
  /// mobile site produces: `/watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`.
  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final v = uri.queryParameters['v'];
    if (_isValidId(v)) return v;

    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final last = segments.last;
      if ((segments.contains('shorts') ||
              segments.contains('embed') ||
              uri.host.contains('youtu.be')) &&
          _isValidId(last)) {
        return last;
      }
    }
    return null;
  }

  static bool _isValidId(String? id) =>
      id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
}
