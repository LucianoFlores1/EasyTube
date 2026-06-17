# EasyTube

Aplicación Flutter tipo Snaptube: **micro-navegador de YouTube + descargador de video/audio**. Android-first.

> ⚠️ **Uso responsable.** Usa `youtube_explode_dart` (ingeniería inversa de los streams de YouTube), por lo que va **contra los Términos de YouTube** y **no es apta para Google Play**: distribución por sideload (APK) o F-Droid. Descargá solo contenido permitido por la ley de derechos de autor de tu país.

## Funcionalidades

- **Explorar** — WebView de `m.youtube.com` con barra de URL/búsqueda, atrás/adelante/recargar, bloqueo de hosts de ads/tracking y detección de videos (`/watch?v=`, `/shorts/`, `youtu.be`). FAB *Descargar* en cada video. La extracción se **precarga** mientras mirás, así el panel abre al instante.
- **Resolución nativa** — Bottom sheet con thumbnail/título/canal/duración y chips con **todas las resoluciones reales** del video (480p, 720p, 1080p… hasta 4K) y audio (M4A / MP3 320k).
- **Descargas** — Cola persistente (sqflite) con progreso, límite de concurrencia y acciones cancelar/reintentar/quitar. Tocar un ítem terminado lo reproduce.
- **Listas** — Botón *Descargar lista completa* en playlists (no-radio), con el formato elegido.
- **Compartir → descargar** — EasyTube aparece como destino al compartir un link de YouTube desde cualquier app; abre el panel de descarga directo.
- **Biblioteca** — Pestañas Videos/Audio (grid), reproductor de video (seek/fullscreen) y de audio con mini-player persistente. Compartir y eliminar (con confirmación).
- **Navegación** — 4 tabs deslizables (swipe) además de tap.

## Cómo funciona la descarga

YouTube bloquea/throttlea la descarga directa de streams adaptativos salvo con el cliente adecuado. EasyTube usa el cliente **`androidVr`** de `youtube_explode`, cuyos streams **video-only (hasta 2160p) y audio-only (AAC)** se bajan con un GET HTTP normal. Luego:

- **Video**: descarga el video-only + el audio-only y los **fusiona con FFmpeg** (`-c copy`, sin recodificar).
- **Audio**: descarga el audio-only AAC; **M4A** se guarda tal cual (sin FFmpeg), **MP3** se transcodifica con `libmp3lame`.

Los archivos van a **`Download/EasyTube/{Videos,Audio}`** (visibles en el explorador del teléfono).

## Arquitectura

Feature-first con capas `domain / data / application / presentation`. Estado con **Riverpod 2 manual** (sin codegen). Navegación con **go_router** (`StatefulShellRoute` + `PageView`). Persistencia con **sqflite**. Ver [`CLAUDE.md`](CLAUDE.md).

```
lib/
  core/        constants, theme (Material 3 dark), router, errors, permissions
  features/
    browser/   WebView + detección de video + FAB + prefetch
    extractor/ youtube_explode (androidVr) + opciones de calidad
    downloader/ cola + descarga HTTP + FFmpeg merge/transcode + sqflite
    library/   escaneo + players (video/audio) + mini-player
    settings/  preferencias + permisos
  shared/      providers globales + widgets
```

## Requisitos

- Flutter 3.x (probado con 3.44 / Dart 3.12)
- Android SDK — minSdk **24** (lo exige ffmpeg_kit), targetSdk 34
- JDK 17

## Puesta en marcha

```bash
flutter pub get
dart run flutter_launcher_icons          # íconos (usa assets/branding/icon.png)
dart run flutter_native_splash:create    # splash
flutter run --release                    # release se siente mucho más fluido que debug
```

## Build de release

```bash
flutter build apk --release --target-platform android-arm64
# o todas las ABIs:
flutter build apk --release --split-per-abi
# APK en build/app/outputs/flutter-apk/
```

> Notas: el release se firma con la **clave de debug** (para sideload; configurá tu `signingConfig` para distribución real). **R8/minify está desactivado** porque eliminaba registrants de plugins; las reglas ProGuard quedan en `android/app/proguard-rules.pro` para reactivarlo con keeps verificados.

## Permisos (AndroidManifest)

`INTERNET`, `MANAGE_EXTERNAL_STORAGE` (para escribir en `Download/`), `READ_MEDIA_VIDEO/AUDIO`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`. Si se niega el acceso a almacenamiento, las descargas caen a la carpeta privada de la app.

## Licencia / créditos

Proyecto educativo. Depende de [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart) y [`ffmpeg_kit_flutter_new_audio`](https://pub.dev/packages/ffmpeg_kit_flutter_new_audio). No afiliado a YouTube/Google.
