import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/spotify_resolver.dart';
import '../domain/spotify_track.dart';

final spotifyTracksProvider =
    FutureProvider.autoDispose.family<List<SpotifyTrack>, String>(
  (ref, url) => SpotifyResolver.getTracks(url),
);
