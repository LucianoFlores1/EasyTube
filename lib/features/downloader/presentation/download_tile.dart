import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/thumbnail_image.dart';
import '../../library/application/audio_player_notifier.dart';
import '../../library/domain/media_item.dart';
import '../application/downloader_notifier.dart';
import '../domain/download_task.dart';

class DownloadTile extends ConsumerWidget {
  const DownloadTile({required this.task, super.key});

  final DownloadTask task;

  void _play(BuildContext context, WidgetRef ref) {
    final item = MediaItem(
      path: task.filePath,
      title: task.title,
      isAudio: task.isAudio,
      sizeBytes: 0,
      modified: task.createdAt,
    );
    if (task.isAudio) {
      ref.read(currentAudioProvider.notifier).play(item);
      context.push(Routes.audioPlayer, extra: item);
    } else {
      context.push(Routes.videoPlayer, extra: item);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloaderProvider.notifier);
    final canPlay = task.status == DownloadStatus.complete;

    return InkWell(
      onTap: canPlay ? () => _play(context, ref) : null,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ThumbnailImage(
                url: task.thumbnailUrl,
                width: 96,
                height: 56,
              ),
              Icon(
                task.isAudio ? Icons.audiotrack : Icons.movie,
                size: 18,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.quality} · ${task.container.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
                const SizedBox(height: 8),
                _ProgressRow(task: task),
              ],
            ),
          ),
          _Actions(task: task, notifier: notifier),
        ],
      ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (task.status) {
      DownloadStatus.complete => (const Color(0xFF2E7D32), 'Completado'),
      DownloadStatus.failed => (AppColors.brandRed, 'Error'),
      DownloadStatus.canceled => (AppColors.onSurfaceMuted, 'Cancelado'),
      DownloadStatus.paused => (Colors.orange, 'Pausado'),
      DownloadStatus.converting => (AppColors.brandRed, 'Convirtiendo a MP3…'),
      DownloadStatus.running => (AppColors.brandRed, '${task.progress}%'),
      DownloadStatus.enqueued => (AppColors.onSurfaceMuted, 'En cola…'),
    };

    final indeterminate = task.status == DownloadStatus.converting ||
        task.status == DownloadStatus.enqueued;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.status.isActive || task.status == DownloadStatus.paused)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: indeterminate
                ? const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceVariant,
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: task.progress / 100),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ),
          ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.task, required this.notifier});
  final DownloadTask task;
  final DownloaderNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return switch (task.status) {
      DownloadStatus.failed ||
      DownloadStatus.canceled ||
      DownloadStatus.paused =>
        IconButton(
          tooltip: 'Reintentar',
          icon: const Icon(Icons.refresh),
          onPressed: () => notifier.retry(task.id),
        ),
      DownloadStatus.complete => IconButton(
          tooltip: 'Quitar de la lista',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => notifier.remove(task.id),
        ),
      DownloadStatus.running ||
      DownloadStatus.enqueued ||
      DownloadStatus.converting =>
        IconButton(
          tooltip: 'Cancelar',
          icon: const Icon(Icons.close),
          onPressed: () => notifier.cancel(task.id),
        ),
    };
  }
}
