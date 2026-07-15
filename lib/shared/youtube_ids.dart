/// Pure helpers to pull YouTube video/playlist ids out of a URL.
class YoutubeIds {
  YoutubeIds._();

  /// 11-char video id from any URL shape (`/watch?v=`, `youtu.be/`,
  /// `/shorts/`, `/embed/`).
  static String? videoId(String url) {
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

  /// True for YouTube Music links (`music.youtube.com/...`).
  static bool isMusicUrl(String url) =>
      Uri.tryParse(url)?.host.contains('music.youtube.com') ?? false;

  /// A real, downloadable playlist id. Excludes auto-generated radio mixes
  /// (`RD...`), which aren't enumerable.
  static String? playlistId(String url) {
    final id = Uri.tryParse(url)?.queryParameters['list'];
    if (id == null || id.isEmpty || id.startsWith('RD')) return null;
    return id;
  }

  static bool _isValidId(String? id) =>
      id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
}
