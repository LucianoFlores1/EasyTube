# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# flutter_downloader (WorkManager background isolate)
-keep class vn.hunghd.flutterdownloader.** { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ffmpeg_kit
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# just_audio / media3 (ExoPlayer)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Keep entry-point callbacks invoked from native side.
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
