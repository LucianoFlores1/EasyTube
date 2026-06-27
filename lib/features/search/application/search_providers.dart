import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../shared/providers/youtube_explode_provider.dart';
import '../../downloader/data/playlist_resolver.dart';

final searchVideosProvider =
    FutureProvider.autoDispose.family<List<SearchVideo>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return const [];
    final res = await ref
        .watch(youtubeExplodeProvider)
        .search
        .searchContent(query, filter: TypeFilters.video);
    return res.whereType<SearchVideo>().toList();
  },
);

final searchPlaylistsProvider =
    FutureProvider.autoDispose.family<List<SearchPlaylist>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return const [];
    final res = await ref
        .watch(youtubeExplodeProvider)
        .search
        .searchContent(query, filter: TypeFilters.playlist);
    return res.whereType<SearchPlaylist>().toList();
  },
);

final playlistVideosProvider =
    FutureProvider.autoDispose.family<List<PlaylistVideo>, String>(
  (ref, playlistId) => PlaylistResolver.getVideos(playlistId, limit: 100),
);
