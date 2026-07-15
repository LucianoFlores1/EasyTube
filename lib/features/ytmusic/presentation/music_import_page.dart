import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/thumbnail_image.dart';
import '../../downloader/application/downloader_notifier.dart';
import '../application/ytmusic_providers.dart';

class MusicImportPage extends ConsumerStatefulWidget {
  const MusicImportPage({required this.playlistId, super.key});

  final String playlistId;

  @override
  ConsumerState<MusicImportPage> createState() => _MusicImportPageState();
}

class _MusicImportPageState extends ConsumerState<MusicImportPage> {
  bool _mp3 = true;

  void _downloadAll(int count) {
    final format = _mp3
        ? (container: 'mp3', audioFormat: 'mp3', quality: 'MP3 320k')
        : (container: 'm4a', audioFormat: 'm4a', quality: 'M4A');
    ref.read(downloaderProvider.notifier).enqueueMusic(
          ref.read(musicTracksProvider(widget.playlistId)).value ?? const [],
          container: format.container,
          audioFormat: format.audioFormat,
          quality: format.quality,
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count canciones agregadas a la cola')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(musicTracksProvider(widget.playlistId));
    return Scaffold(
      appBar: AppBar(title: const Text('Importar de YouTube Music')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo leer la lista',
          message: e.toString(),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const EmptyState(
              icon: Icons.link_off,
              title: 'Sin canciones',
              message: '¿El link es de un álbum o playlist de YouTube Music? '
                  'Los mixes automáticos no se pueden importar.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('MP3')),
                        ButtonSegment(value: false, label: Text('M4A')),
                      ],
                      selected: {_mp3},
                      onSelectionChanged: (s) => setState(() => _mp3 = s.first),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _downloadAll(tracks.length),
                      icon: const Icon(Icons.download),
                      label: Text('Descargar todo (${tracks.length})'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = tracks[i];
                    return ListTile(
                      leading: ThumbnailImage(
                        url: 'https://i.ytimg.com/vi/${t.id}/default.jpg',
                        width: 56,
                        height: 40,
                      ),
                      title: Text(t.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: t.author.isEmpty
                          ? null
                          : Text(t.author,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      dense: true,
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
