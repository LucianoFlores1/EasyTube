# TubeDL
Flutter app: micro-browser YouTube + video/audio downloader. Android-first.

## Stack
Flutter 3.x | Riverpod 2 (manual Notifier/AsyncNotifier — no codegen) | go_router
webview_flutter | youtube_explode_dart | flutter_downloader | just_audio | video_player
sqflite | ffmpeg_kit_full_gpl | permission_handler | share_plus | cached_network_image

## Estructura
lib/core/{constants,theme,router,errors,permissions}
lib/features/{browser,extractor,downloader,library,settings}/{domain,data,application,presentation}
lib/shared/{providers,widgets}

## Convenciones
- Feature-first; cada feature en capas domain/data/application/presentation.
- Riverpod manual: `NotifierProvider`, `AsyncNotifierProvider`, `Provider`, `FutureProvider.family`.
  NO se usa codegen (`@riverpod`) ni `build_runner` — evita dependencia frágil de generación.
- DB con sqflite directo (sin drift). Tabla `download_tasks`.
- go_router `StatefulShellRoute.indexedStack` para el BottomNav (4 tabs).
- Sin comentarios salvo que el PORQUÉ no sea obvio. Sin tests salvo que se pidan.
- Validar solo en bordes (input de usuario, respuestas de YouTube).

## Data flow
browser (detecta /watch?v=) → extractor (manifest youtube_explode) → downloader (cola + FlutterDownloader + FFmpeg) → library (escaneo de archivos + players)

## Notas de implementación
- Video: solo streams *muxed* (audio+video juntos) → sin merge FFmpeg. FFmpeg solo para M4A→MP3.
- Descargas en almacenamiento app-scoped: `getExternalStorageDirectory()/TubeDL/{Videos,Audio}` (sin permiso de storage en Android 11+).
- Progreso de descarga: isolate de flutter_downloader → `IsolateNameServer` port → `DownloaderNotifier`.
- minSdk 24 (requerido por ffmpeg_kit_full_gpl), targetSdk 34.

## Comandos
flutter run --debug
flutter analyze
flutter build apk --release --split-per-abi
dart run flutter_launcher_icons
dart run flutter_native_splash:create
