import 'dart:convert';
import 'dart:io';

const _key = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

String? _firstString(dynamic node, String key) {
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

void collectLockups(dynamic node, List<Map<String, String>> out) {
  if (node is Map) {
    final lm = node['lockupViewModel'];
    if (lm is Map && lm['contentId'] is String) {
      out.add({
        'id': lm['contentId'] as String,
        'title': _firstString(lm['metadata'], 'content') ?? '',
      });
    }
    for (final v in node.values) {
      collectLockups(v, out);
    }
  } else if (node is List) {
    for (final v in node) {
      collectLockups(v, out);
    }
  }
}

Future<void> main() async {
  const playlistId = 'PLlqZM4covn1EbvC_6cuERQ59QaMbPkUyE';
  final http = HttpClient();
  final req = await http.postUrl(
      Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=$_key'));
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode({
    'context': {
      'client': {'clientName': 'WEB', 'clientVersion': '2.20240101.00.00'}
    },
    'browseId': 'VL$playlistId',
  }));
  final resp = await req.close();
  final json = jsonDecode(await resp.transform(utf8.decoder).join());
  http.close();
  final out = <Map<String, String>>[];
  collectLockups(json, out);
  stdout.writeln('items: ${out.length}');
  for (final v in out.take(8)) {
    stdout.writeln('  ${v['id']}  ${v['title']}');
  }
  exit(0);
}
