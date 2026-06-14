/// A user-confirmed request produced by the extractor sheet and handed to the
/// downloader queue.
class DownloadRequest {
  const DownloadRequest({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.url,
    required this.container,
    required this.isAudio,
    required this.convertToMp3,
    required this.quality,
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;

  /// Direct stream URL resolved by youtube_explode.
  final String url;

  /// Final container shown to the user (`mp4`, `m4a`, `mp3`).
  final String container;
  final bool isAudio;

  /// When true the stream is downloaded as m4a then transcoded to mp3.
  final bool convertToMp3;
  final String quality;
}
