import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../downloader/application/downloader_notifier.dart';
import '../application/spotify_providers.dart';

class SpotifyImportPage extends ConsumerStatefulWidget {
  const SpotifyImportPage({required this.url, super.key});

  final String url;

  @override
  ConsumerState<SpotifyImportPage> createState() => _SpotifyImportPageState();
}

class _SpotifyImportPageState extends ConsumerState<SpotifyImportPage> {
  bool _mp3 = true;

  void _downloadAll(int count) {
    final format = _mp3
        ? (container: 'mp3', audioFormat: 'mp3', quality: 'MP3 320k')
        : (container: 'm4a', audioFormat: 'm4a', quality: 'M4A');
    ref.read(downloaderProvider.notifier).enqueueSpotify(
          ref.read(spotifyTracksProvider(widget.url)).value ?? const [],
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
    final async = ref.watch(spotifyTracksProvider(widget.url));
    return Scaffold(
      appBar: AppBar(title: const Text('Importar de Spotify')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo leer la playlist',
          message: e.toString(),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const EmptyState(
              icon: Icons.link_off,
              title: 'Sin canciones',
              message: '¿El link es de una playlist/álbum público de Spotify?',
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
                      leading: const Icon(Icons.music_note,
                          color: AppColors.brandRed),
                      title: Text(t.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artist,
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
