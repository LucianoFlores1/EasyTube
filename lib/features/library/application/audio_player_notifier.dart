import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/media_item.dart';

/// Long-lived [AudioPlayer] shared by the mini-player and the full audio page.
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final currentAudioProvider =
    NotifierProvider<AudioPlayerController, MediaItem?>(
  AudioPlayerController.new,
);

class AudioPlayerController extends Notifier<MediaItem?> {
  @override
  MediaItem? build() => null;

  AudioPlayer get _player => ref.read(audioPlayerProvider);

  Future<void> play(MediaItem item) async {
    if (state?.path == item.path) {
      await _player.play();
      return;
    }
    state = item;
    try {
      await _player.setFilePath(item.path);
      await _player.play();
    } catch (_) {
      state = null;
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    await _player.stop();
    state = null;
  }
}
