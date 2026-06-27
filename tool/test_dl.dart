import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main() async {
  final yt = YoutubeExplode();
  try {
    final res = await yt.search
        .searchContent('linkin park numb', filter: TypeFilters.video);
    final videos = res.whereType<SearchVideo>().toList();
    stdout.writeln('videos: ${videos.length}');
    for (final v in videos.take(6)) {
      stdout.writeln('  ${v.id.value}  [${v.duration}]  ${v.title}');
    }
  } catch (e) {
    stdout.writeln('ERROR: $e');
  }
  yt.close();
  exit(0);
}
