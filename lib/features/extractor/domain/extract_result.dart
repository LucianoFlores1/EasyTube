import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'stream_option.dart';

/// Metadata + the available download options for a single video.
class ExtractResult {
  const ExtractResult({
    required this.video,
    required this.videoOptions,
    required this.audioOptions,
  });

  final Video video;
  final List<StreamOption> videoOptions;
  final List<StreamOption> audioOptions;

  String get title => video.title;
  String get author => video.author;
  Duration? get duration => video.duration;
  String get thumbnailUrl => video.thumbnails.highResUrl;

  String get readableDuration {
    final d = duration;
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
