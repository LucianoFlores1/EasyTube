import 'package:flutter/material.dart';

/// App-wide constants for TubeDL.
class AppConstants {
  AppConstants._();

  static const String appName = 'TubeDL';

  /// Initial URL loaded in the micro-browser.
  static const String youtubeHomeUrl = 'https://m.youtube.com';

  /// Root folder name created inside external storage.
  static const String rootFolder = 'TubeDL';
  static const String videosFolder = 'Videos';
  static const String audioFolder = 'Audio';

  /// Hosts blocked by the in-app navigation filter (ads / tracking).
  static const List<String> blockedHosts = [
    'doubleclick.net',
    'googleadservices.com',
    'googlesyndication.com',
    'google-analytics.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'ads.youtube.com',
  ];

  /// Notification channel for the foreground download service.
  static const String downloadChannelId = 'tubedl_downloads';
  static const String downloadChannelName = 'Descargas';
}

/// Brand palette.
class AppColors {
  AppColors._();

  static const Color brandRed = Color(0xFFE53935);
  static const Color brandRedDark = Color(0xFFB71C1C);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  static const Color onSurfaceMuted = Color(0xFFB0B0B0);
}
