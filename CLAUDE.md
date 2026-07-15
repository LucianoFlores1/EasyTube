# EasyTube
Flutter app: buscador nativo de YouTube + descargador de video/audio con metadata
completa (portada, artista, género, letras). Android-first.

## Stack
Flutter 3.x | Riverpod 2 (manual Notifier/AsyncNotifier — no codegen) | go_router
youtube_explode_dart | just_audio | video_player | sqflite | permission_handler
share_plus | cached_network_image | ffmpeg_kit_flutter_new_audio | flutter_foreground_task

## Estructura
lib/core/{constants,theme,router,errors,permissions}
lib/features/{search,extractor,downloader,library,settings,spotify,ytmusic}/{domain,data,application,presentation}
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
search (nativo, youtube_explode) → extractor (manifest) → downloader (cola propia +
descarga chunked + FFmpeg) → library (escaneo de archivos + players)
Import: Spotify/YouTube Music → lista de tracks → downloader (audio + metadata + letra)

## Notas de implementación
- Video: stream de video + audio por separado (calidad nativa hasta 2160p vía
  `YoutubeApiClient.androidVr`) y merge con FFmpeg `-c copy`.
- Descarga vía `yt.videos.streamsClient.get()` (chunked). Un GET largo único lo
  throttlea YouTube a ~31 KB/s y corta la conexión; chunked va a 300 KB/s–2 MB/s.
- `youtube_explode.playlists.getVideos` está ROTO (devuelve 0) → `PlaylistResolver`
  usa el endpoint InnerTube `browse` (`VL<id>`, nodos `lockupViewModel`).
  Sirve igual para álbumes de YouTube Music (`OLAK5uy_...`).
- Metadata: iTunes Search API (álbum/género/año/portada) + LRCLIB (letras). Sin auth.
- FFmpeg se invoca con `executeWithArguments(List<String>)`, NO con string: las
  letras traen saltos de línea y los títulos comillas, y el parser de comandos rompe.
- Letras: `plain` embebida (USLT en MP3 / `©lyr` en M4A) + `.lrc` sincronizado al lado
  del archivo (convención que leen Poweramp/Musicolet). Verificado con ffprobe.
- `-map_metadata -1` antes de escribir tags: si no, se cuelan los tags del contenedor
  de origen (major_brand, compatible_brands...).
- Descargas en `Download/EasyTube/{Videos,Audio}` (público) con fallback app-scoped.
- Nombres únicos ante colisión (` (2)`): dos canciones distintas pueden llamarse igual.
- minSdk 24, targetSdk 34. R8/minify DESACTIVADO (stripea los registrants de plugins).

## Comandos
flutter run --debug
flutter analyze lib
flutter build apk --release --target-platform android-arm64
dart run tool/test_dl.dart       # dry-run del pipeline de metadata (sin descargar)
dart run flutter_launcher_icons
dart run flutter_native_splash:create
