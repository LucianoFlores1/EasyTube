import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloader/data/playlist_resolver.dart';

/// Tracks of a YouTube Music album/playlist, keyed by its playlist id.
final musicTracksProvider =
    FutureProvider.family<List<PlaylistVideo>, String>((ref, playlistId) {
  return PlaylistResolver.getVideos(playlistId, limit: 50);
});
