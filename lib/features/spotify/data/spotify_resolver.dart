import 'dart:convert';
import 'dart:io';

import '../domain/spotify_track.dart';

/// Reads a Spotify playlist/album/track's tracklist (title + artist) via the
/// public `embed` endpoint — no login, no API key. Validated with
/// `tool/test_spotify.dart`.
class SpotifyResolver {
  SpotifyResolver._();

  static bool isSpotifyUrl(String url) =>
      url.contains('spotify.com') ||
      url.contains('spotify:') ||
      url.contains('spotify.link');

  static Future<List<SpotifyTrack>> getTracks(String url) async {
    final ref = await _resolve(url);
    if (ref == null) return const [];
    final http = HttpClient();
    try {
      final req = await http.getUrl(
          Uri.parse('https://open.spotify.com/embed/${ref.type}/${ref.id}'));
      req.headers.set(HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final resp = await req.close();
      if (resp.statusCode != 200) return const [];
      final html = await resp.transform(utf8.decoder).join();
      final m = RegExp(
              r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
              dotAll: true)
          .firstMatch(html);
      if (m == null) return const [];
      final json = jsonDecode(m.group(1)!);
      final entity = json['props']?['pageProps']?['state']?['data']?['entity'];
      final list = entity?['trackList'] as List?;
      if (list == null) {
        // single track embed
        final title = entity?['title'];
        final sub = entity?['subtitle'];
        if (title is String && title.isNotEmpty) {
          return [SpotifyTrack(title, sub is String ? sub : '')];
        }
        return const [];
      }
      return [
        for (final t in list)
          if (t is Map && t['title'] is String)
            SpotifyTrack(t['title'] as String, (t['subtitle'] as String?) ?? ''),
      ];
    } catch (_) {
      return const [];
    } finally {
      http.close();
    }
  }

  static Future<({String type, String id})?> _resolve(String url) async {
    var u = url.trim();
    if (u.contains('spotify.link') || u.contains('spotify.app.link')) {
      u = await _followRedirect(u) ?? u;
    }
    final scheme =
        RegExp(r'spotify:(playlist|album|track):([A-Za-z0-9]+)').firstMatch(u);
    if (scheme != null) return (type: scheme.group(1)!, id: scheme.group(2)!);
    final web = RegExp(
            r'open\.spotify\.com/(?:intl-[a-z]+/)?(playlist|album|track)/([A-Za-z0-9]+)')
        .firstMatch(u);
    if (web != null) return (type: web.group(1)!, id: web.group(2)!);
    return null;
  }

  static Future<String?> _followRedirect(String url) async {
    final http = HttpClient();
    try {
      final req = await http.getUrl(Uri.parse(url));
      req.followRedirects = false;
      final resp = await req.close();
      await resp.drain<void>();
      if (resp.isRedirect) {
        return resp.headers.value(HttpHeaders.locationHeader);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      http.close();
    }
  }
}
