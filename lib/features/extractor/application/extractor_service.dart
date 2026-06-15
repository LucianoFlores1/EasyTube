import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/errors/failure.dart';
import '../../../shared/providers/youtube_explode_provider.dart';
import '../domain/extract_result.dart';
import '../domain/stream_option.dart';

final extractorServiceProvider = Provider<ExtractorService>((ref) {
  return ExtractorService(ref.watch(youtubeExplodeProvider));
});

/// Fetches metadata + available streams for a video and shapes them into the
/// options shown in the extractor sheet.
final extractOptionsProvider =
    FutureProvider.family<ExtractResult, String>((ref, videoId) {
  return ref.watch(extractorServiceProvider).getOptions(videoId);
});

class ExtractorService {
  ExtractorService(this._yt);

  final YoutubeExplode _yt;

  Future<ExtractResult> getOptions(String videoId) async {
    try {
      // Fetch metadata and the stream manifest concurrently to cut latency.
      final results = await Future.wait([
        _yt.videos.get(videoId),
        _yt.videos.streamsClient.getManifest(videoId),
      ]);
      final video = results[0] as Video;
      final manifest = results[1] as StreamManifest;

      final muxed = manifest.muxed.sortByVideoQuality();
      return ExtractResult(
        video: video,
        videoOptions: _buildVideoOptions(muxed),
        audioOptions: _buildAudioOptions(muxed),
      );
    } on VideoRequiresPurchaseException {
      throw const VideoUnavailableFailure('Este video requiere compra.');
    } on VideoUnavailableException {
      throw const VideoUnavailableFailure();
    } on VideoUnplayableException {
      throw const RegionBlockedFailure();
    } on Failure {
      rethrow;
    } catch (e) {
      throw ExtractionFailure(e.toString());
    }
  }

  List<StreamOption> _buildVideoOptions(List<MuxedStreamInfo> muxed) {
    final seen = <String>{};
    final options = <StreamOption>[];
    for (final s in muxed) {
      if (!seen.add(s.qualityLabel)) continue;
      options.add(
        StreamOption(
          label: s.qualityLabel,
          kind: MediaKind.video,
          container: s.container.name,
          streamInfo: s,
          height: s.videoResolution.height,
          sizeBytes: s.size.totalBytes,
        ),
      );
    }
    return options;
  }

  /// Audio is extracted from the highest-quality muxed stream, so it downloads
  /// reliably and carries the best available audio track.
  List<StreamOption> _buildAudioOptions(List<MuxedStreamInfo> muxed) {
    if (muxed.isEmpty) return const [];
    final src = muxed.first; // highest quality muxed

    return [
      StreamOption(
        label: 'M4A',
        kind: MediaKind.audio,
        container: 'm4a',
        streamInfo: src,
        audioCodec: 'copy',
      ),
      StreamOption(
        label: 'MP3 320k',
        kind: MediaKind.audio,
        container: 'mp3',
        streamInfo: src,
        audioCodec: 'libmp3lame',
      ),
    ];
  }
}
