import 'dart:convert';
import 'dart:io';

/// End-to-end dry run of the YouTube Music import pipeline, without downloading:
/// album -> (title, artist) -> iTunes metadata -> LRCLIB lyrics.
/// Prints exactly what would get embedded in each file.
Future<void> main() async {
  final http = HttpClient()..badCertificateCallback = (c, h, p) => true;

  Future<dynamic> getJson(String url) async {
    final req = await http.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, 'EasyTube/1.3');
    final resp = await req.close();
    return jsonDecode(await resp.transform(utf8.decoder).join());
  }

  // 1) Album -> tracks (what PlaylistResolver does).
  const albumId = 'OLAK5uy_nE-SkwNA6lYF99wd-MHzJVqThnUIJGe3I';
  final req = await http.postUrl(Uri.parse(
      'https://www.youtube.com/youtubei/v1/browse'
      '?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'));
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode({
    'context': {
      'client': {'clientName': 'WEB', 'clientVersion': '2.20240101.00.00'}
    },
    'browseId': 'VL$albumId',
  }));
  final browse = jsonDecode(await (await req.close()).transform(utf8.decoder).join());

  final tracks = <(String, String, String)>[];
  void walk(dynamic n) {
    if (n is Map) {
      final lm = n['lockupViewModel'];
      if (lm is Map && lm['contentId'] is String) {
        final rows = <String>[];
        void grab(dynamic x) {
          if (x is Map) {
            if (x['content'] is String) rows.add(x['content'] as String);
            x.values.forEach(grab);
          } else if (x is List) {
            x.forEach(grab);
          }
        }

        grab(lm['metadata']);
        tracks.add((
          lm['contentId'] as String,
          rows.isNotEmpty ? rows.first : '',
          rows.length > 1 ? rows[1] : '',
        ));
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(browse);
  stdout.writeln('album tracks: ${tracks.length}\n');

  // 2+3) For each track: iTunes metadata + LRCLIB lyrics.
  for (final t in tracks.take(4)) {
    final (id, title, artist) = t;
    stdout.writeln('### $title — $artist  ($id)');

    final itunes = await getJson(
        'https://itunes.apple.com/search?media=music&entity=song&limit=1'
        '&term=${Uri.encodeQueryComponent("$artist $title")}');
    final res = (itunes['results'] as List?) ?? const [];
    if (res.isEmpty) {
      stdout.writeln('   iTunes: SIN MATCH');
    } else {
      final r = res.first as Map;
      stdout.writeln('   iTunes: ${r['artistName']} | ${r['trackName']} | '
          'album=${r['collectionName']} | genre=${r['primaryGenreName']} | '
          'year=${(r['releaseDate'] as String?)?.substring(0, 4)}');
    }

    final lrc = await getJson('https://lrclib.net/api/search'
        '?artist_name=${Uri.encodeQueryComponent(artist)}'
        '&track_name=${Uri.encodeQueryComponent(title)}');
    final list = (lrc as List?) ?? const [];
    final hit = list.cast<Map>().where((r) {
      final s = r['syncedLyrics'] as String?;
      final p = r['plainLyrics'] as String?;
      return (s != null && s.isNotEmpty) || (p != null && p.isNotEmpty);
    }).toList();
    if (hit.isEmpty) {
      stdout.writeln('   LRCLIB: sin letra');
    } else {
      final r = hit.first;
      final synced = r['syncedLyrics'] as String?;
      stdout.writeln('   LRCLIB: ${r['artistName']} | ${r['trackName']} | '
          'synced=${synced != null} '
          '| ${(synced ?? r['plainLyrics'] as String).split('\n').first}');
    }
    stdout.writeln();
  }
  http.close();
  exit(0);
}
