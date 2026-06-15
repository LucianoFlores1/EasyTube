import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const id = 'kXYiU_JCYtU'; // Coldplay - The Scientist

Future<void> main() async {
  final yt = YoutubeExplode();
  try {
    stdout.writeln('Fetching manifest (muxed)...');
    final manifest = await yt.videos.streamsClient.getManifest(id);
    final muxed = manifest.muxed.sortByVideoQuality();
    for (final m in muxed) {
      stdout.writeln('  muxed itag=${m.tag} ${m.qualityLabel} '
          '${m.container.name} size=${m.size.totalBytes}');
    }
    final best = muxed.first; // highest quality muxed
    stdout.writeln('Downloading muxed itag=${best.tag} via HttpClient...');

    final http = HttpClient();
    final req = await http.getUrl(best.url);
    req.headers.set(HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36');
    final resp = await req.close();
    stdout.writeln('HTTP status=${resp.statusCode} '
        'contentLength=${resp.contentLength}');

    var received = 0;
    final sw = Stopwatch()..start();
    await for (final chunk in resp.timeout(const Duration(seconds: 25))) {
      received += chunk.length;
      if (received >= 800000) break;
    }
    final kbps = (received / 1024) / (sw.elapsedMilliseconds / 1000);
    stdout.writeln('GOT=$received bytes in ${sw.elapsedMilliseconds}ms '
        '(${kbps.toStringAsFixed(0)} KB/s)');
    http.close(force: true);
  } catch (e) {
    stdout.writeln('ERROR: ${e.toString().split('\n').first}');
  } finally {
    yt.close();
  }
  exit(0);
}
