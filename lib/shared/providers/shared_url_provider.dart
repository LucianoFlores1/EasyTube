import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a URL shared into the app (Android share sheet), consumed once by the
/// shell to open the download sheet.
final sharedUrlProvider =
    NotifierProvider<SharedUrlNotifier, String?>(SharedUrlNotifier.new);

class SharedUrlNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? url) => state = url;
  void clear() => state = null;
}
