import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloader/data/file_paths.dart';
import '../domain/media_item.dart';

final libraryProvider =
    AsyncNotifierProvider<LibraryNotifier, LibraryData>(LibraryNotifier.new);

const _videoExt = {'.mp4', '.webm', '.mkv', '.mov'};
const _audioExt = {'.m4a', '.mp3', '.aac', '.opus', '.wav'};

class LibraryNotifier extends AsyncNotifier<LibraryData> {
  @override
  Future<LibraryData> build() => _scan();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_scan);
  }

  Future<void> delete(MediaItem item) async {
    final file = File(item.path);
    if (await file.exists()) await file.delete();
    await refresh();
  }

  Future<LibraryData> _scan() async {
    final videosDir = await FilePaths.videosDir();
    final audioDir = await FilePaths.audioDir();
    return LibraryData(
      videos: await _scanDir(videosDir, _videoExt, isAudio: false),
      audio: await _scanDir(audioDir, _audioExt, isAudio: true),
    );
  }

  Future<List<MediaItem>> _scanDir(
    Directory dir,
    Set<String> extensions, {
    required bool isAudio,
  }) async {
    if (!await dir.exists()) return const [];
    final items = <MediaItem>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final ext = _extension(entity.path);
      if (!extensions.contains(ext)) continue;
      final stat = await entity.stat();
      items.add(
        MediaItem(
          path: entity.path,
          title: _titleFromPath(entity.path),
          isAudio: isAudio,
          sizeBytes: stat.size,
          modified: stat.modified,
        ),
      );
    }
    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot).toLowerCase();
  }

  String _titleFromPath(String path) {
    var name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    // Drop the trailing " [720p]" / " [MP3 320k]" quality tag.
    return name.replaceFirst(RegExp(r'\s*\[[^\]]*\]\s*$'), '').trim();
  }
}
