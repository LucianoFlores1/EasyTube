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
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      return ExtractResult(
        video: video,
        videoOptions: _buildVideoOptions(manifest),
        audioOptions: _buildAudioOptions(manifest),
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

  List<StreamOption> _buildVideoOptions(StreamManifest manifest) {
    // Muxed streams carry both audio and video, so no merge step is needed.
    final muxed = manifest.muxed.sortByVideoQuality();
    final seen = <String>{};
    final options = <StreamOption>[];
    for (final s in muxed) {
      final label = s.qualityLabel;
      if (!seen.add(label)) continue;
      options.add(
        StreamOption(
          label: label,
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

  List<StreamOption> _buildAudioOptions(StreamManifest manifest) {
    final audios = manifest.audioOnly.sortByBitrate();
    if (audios.isEmpty) return const [];
    final best = audios.last; // highest bitrate
    final kbps = best.bitrate.kiloBitsPerSecond.round();

    return [
      StreamOption(
        label: 'M4A ${kbps}k',
        kind: MediaKind.audio,
        container: 'm4a',
        streamInfo: best,
        bitrate: kbps,
        sizeBytes: best.size.totalBytes,
      ),
      StreamOption(
        label: 'MP3 320k',
        kind: MediaKind.audio,
        container: 'mp3',
        streamInfo: best,
        bitrate: 320,
        sizeBytes: best.size.totalBytes,
        convertToMp3: true,
      ),
    ];
  }
}
