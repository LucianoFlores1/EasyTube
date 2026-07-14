/// Rich music metadata to embed in a downloaded file (from iTunes lookup).
class TrackMeta {
  const TrackMeta({
    required this.artist,
    required this.album,
    required this.genre,
    required this.coverUrl,
    this.year,
    this.trackNumber,
  });

  final String artist;
  final String album;
  final String genre;

  /// High-res cover art URL (preferred over the YouTube thumbnail).
  final String coverUrl;
  final int? year;
  final int? trackNumber;
}
