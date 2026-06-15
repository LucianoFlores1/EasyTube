import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/permissions/permission_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/downloader/application/downloader_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TubeDLApp()));
}

class TubeDLApp extends ConsumerStatefulWidget {
  const TubeDLApp({super.key});

  @override
  ConsumerState<TubeDLApp> createState() => _TubeDLAppState();
}

class _TubeDLAppState extends ConsumerState<TubeDLApp> {
  @override
  void initState() {
    super.initState();
    // Eagerly bind the downloader so background progress is received even
    // before the user opens the Downloads tab, and ask for notifications.
    ref.read(downloaderProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => PermissionService.requestOnStartup(),
    );
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
