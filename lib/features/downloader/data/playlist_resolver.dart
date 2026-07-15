import 'dart:convert';
import 'dart:io';

class PlaylistVideo {
  const PlaylistVideo(this.id, this.title, this.author);
  final String id;
  final String title;

  /// Channel/artist row. Empty when the response doesn't carry one.
  final String author;
}

/// Enumerates a playlist's videos via YouTube's InnerTube `browse` endpoint.
///
/// youtube_explode's own `playlists.getVideos` is broken on current YouTube
/// (its parser drops every item, returning 0). The WEB InnerTube response
/// lists videos as `lockupViewModel` nodes, which we collect directly.
///
/// Validated by `tool/test_dl.dart` (Meteora playlist -> 13 id/title pairs).
class PlaylistResolver {
  PlaylistResolver._();

  // Public YouTube web InnerTube key (stable, not a secret).
  static const _key = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  static Future<List<PlaylistVideo>> getVideos(
    String playlistId, {
    int limit = 50,
  }) async {
    final http = HttpClient();
    try {
      final req = await http.postUrl(Uri.parse(
          'https://www.youtube.com/youtubei/v1/browse?key=$_key'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'context': {
          'client': {'clientName': 'WEB', 'clientVersion': '2.20240101.00.00'}
        },
        'browseId': 'VL$playlistId',
      }));
      final resp = await req.close();
      if (resp.statusCode != 200) return const [];
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      final out = <PlaylistVideo>[];
      _collect(json, out);
      return out.length > limit ? out.sublist(0, limit) : out;
    } catch (_) {
      return const [];
    } finally {
      http.close();
    }
  }

  static void _collect(dynamic node, List<PlaylistVideo> out) {
    if (node is Map) {
      final lm = node['lockupViewModel'];
      if (lm is Map && lm['contentId'] is String) {
        // Metadata rows come in order: [0] title, [1] channel/artist, then
        // view count and age. Validated by `tool/test_dl.dart`.
        final rows = <String>[];
        _contents(lm['metadata'], rows);
        out.add(PlaylistVideo(
          lm['contentId'] as String,
          rows.isNotEmpty ? rows.first : '',
          rows.length > 1 && !_isStat(rows[1]) ? rows[1] : '',
        ));
      }
      for (final v in node.values) {
        _collect(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        _collect(v, out);
      }
    }
  }

  static final _stat = RegExp(
    r'\b(views|vistas|visualizaciones|reproducciones)\b',
    caseSensitive: false,
  );

  static bool _isStat(String s) => _stat.hasMatch(s);

  static void _contents(dynamic node, List<String> out) {
    if (node is Map) {
      if (node['content'] is String) out.add(node['content'] as String);
      for (final v in node.values) {
        _contents(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        _contents(v, out);
      }
    }
  }
}
