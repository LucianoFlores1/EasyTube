import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum MediaKind { video, audio }

/// A downloadable option. Video options pair a video-only stream with an
/// audio-only stream (merged with FFmpeg) to allow native resolutions; audio
/// options use the audio-only stream directly.
class StreamOption {
  const StreamOption({
    required this.label,
    required this.kind,
    required this.container,
    required this.audioStream,
    this.videoStream,
    this.audioFormat,
    this.height,
    this.sizeBytes,
  });

  final String label;
  final MediaKind kind;

  /// Final container shown to the user (`mp4`, `m4a`, `mp3`).
  final String container;

  /// AAC audio-only stream: the audio source for both audio downloads and the
  /// merge step of video downloads.
  final StreamInfo audioStream;

  /// Video-only stream for video options; null for audio.
  final StreamInfo? videoStream;

  /// For audio options: `m4a` (save as-is) or `mp3` (transcode). Null for video.
  final String? audioFormat;

  final int? height;
  final int? sizeBytes;

  bool get isAudio => kind == MediaKind.audio;

  String get readableSize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
