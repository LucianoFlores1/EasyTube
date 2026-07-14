import 'dart:convert';
import 'dart:io';

// iTunes Search API (no auth) as the metadata enrichment source.
Future<void> main() async {
  final http = HttpClient()
    ..badCertificateCallback = (cert, host, port) => true; // PC-only test
  for (final term in ['linkin park numb', 'ella langley choosin texas']) {
    try {
      final req = await http.getUrl(Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeQueryComponent(term)}&entity=song&limit=1'));
      final resp = await req.close();
      final json = jsonDecode(await resp.transform(utf8.decoder).join());
      final results = json['results'] as List;
      stdout.writeln('--- "$term" -> ${results.length} result(s)');
      if (results.isNotEmpty) {
        final r = results.first as Map;
        stdout.writeln('  title=${r['trackName']}');
        stdout.writeln('  artist=${r['artistName']}');
        stdout.writeln('  album=${r['collectionName']}');
        stdout.writeln('  genre=${r['primaryGenreName']}');
        stdout.writeln('  year=${r['releaseDate']}');
        stdout.writeln('  track=${r['trackNumber']}/${r['trackCount']}');
        stdout.writeln('  art=${r['artworkUrl100']}');
      }
    } catch (e) {
      stdout.writeln('ERROR: $e');
    }
  }
  http.close();
  exit(0);
}
