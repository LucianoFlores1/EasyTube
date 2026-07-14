import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final http = HttpClient()..badCertificateCallback = (c, h, p) => true;
  for (final term in [
    'Black Veil Brides In The End',
    'Linkin Park In The End',
  ]) {
    final req = await http.getUrl(Uri.parse(
        'https://itunes.apple.com/search?media=music&entity=song&limit=1&term=${Uri.encodeQueryComponent(term)}'));
    final resp = await req.close();
    final json = jsonDecode(await resp.transform(utf8.decoder).join());
    final r = (json['results'] as List).isNotEmpty
        ? (json['results'] as List).first as Map
        : null;
    stdout.writeln('"$term" -> artist=${r?['artistName']} | '
        'title=${r?['trackName']} | album=${r?['collectionName']}');
  }
  http.close();
  exit(0);
}
