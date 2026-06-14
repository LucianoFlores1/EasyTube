import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum MediaKind { video, audio }

/// A single downloadable option presented in the extractor sheet.
class StreamOption {
  const StreamOption({
    required this.label,
    required this.kind,
    required this.container,
    required this.streamInfo,
    this.height,
    this.bitrate,
    this.sizeBytes,
    this.convertToMp3 = false,
  });

  final String label;
  final MediaKind kind;

  /// Target container shown to the user (`mp4`, `m4a`, `mp3`).
  final String container;

  /// The source stream fetched from YouTube. For the MP3 option this is the
  /// best audio-only stream, transcoded after download.
  final StreamInfo streamInfo;

  final int? height;
  final int? bitrate;
  final int? sizeBytes;
  final bool convertToMp3;

  bool get isAudio => kind == MediaKind.audio;

  String get url => streamInfo.url.toString();

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
