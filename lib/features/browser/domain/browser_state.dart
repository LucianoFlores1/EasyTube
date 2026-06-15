/// Immutable state of the in-app micro-browser.
class BrowserState {
  const BrowserState({
    this.url = '',
    this.title = '',
    this.isLoading = false,
    this.progress = 0,
    this.currentVideoId,
    this.playlistId,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  final String url;
  final String title;
  final bool isLoading;
  final double progress;

  /// Non-null when the current page is a watchable YouTube video.
  final String? currentVideoId;

  /// Non-null when the current page belongs to a real (non-radio) playlist.
  final String? playlistId;
  final bool canGoBack;
  final bool canGoForward;

  bool get hasVideo => currentVideoId != null && currentVideoId!.isNotEmpty;
  bool get hasPlaylist => playlistId != null && playlistId!.isNotEmpty;

  BrowserState copyWith({
    String? url,
    String? title,
    bool? isLoading,
    double? progress,
    String? Function()? currentVideoId,
    String? Function()? playlistId,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    return BrowserState(
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      currentVideoId:
          currentVideoId != null ? currentVideoId() : this.currentVideoId,
      playlistId: playlistId != null ? playlistId() : this.playlistId,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
    );
  }
}
