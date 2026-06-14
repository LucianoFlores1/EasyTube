# TubeDL

Aplicación Flutter tipo Snaptube: **micro-navegador de YouTube + descargador de video/audio**. Android-first.

> ⚠️ **Uso responsable.** Esta app usa `youtube_explode_dart` (ingeniería inversa de los streams de YouTube) y `ffmpeg_kit_full_gpl` (licencia GPL). Por la licencia GPL **no puede publicarse en Google Play**; distribución vía sideload/APK o F-Droid. Descarga únicamente contenido permitido por los Términos de Servicio de YouTube y la ley de derechos de autor de tu país.

## Funcionalidades

- **Explorar** — WebView de `m.youtube.com` con barra de URL/búsqueda, navegación atrás/adelante/recargar, bloqueo de hosts de ads/tracking y detección automática de videos (`/watch?v=`, `/shorts/`, `youtu.be`). Aparece un FAB *Descargar* al estar en un video.
- **Extractor** — Bottom sheet con thumbnail, título, canal y duración; chips de calidad de video (streams muxed) y audio (M4A / MP3 320k), con tamaño estimado.
- **Descargas** — Cola persistente (sqflite) con progreso real, notificaciones nativas y acciones pausar/reanudar/cancelar/reintentar/quitar. Conversión M4A→MP3 vía FFmpeg. Sobrevive a cierres en segundo plano (WorkManager).
- **Biblioteca** — Pestañas Videos/Audio con grid; reproductor de video (play/pausa/seek/pantalla completa) y de audio con mini-player persistente. Compartir y eliminar (con confirmación).
- **Ajustes** — Preferencias, ruta de almacenamiento, solicitud de permisos en runtime, aviso de uso responsable.

## Arquitectura

Feature-first con capas `domain / data / application / presentation`. Estado con **Riverpod 2 manual** (sin codegen). Navegación con **go_router** (`StatefulShellRoute`). Persistencia con **sqflite**. Ver [`CLAUDE.md`](CLAUDE.md) para convenciones.

```
lib/
  core/        constants, theme (Material 3 dark), router, errors, permissions
  features/
    browser/   WebView + detección de video + FAB
    extractor/ youtube_explode + opciones de calidad
    downloader/ cola + FlutterDownloader + FFmpeg + sqflite
    library/   escaneo + players (video/audio) + mini-player
    settings/  preferencias + permisos
  shared/      providers globales + widgets reutilizables
```

## Requisitos

- Flutter 3.x (probado con 3.44, Dart 3.12)
- Android SDK (minSdk **24** por ffmpeg_kit, targetSdk 34)
- JDK 17

## Puesta en marcha

```bash
flutter pub get
dart run flutter_launcher_icons          # genera íconos
dart run flutter_native_splash:create    # genera splash
flutter run --debug
```

## Build de release

```bash
flutter build apk --release --split-per-abi
# APKs en build/app/outputs/flutter-apk/
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

> El `build.gradle.kts` firma el release con la clave de debug para que `flutter run --release` funcione sin configuración. Para distribución real, configura tu propio `signingConfig`.

## Permisos (AndroidManifest)

`INTERNET`, `READ/WRITE_EXTERNAL_STORAGE` (acotados por `maxSdkVersion`), `READ_MEDIA_VIDEO/AUDIO`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `RECEIVE_BOOT_COMPLETED`. Los archivos se guardan en almacenamiento app-scoped, por lo que no se requiere permiso de almacenamiento en Android 11+.
