import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../application/audio_player_notifier.dart';

/// Persistent audio bar shown above the bottom navigation while something is
/// playing. Tapping it opens the full audio page.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentAudioProvider);
    if (current == null) return const SizedBox.shrink();

    final player = ref.watch(audioPlayerProvider);
    final controller = ref.read(currentAudioProvider.notifier);

    return Material(
      color: AppColors.surfaceVariant,
      child: InkWell(
        onTap: () => context.push(Routes.audioPlayer, extra: current),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = player.duration ?? Duration.zero;
                final value = total.inMilliseconds == 0
                    ? 0.0
                    : position.inMilliseconds / total.inMilliseconds;
                return LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack, color: AppColors.brandRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      current.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: controller.toggle,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: controller.stop,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
