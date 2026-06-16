import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_snackbar.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/thumbnail_image.dart';
import '../application/audio_player_notifier.dart';
import '../application/library_notifier.dart';
import '../domain/media_item.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => ref.read(libraryProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.brandRed,
            tabs: [
              Tab(text: 'Videos', icon: Icon(Icons.movie_outlined)),
              Tab(text: 'Audio', icon: Icon(Icons.audiotrack_outlined)),
            ],
          ),
        ),
        body: libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo leer la biblioteca',
            message: e.toString(),
          ),
          data: (data) => TabBarView(
            children: [
              _MediaGrid(items: data.videos, isAudio: false),
              _MediaGrid(items: data.audio, isAudio: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  const _MediaGrid({required this.items, required this.isAudio});

  final List<MediaItem> items;
  final bool isAudio;

  void _open(BuildContext context, WidgetRef ref, MediaItem item) {
    if (item.isAudio) {
      ref.read(currentAudioProvider.notifier).play(item);
      context.push(Routes.audioPlayer, extra: item);
    } else {
      context.push(Routes.videoPlayer, extra: item);
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartir'),
              onTap: () {
                Navigator.pop(sheetContext);
                SharePlus.instance.share(ShareParams(files: [XFile(item.path)]));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.brandRed),
              title: const Text('Eliminar'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _confirmDelete(context, ref, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Eliminar "${item.title}" del dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryProvider.notifier).delete(item);
    if (context.mounted) AppSnackbar.showSuccess(context, 'Archivo eliminado');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyState(
        icon: isAudio ? Icons.music_off_outlined : Icons.video_library_outlined,
        title: isAudio ? 'Sin audios' : 'Sin videos',
        message: 'Tus descargas aparecerán aquí.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _MediaCard(
          item: item,
          onTap: () => _open(context, ref, item),
          onLongPress: () => _showActions(context, ref, item),
        );
      },
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ThumbnailImage(borderRadius: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isAudio ? Icons.music_note : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            item.readableSize,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
        ],
      ),
    );
  }
}
