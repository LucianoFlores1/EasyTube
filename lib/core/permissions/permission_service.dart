import 'package:permission_handler/permission_handler.dart';

/// Requests the runtime permissions TubeDL needs. Files are written to
/// app-scoped storage (no storage permission required on Android 11+), so the
/// main ask is the POST_NOTIFICATIONS permission used by the download service,
/// plus media read access for the library on Android 13+.
class PermissionService {
  PermissionService._();

  static Future<void> requestOnStartup() async {
    await [
      Permission.notification,
    ].request();
  }

  static Future<bool> requestMedia() async {
    final statuses = await [
      Permission.notification,
      Permission.videos,
      Permission.audio,
    ].request();
    return statuses.values.any((s) => s.isGranted);
  }
}
