import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A user-confirmed request produced by the extractor sheet and handed to the
/// downloader queue.
class DownloadRequest {
  const DownloadRequest({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.streamInfo,
    required this.container,
    required this.isAudio,
    required this.audioCodec,
    required this.quality,
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;

  /// Muxed source stream resolved by youtube_explode. Downloaded over a plain
  /// HTTP GET (works without throttling, unlike adaptive streams).
  final StreamInfo streamInfo;

  /// Final container shown to the user (`mp4`, `m4a`, `mp3`).
  final String container;
  final bool isAudio;

  /// FFmpeg audio codec for extraction (`copy`/`libmp3lame`), or null for a
  /// plain video download.
  final String? audioCodec;
  final String quality;
}
