import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum MediaKind { video, audio }

/// A single downloadable option presented in the extractor sheet.
///
/// All options download a *muxed* (progressive) stream, which YouTube serves
/// over a plain HTTP GET. Audio options extract the audio track from that muxed
/// stream with FFmpeg — this avoids the adaptive (DASH) audio-only streams that
/// YouTube blocks/throttles for non-browser clients.
class StreamOption {
  const StreamOption({
    required this.label,
    required this.kind,
    required this.container,
    required this.streamInfo,
    this.height,
    this.bitrate,
    this.sizeBytes,
    this.audioCodec,
  });

  final String label;
  final MediaKind kind;

  /// Final container shown to the user (`mp4`, `m4a`, `mp3`).
  final String container;

  /// The muxed source stream fetched from YouTube.
  final StreamInfo streamInfo;

  final int? height;
  final int? bitrate;
  final int? sizeBytes;

  /// FFmpeg audio codec for extraction: `copy` (m4a), `libmp3lame` (mp3), or
  /// null for a plain video download (no transcode).
  final String? audioCodec;

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
