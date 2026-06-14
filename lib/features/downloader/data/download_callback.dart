import 'dart:ui';

/// Name under which the UI isolate registers its [SendPort] so the
/// flutter_downloader background isolate can post progress updates.
const String downloaderPortName = 'tubedl_downloader_port';

/// Runs in flutter_downloader's background isolate. Forwards raw progress to
/// the UI isolate via the registered port.
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final send = IsolateNameServer.lookupPortByName(downloaderPortName);
  send?.send(<dynamic>[id, status, progress]);
}
