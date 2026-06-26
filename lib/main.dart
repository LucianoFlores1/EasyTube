import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/permissions/permission_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/downloader/application/downloader_notifier.dart';
import 'shared/providers/shared_url_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'easytube_downloads',
      channelName: 'Descargas',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  runApp(const ProviderScope(child: TubeDLApp()));
}

class TubeDLApp extends ConsumerStatefulWidget {
  const TubeDLApp({super.key});

  @override
  ConsumerState<TubeDLApp> createState() => _TubeDLAppState();
}

class _TubeDLAppState extends ConsumerState<TubeDLApp> {
  static const _shareChannel = MethodChannel('easytube/share');

  @override
  void initState() {
    super.initState();
    // Eagerly bind the downloader so background progress is received even
    // before the user opens the Downloads tab, and ask for notifications.
    ref.read(downloaderProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => PermissionService.requestOnStartup(),
    );
    _initShare();
  }

  void _initShare() {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onShared') {
        ref.read(sharedUrlProvider.notifier).set(call.arguments as String?);
      }
    });
    // Cold start: pull the intent that launched the app, if it was a share.
    _shareChannel.invokeMethod<String>('getSharedText').then((text) {
      if (text != null && text.isNotEmpty) {
        ref.read(sharedUrlProvider.notifier).set(text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
