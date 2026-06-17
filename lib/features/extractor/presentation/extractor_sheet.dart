import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/widgets/thumbnail_image.dart';
import '../../downloader/application/downloader_notifier.dart';
import '../../downloader/domain/download_request.dart';
import '../application/extractor_service.dart';
import '../domain/extract_result.dart';
import '../domain/stream_option.dart';

/// Bottom sheet that lists the real video/audio download options for a video.
class ExtractorSheet extends ConsumerStatefulWidget {
  const ExtractorSheet({required this.videoId, this.playlistId, super.key});

  final String videoId;
  final String? playlistId;

  @override
  ConsumerState<ExtractorSheet> createState() => _ExtractorSheetState();
}

class _ExtractorSheetState extends ConsumerState<ExtractorSheet> {
  StreamOption? _selected;

  Future<void> _download(ExtractResult result) async {
    final option = _selected;
    if (option == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await PermissionService.ensureStorage();
      await ref.read(downloaderProvider.notifier).enqueue(
            DownloadRequest(
              videoId: widget.videoId,
              title: result.title,
              author: result.author,
              thumbnailUrl: result.thumbnailUrl,
              audioStream: option.audioStream,
              videoStream: option.videoStream,
              container: option.container,
              isAudio: option.isAudio,
              audioFormat: option.audioFormat,
              quality: option.label,
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Descarga agregada a la cola')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al iniciar descarga: $e')),
      );
    }
  }

  Future<void> _downloadPlaylist() async {
    final option = _selected;
    final playlistId = widget.playlistId;
    if (option == null || playlistId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await PermissionService.ensureStorage();
      await ref.read(downloaderProvider.notifier).enqueuePlaylist(
            playlistId: playlistId,
            isAudio: option.isAudio,
            container: option.container,
            audioFormat: option.audioFormat,
            quality: option.label,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Lista completa agregada a la cola')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error con la lista: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(extractOptionsProvider(widget.videoId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: async.when(
              loading: () =>
                  _SheetLoading(key: const ValueKey('l'), videoId: widget.videoId),
              error: (err, _) => _SheetError(
                key: const ValueKey('e'),
                error: err,
                onRetry: () =>
                    ref.invalidate(extractOptionsProvider(widget.videoId)),
              ),
              data: (result) => _SheetContent(
                key: const ValueKey('d'),
                result: result,
                selected: _selected,
                scrollController: scrollController,
                hasPlaylist: widget.playlistId != null,
                onSelect: (o) => setState(() => _selected = o),
                onDownload: () => _download(result),
                onDownloadPlaylist: _downloadPlaylist,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.result,
    required this.selected,
    required this.scrollController,
    required this.hasPlaylist,
    required this.onSelect,
    required this.onDownload,
    required this.onDownloadPlaylist,
    super.key,
  });

  final ExtractResult result;
  final StreamOption? selected;
  final ScrollController scrollController;
  final bool hasPlaylist;
  final ValueChanged<StreamOption> onSelect;
  final VoidCallback onDownload;
  final VoidCallback onDownloadPlaylist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        Expanded(
          child: ListView(
            controller: scrollController,
            children: [
              _Header(result: result),
              const SizedBox(height: 20),
              if (result.videoOptions.isNotEmpty) ...[
                const _SectionLabel(icon: Icons.movie_outlined, label: 'Video'),
                _OptionWrap(
                  options: result.videoOptions,
                  selected: selected,
                  onSelect: onSelect,
                ),
                const SizedBox(height: 16),
              ],
              if (result.audioOptions.isNotEmpty) ...[
                const _SectionLabel(
                    icon: Icons.audiotrack_outlined, label: 'Audio'),
                _OptionWrap(
                  options: result.audioOptions,
                  selected: selected,
                  onSelect: onSelect,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: selected == null ? null : onDownload,
          icon: const Icon(Icons.download),
          label: Text(
            selected == null
                ? 'Selecciona un formato'
                : 'Descargar ${selected!.label}',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (hasPlaylist) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: selected == null ? null : onDownloadPlaylist,
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Descargar lista completa'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.result});
  final ExtractResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            ThumbnailImage(
              url: result.thumbnailUrl,
              width: 140,
              height: 80,
            ),
            if (result.readableDuration.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.readableDuration,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                result.author,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionWrap extends StatelessWidget {
  const _OptionWrap({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<StreamOption> options;
  final StreamOption? selected;
  final ValueChanged<StreamOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              selected: identical(selected, option),
              onSelected: (_) => onSelect(option),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label),
                  if (option.readableSize.isNotEmpty)
                    Text(
                      option.readableSize,
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.onSurfaceMuted),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetLoading extends StatelessWidget {
  const _SheetLoading({required this.videoId, super.key});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Grabber(),
        const SizedBox(height: 8),
        ThumbnailImage(
          url: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          width: 200,
          height: 112,
        ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Obteniendo formatos…'),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.error, required this.onRetry, super.key});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Grabber(),
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 48, color: AppColors.brandRed),
        const SizedBox(height: 16),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
