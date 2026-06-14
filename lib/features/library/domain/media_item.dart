import 'dart:io';

/// A playable file discovered on disk by the library scanner.
class MediaItem {
  const MediaItem({
    required this.path,
    required this.title,
    required this.isAudio,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final String title;
  final bool isAudio;
  final int sizeBytes;
  final DateTime modified;

  String get fileName => path.split(Platform.pathSeparator).last;

  String get readableSize {
    if (sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = sizeBytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}

/// Snapshot of the whole library, split by media kind.
class LibraryData {
  const LibraryData({this.videos = const [], this.audio = const []});

  final List<MediaItem> videos;
  final List<MediaItem> audio;

  bool get isEmpty => videos.isEmpty && audio.isEmpty;
}
