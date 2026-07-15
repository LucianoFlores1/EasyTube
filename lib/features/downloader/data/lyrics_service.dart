import 'dart:convert';
import 'dart:io';

import '../domain/lyrics.dart';

/// Fetches lyrics from LRCLIB (open database, no auth, no key).
///
/// Best-effort: returns null when the song isn't in the database, so a missing
/// lyric never breaks a download.
class LyricsService {
  LyricsService._();

  static Future<Lyrics?> fetch(String artist, String title) async {
    if (artist.isEmpty || title.isEmpty) return null;
    final http = HttpClient();
    try {
      final req = await http.getUrl(Uri.parse('https://lrclib.net/api/search'
          '?artist_name=${Uri.encodeQueryComponent(artist)}'
          '&track_name=${Uri.encodeQueryComponent(title)}'));
      // LRCLIB asks clients to identify themselves.
      req.headers.set(HttpHeaders.userAgentHeader,
          'EasyTube (https://github.com/LucianoFlores1/EasyTube)');
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      if (body is! List) return null;
      // Results are relevance-ranked; take the first that actually has words.
      // Instrumentals are skipped: their "lyrics" is the word "Instrumental".
      for (final r in body) {
        if (r is! Map || r['instrumental'] == true) continue;
        final synced = r['syncedLyrics'] as String?;
        final plain = r['plainLyrics'] as String?;
        final hasSynced = synced != null && synced.isNotEmpty;
        final hasPlain = plain != null && plain.isNotEmpty;
        if (hasSynced || hasPlain) {
          return Lyrics(
            plain: hasPlain ? plain : null,
            synced: hasSynced ? synced : null,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      http.close();
    }
  }
}
