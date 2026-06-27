import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/thumbnail_image.dart';
import '../../extractor/presentation/extractor_sheet.dart';
import '../application/search_providers.dart';
import 'search_page.dart';

class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({required this.playlistId, required this.title, super.key});

  final String playlistId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playlistVideosProvider(playlistId));
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo abrir la lista',
          message: e.toString(),
        ),
        data: (videos) {
          if (videos.isEmpty) {
            return const EmptyState(
              icon: Icons.playlist_remove,
              title: 'Lista vacía',
              message: 'No se encontraron videos (¿privada o un Mix?).',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ExtractorSheet(
                      videoId: videos.first.id,
                      playlistId: playlistId,
                    ),
                  ),
                  icon: const Icon(Icons.download),
                  label: Text('Descargar lista completa (${videos.length})'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (_, i) {
                    final v = videos[i];
                    return InkWell(
                      onTap: () => openDownloadSheet(context, v.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            ThumbnailImage(
                                url: thumbUrl(v.id), width: 88, height: 50),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                v.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.download_outlined,
                                size: 20, color: Colors.white54),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
