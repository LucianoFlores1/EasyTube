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
}
