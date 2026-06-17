import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/errors/failure.dart';
import '../../../shared/providers/youtube_explode_provider.dart';
import '../domain/extract_result.dart';
import '../domain/stream_option.dart';

final extractorServiceProvider = Provider<ExtractorService>((ref) {
  return ExtractorService(ref.watch(youtubeExplodeProvider));
});

final extractOptionsProvider =
    FutureProvider.family<ExtractResult, String>((ref, videoId) {
  return ref.watch(extractorServiceProvider).getOptions(videoId);
});

/// androidVr exposes every native resolution as video-only streams AND serves
/// them (plus AAC audio-only) over a plain HTTP GET without throttling.
const _client = YoutubeApiClient.androidVr;

class ExtractorService {
  ExtractorService(this._yt);

  final YoutubeExplode _yt;

  Future<StreamManifest> manifest(String videoId) =>
      _yt.videos.streamsClient.getManifest(videoId, ytClients: [_client]);

  Future<ExtractResult> getOptions(String videoId) async {
    try {
      final results = await Future.wait([
        _yt.videos.get(videoId),
        manifest(videoId),
      ]);
      final video = results[0] as Video;
      final m = results[1] as StreamManifest;
      final audio = pickAudio(m);

      return ExtractResult(
        video: video,
        videoOptions: [
          for (final v in pickVideos(m))
            StreamOption(
              label: v.qualityLabel,
              kind: MediaKind.video,
              container: 'mp4',
              videoStream: v,
              audioStream: audio,
              height: v.videoResolution.height,
              sizeBytes: v.size.totalBytes + audio.size.totalBytes,
            ),
        ],
        audioOptions: [
          StreamOption(
            label: 'M4A ${audio.bitrate.kiloBitsPerSecond.round()}k',
            kind: MediaKind.audio,
            container: 'm4a',
            audioStream: audio,
            audioFormat: 'm4a',
            sizeBytes: audio.size.totalBytes,
          ),
          StreamOption(
            label: 'MP3 320k',
            kind: MediaKind.audio,
            container: 'mp3',
            audioStream: audio,
            audioFormat: 'mp3',
            sizeBytes: audio.size.totalBytes,
          ),
        ],
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

  /// Highest-bitrate AAC (mp4) audio-only — downloads reliably (itag 139, the
  /// lowest, is the one that throttles, and sorting by bitrate skips it).
  StreamInfo pickAudio(StreamManifest m) {
    final aac = m.audioOnly.where((a) => a.container.name == 'mp4').toList();
    if (aac.isNotEmpty) return aac.sortByBitrate().last;
    if (m.audioOnly.isNotEmpty) return m.audioOnly.sortByBitrate().last;
    return m.muxed.first; // last resort
  }

  /// One mp4 video-only stream per resolution (highest first), preferring H.264
  /// for player compatibility.
  List<VideoOnlyStreamInfo> pickVideos(StreamManifest m) {
    final byHeight = <int, VideoOnlyStreamInfo>{};
    for (final v in m.videoOnly.where((v) => v.container.name == 'mp4')) {
      final h = v.videoResolution.height;
      final cur = byHeight[h];
      if (cur == null ||
          (v.videoCodec.startsWith('avc') &&
              !cur.videoCodec.startsWith('avc'))) {
        byHeight[h] = v;
      }
    }
    final list = byHeight.values.toList()
      ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    return list;
  }

  VideoOnlyStreamInfo? pickVideoByQuality(StreamManifest m, String quality) {
    final vids = pickVideos(m);
    if (vids.isEmpty) return null;
    return vids.firstWhere((v) => v.qualityLabel == quality,
        orElse: () => vids.first);
  }
}
