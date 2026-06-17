import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const id = 'aqz-KE-bpKQ';

Future<int> probe(StreamInfo s) async {
  final http = HttpClient();
  try {
    final req = await http.getUrl(s.url);
    req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Linux; Android 13)');
    final resp = await req.close();
    if (resp.statusCode != 200 && resp.statusCode != 206) return -resp.statusCode;
    var got = 0;
    await for (final c in resp.timeout(const Duration(seconds: 15))) {
      got += c.length;
      if (got >= 400000) break;
    }
    return got;
  } on TimeoutException {
    return -1;
  } catch (_) {
    return -2;
  } finally {
    http.close(force: true);
  }
}

Future<void> main() async {
  final yt = YoutubeExplode();
  try {
    final m = await yt.videos.streamsClient
        .getManifest(id, ytClients: [YoutubeApiClient.androidVr]);
    stdout.writeln('muxed count=${m.muxed.length}: '
        '${m.muxed.map((e) => "${e.tag}/${e.qualityLabel}/${e.container.name}").join(", ")}');
    stdout.writeln('videoOnly mp4: '
        '${m.videoOnly.where((v) => v.container.name == "mp4").map((v) => "${v.tag}/${v.qualityLabel}").join(", ")}');
    stdout.writeln('audioOnly: '
        '${m.audioOnly.map((a) => "${a.tag}/${a.container.name}/${a.bitrate.kiloBitsPerSecond.round()}k").join(", ")}');

    // best h264 (mp4) video-only
    final h264 = m.videoOnly.where((v) => v.container.name == 'mp4').toList()
      ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    if (h264.isNotEmpty) {
      stdout.writeln('probe video ${h264.first.qualityLabel} itag=${h264.first.tag}: ${await probe(h264.first)}');
    }
    if (m.muxed.isNotEmpty) {
      stdout.writeln('probe muxed ${m.muxed.first.qualityLabel}: ${await probe(m.muxed.first)}');
    }
    for (final a in m.audioOnly.where((a) => a.container.name == 'mp4')) {
      stdout.writeln('probe audio itag=${a.tag} ${a.bitrate.kiloBitsPerSecond.round()}k: ${await probe(a)}');
    }
  } catch (e) {
    stdout.writeln('ERR ${e.toString().split("\n").first}');
  } finally {
    yt.close();
  }
  exit(0);
}
