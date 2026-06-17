import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A user-confirmed request produced by the extractor sheet.
class DownloadRequest {
  const DownloadRequest({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.audioStream,
    required this.videoStream,
    required this.container,
    required this.isAudio,
    required this.audioFormat,
    required this.quality,
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;

  /// AAC audio-only stream (audio source / merge audio).
  final StreamInfo audioStream;

  /// Video-only stream for video downloads; null for audio.
  final StreamInfo? videoStream;

  final String container;
  final bool isAudio;

  /// `m4a` or `mp3` for audio downloads; null for video.
  final String? audioFormat;
  final String quality;
}
