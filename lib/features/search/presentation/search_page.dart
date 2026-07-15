import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/thumbnail_image.dart';
import '../../../shared/youtube_ids.dart';
import '../../extractor/presentation/extractor_sheet.dart';
import '../../spotify/data/spotify_resolver.dart';
import '../../spotify/presentation/spotify_import_page.dart';
import '../../ytmusic/presentation/music_import_page.dart';
import '../application/search_providers.dart';
import 'playlist_page.dart';

void openDownloadSheet(BuildContext context, String videoId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExtractorSheet(videoId: videoId),
  );
}

String thumbUrl(String videoId) =>
    'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _field = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _importList() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Link de Spotify o YouTube Music',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Importar')),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    if (SpotifyResolver.isSpotifyUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SpotifyImportPage(url: url)),
      );
      return;
    }
    final playlistId = YoutubeIds.playlistId(url);
    if (YoutubeIds.isMusicUrl(url) && playlistId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MusicImportPage(playlistId: playlistId)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pegá un link de playlist/álbum de Spotify o '
            'YouTube Music'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: SizedBox(
            height: 42,
            child: TextField(
              controller: _field,
              textInputAction: TextInputAction.search,
              autofocus: false,
              onSubmitted: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                hintText: 'Buscar en YouTube',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _field.clear();
                          setState(() => _query = '');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Importar lista (Spotify / YouTube Music)',
              icon: const Icon(Icons.playlist_add),
              onPressed: _importList,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.brandRed,
            tabs: [Tab(text: 'Videos'), Tab(text: 'Listas')],
          ),
        ),
        body: _query.isEmpty
            ? const EmptyState(
                icon: Icons.search,
                title: 'Buscá en YouTube',
                message: 'Escribí arriba para encontrar videos o listas y '
                    'descargarlos.',
              )
            : TabBarView(
                children: [
                  _VideoResults(query: _query),
                  _PlaylistResults(query: _query),
                ],
              ),
      ),
    );
  }
}

class _VideoResults extends ConsumerWidget {
  const _VideoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(searchVideosProvider(query)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo buscar',
            message: e.toString(),
          ),
          data: (videos) => videos.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                  message: 'Probá con otras palabras.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _VideoTile(video: videos[i]),
                ),
        );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video});
  final SearchVideo video;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openDownloadSheet(context, video.id.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ThumbnailImage(
                    url: thumbUrl(video.id.value), width: 128, height: 72),
                if (video.duration.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(video.duration,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(video.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted)),
                ],
              ),
            ),
            const Icon(Icons.download_outlined, color: AppColors.brandRed),
          ],
        ),
      ),
    );
  }
}

class _PlaylistResults extends ConsumerWidget {
  const _PlaylistResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(searchPlaylistsProvider(query)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo buscar',
            message: e.toString(),
          ),
          data: (lists) => lists.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Sin listas',
                  message: 'Probá con otras palabras.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: lists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _PlaylistTile(playlist: lists[i]),
                ),
        );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist});
  final SearchPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistPage(
          playlistId: playlist.id.value,
          title: playlist.title,
        ),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 128, height: 72, color: AppColors.surfaceVariant),
                const Icon(Icons.playlist_play, size: 32, color: Colors.white70),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('${playlist.videoCount} videos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}
