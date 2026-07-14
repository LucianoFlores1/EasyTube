import 'dart:convert';
import 'dart:io';

import '../domain/track_meta.dart';

/// Enriches a song's metadata (album, year, genre, high-res cover) using the
/// free, no-auth iTunes Search API. Best-effort: returns null on no match.
class MetadataEnricher {
  MetadataEnricher._();

  static Future<TrackMeta?> enrich(String title, String artist) async {
    final term = '$artist $title'.trim();
    if (term.isEmpty) return null;
    final http = HttpClient();
    try {
      final req = await http.getUrl(Uri.parse(
          'https://itunes.apple.com/search?media=music&entity=song&limit=1'
          '&term=${Uri.encodeQueryComponent(term)}'));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final r = results.first as Map;

      final art = (r['artworkUrl100'] as String?)
              ?.replaceAll('100x100bb', '600x600bb') ??
          '';
      int? year;
      final date = r['releaseDate'] as String?;
      if (date != null && date.length >= 4) {
        year = int.tryParse(date.substring(0, 4));
      }
      return TrackMeta(
        artist: (r['artistName'] as String?) ?? artist,
        album: (r['collectionName'] as String?) ?? '',
        genre: (r['primaryGenreName'] as String?) ?? '',
        coverUrl: art,
        year: year,
        trackNumber: r['trackNumber'] as int?,
      );
    } catch (_) {
      return null;
    } finally {
      http.close();
    }
  }
}
