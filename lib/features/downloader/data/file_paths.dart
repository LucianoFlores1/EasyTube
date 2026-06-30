import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';

/// Resolves and creates the on-device folders used for downloads.
///
/// Files live under the app-scoped external storage directory
/// (`.../TubeDL/Videos` and `.../TubeDL/Audio`), which needs no extra runtime
/// permission on Android 11+.
class FilePaths {
  FilePaths._();

  static Future<Directory> videosDir() => _ensure(AppConstants.videosFolder);
  static Future<Directory> audioDir() => _ensure(AppConstants.audioFolder);

  /// App-private folder for cover thumbnails (kept out of the public Downloads
  /// folder, so it stays tidy). Persisted, not the cache dir.
  static Future<Directory> thumbsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/thumbs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// File name without directory or extension (the sanitized title).
  static String baseName(String filePath) {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Public `Download/TubeDL/<sub>` so files show up in the device's Downloads;
  /// falls back to app-scoped storage if that isn't writable (no permission).
  static Future<Directory> _ensure(String sub) async {
    final base = await getExternalStorageDirectory();
    if (base == null) throw const StorageFailure();
    final publicRoot = base.path.split('/Android/').first; // /storage/emulated/0
    try {
      final dir = Directory(
          '$publicRoot/Download/${AppConstants.rootFolder}/$sub');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      final dir = Directory('${base.path}/${AppConstants.rootFolder}/$sub');
      await dir.create(recursive: true);
      return dir;
    }
  }

  /// Strips characters that are illegal in file names on Android/FAT.
  static String sanitize(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final clipped = cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
    return clipped.isEmpty ? 'video' : clipped;
  }

  // ponytail: naive YouTube-title noise stripper. Removes bracketed/parenthetical
  // groups that contain obvious junk keywords; keeps things like "(Meteora)".
  static final _noise = RegExp(
    r'\s*[\(\[][^)\]]*\b(official|video|audio|lyric|lyrics|visualizer|'
    r'music\s*video|mv|hd|hq|4k|8k|remaster(ed)?|explicit|upgrade|'
    r'oficial|letra|legendado|sub\s*español)\b[^)\]]*[\)\]]',
    caseSensitive: false,
  );

  /// The song name only — drops "(Official Music Video)", "[4K UPGRADE]", etc.
  static String cleanTitle(String title) =>
      title.replaceAll(_noise, '').replaceAll(RegExp(r'\s+'), ' ').trim();
}
