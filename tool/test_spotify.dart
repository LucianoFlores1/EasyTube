import 'dart:convert';
import 'dart:io';

// LRCLIB (free, no auth) as the lyrics source.
Future<void> main() async {
  final http = HttpClient()..badCertificateCallback = (c, h, p) => true;
  for (final t in [
    ('Linkin Park', 'Numb'),
    ('Black Veil Brides', 'In The End'),
  ]) {
    final url = Uri.parse('https://lrclib.net/api/search'
        '?artist_name=${Uri.encodeQueryComponent(t.$1)}'
        '&track_name=${Uri.encodeQueryComponent(t.$2)}');
    final req = await http.getUrl(url);
    req.headers.set(HttpHeaders.userAgentHeader, 'EasyTube/1.0');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    stdout.writeln('=== ${t.$1} - ${t.$2} (status ${resp.statusCode})');
    final list = jsonDecode(body) as List;
    stdout.writeln('  results=${list.length}');
    if (list.isNotEmpty) {
      final r = list.first as Map;
      final synced = r['syncedLyrics'] as String?;
      final plain = r['plainLyrics'] as String?;
      stdout.writeln('  match: ${r['artistName']} - ${r['trackName']} '
          '(${r['albumName']}) dur=${r['duration']}');
      stdout.writeln('  hasSynced=${synced != null} hasPlain=${plain != null}');
      if (synced != null) {
        stdout.writeln('  synced head: ${synced.split('\n').take(2).join(" | ")}');
      }
    }
  }
  http.close();
  exit(0);
}
