import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Single long-lived [YoutubeExplode] client shared by the extractor and
/// downloader. Closed automatically when the provider is disposed.
final youtubeExplodeProvider = Provider<YoutubeExplode>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(yt.close);
  return yt;
});
