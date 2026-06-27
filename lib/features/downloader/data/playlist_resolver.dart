import 'dart:convert';
import 'dart:io';

class PlaylistVideo {
  const PlaylistVideo(this.id, this.title);
  final String id;
  final String title;
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
        out.add(PlaylistVideo(
          lm['contentId'] as String,
          _firstString(lm['metadata'], 'content') ?? '',
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

  static String? _firstString(dynamic node, String key) {
    if (node is Map) {
      if (node[key] is String) return node[key] as String;
      for (final v in node.values) {
        final r = _firstString(v, key);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _firstString(v, key);
        if (r != null) return r;
      }
    }
    return null;
  }
}
