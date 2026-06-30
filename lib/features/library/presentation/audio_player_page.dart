import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_constants.dart';
import '../application/audio_player_notifier.dart';
import '../domain/media_item.dart';

class _ArtFallback extends StatelessWidget {
  const _ArtFallback();

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        height: 220,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.music_note, size: 96, color: AppColors.brandRed),
      );
}

class AudioPlayerPage extends ConsumerStatefulWidget {
  const AudioPlayerPage({required this.item, super.key});

  final MediaItem item;

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  @override
  void initState() {
    super.initState();
    // Ensure this item is the one playing (e.g. opened from the grid).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentAudioProvider.notifier).play(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(audioPlayerProvider);
    final controller = ref.read(currentAudioProvider.notifier);
    final current = ref.watch(currentAudioProvider) ?? widget.item;

    return Scaffold(
      appBar: AppBar(title: const Text('Reproduciendo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: current.thumbnailPath != null
                  ? Image.file(
                      File(current.thumbnailPath!),
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ArtFallback(),
                    )
                  : const _ArtFallback(),
            ),
            const SizedBox(height: 32),
            Text(
              current.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = player.duration ?? Duration.zero;
                final max = total.inMilliseconds.toDouble();
                final value =
                    position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                return Column(
                  children: [
                    Slider(
                      max: max <= 0 ? 1 : max,
                      value: max <= 0 ? 0 : value,
                      activeColor: AppColors.brandRed,
                      onChanged: (v) =>
                          controller.seek(Duration(milliseconds: v.toInt())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position)),
                          Text(_fmt(total)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final playing = playerState?.playing ?? false;
                final completed =
                    playerState?.processingState == ProcessingState.completed;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.replay_10),
                      onPressed: () => controller.seek(
                        player.position - const Duration(seconds: 10),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton.large(
                      onPressed: () {
                        if (completed) {
                          controller.seek(Duration.zero);
                        }
                        controller.toggle();
                      },
                      child: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.forward_10),
                      onPressed: () => controller.seek(
                        player.position + const Duration(seconds: 10),
                      ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
