import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../shared/providers/youtube_explode_provider.dart';
import '../../extractor/application/extractor_service.dart';
import '../../library/application/library_notifier.dart';
import '../../spotify/domain/spotify_track.dart';
import '../data/download_database.dart';
import '../data/file_paths.dart';
import '../data/metadata_enricher.dart';
import '../data/playlist_resolver.dart';
import '../domain/download_request.dart';
import '../domain/download_task.dart';
import '../domain/track_meta.dart';

final downloaderProvider =
    NotifierProvider<DownloaderNotifier, List<DownloadTask>>(
  DownloaderNotifier.new,
);

/// Last download failure message, surfaced as a snackbar by the Downloads page.
final lastDownloadErrorProvider = StateProvider<String?>((ref) => null);

const _maxConcurrent = 2;
const _playlistCap = 50;

/// In-memory job. Streams are null for playlist items (resolved in [_run]).
class _Job {
  _Job({
    required this.videoId,
    required this.isAudio,
    required this.audioFormat,
    required this.quality,
    this.searchQuery,
    this.enrich = false,
    this.videoStream,
    this.audioStream,
  });

  /// Resolved lazily via [searchQuery] when empty (Spotify import).
  String videoId;
  final bool isAudio;
  final String? audioFormat; // 'm4a' | 'mp3' (audio only)
  final String quality;

  /// "artist title" to find the YouTube video for a Spotify track.
  final String? searchQuery;

  /// Look up rich metadata (album/genre/cover) via iTunes for this download.
  final bool enrich;
  StreamInfo? videoStream;
  StreamInfo? audioStream;
  TrackMeta? meta;
}

class DownloaderNotifier extends Notifier<List<DownloadTask>> {
  DownloadDatabase? _db;
  final Map<String, StreamSubscription<List<int>>> _subs = {};
  final Map<String, Completer<void>> _completers = {};
  final Map<String, _Job> _jobs = {};
  final Set<String> _running = {};
  bool _serviceOn = false;
  int _seq = 0;

  @override
  List<DownloadTask> build() {
    _init();
    ref.onDispose(() {
      for (final s in _subs.values) {
        s.cancel();
      }
    });
    return const [];
  }

  Future<void> _init() async {
    _db = await DownloadDatabase.open();
    final restored = await _db!.getAll();
    state = [
      for (final t in restored)
        t.status.isActive ? t.copyWith(status: DownloadStatus.failed) : t,
    ];
  }

  Future<void> enqueue(DownloadRequest req) async {
    await _addTask(
      videoId: req.videoId,
      title: req.title,
      author: req.author,
      thumbnailUrl: req.thumbnailUrl,
      container: req.container,
      isAudio: req.isAudio,
      audioFormat: req.audioFormat,
      quality: req.quality,
      videoStream: req.videoStream,
      audioStream: req.audioStream,
    );
    _pump();
    unawaited(_syncNotification());
  }

  /// Returns how many videos were enqueued.
  Future<int> enqueuePlaylist({
    required String playlistId,
    required bool isAudio,
    required String container,
    required String? audioFormat,
    required String quality,
  }) async {
    final videos =
        await PlaylistResolver.getVideos(playlistId, limit: _playlistCap);
    for (final v in videos) {
      await _addTask(
        videoId: v.id,
        title: v.title.isEmpty ? v.id : v.title,
        author: '',
        thumbnailUrl: 'https://i.ytimg.com/vi/${v.id}/hqdefault.jpg',
        container: container,
        isAudio: isAudio,
        audioFormat: audioFormat,
        quality: quality,
      );
    }
    _pump();
    unawaited(_syncNotification());
    return videos.length;
  }

  /// Enqueues Spotify tracks: each resolves its YouTube video by search and is
  /// enriched with iTunes metadata (album/genre/cover) at download time.
  Future<int> enqueueSpotify(
    List<SpotifyTrack> tracks, {
    required String container,
    required String? audioFormat,
    required String quality,
  }) async {
    for (final t in tracks) {
      await _addTask(
        videoId: '',
        title: t.title,
        author: t.artist,
        thumbnailUrl: '',
        container: container,
        isAudio: true,
        audioFormat: audioFormat,
        quality: quality,
        searchQuery: '${t.artist} ${t.title}'.trim(),
        enrich: true,
      );
    }
    _pump();
    unawaited(_syncNotification());
    return tracks.length;
  }

  Future<void> _addTask({
    required String videoId,
    required String title,
    required String author,
    required String thumbnailUrl,
    required String container,
    required bool isAudio,
    required String? audioFormat,
    required String quality,
    String? searchQuery,
    bool enrich = false,
    StreamInfo? videoStream,
    StreamInfo? audioStream,
  }) async {
    final db = _db ??= await DownloadDatabase.open();
    final dir =
        isAudio ? await FilePaths.audioDir() : await FilePaths.videosDir();
    final base = FilePaths.sanitize(FilePaths.cleanTitle(title));
    final filePath = _uniquePath(dir.path, base, container);
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_seq++}';

    final task = DownloadTask(
      id: id,
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      filePath: filePath,
      status: DownloadStatus.enqueued,
      progress: 0,
      createdAt: DateTime.now(),
      isAudio: isAudio,
      convertToMp3: false,
      quality: quality,
      container: container,
    );
    _jobs[id] = _Job(
      videoId: videoId,
      isAudio: isAudio,
      audioFormat: audioFormat,
      quality: quality,
      searchQuery: searchQuery,
      enrich: enrich,
      videoStream: videoStream,
      audioStream: audioStream,
    );
    await db.insert(task);
    state = [task, ...state];
  }

  /// Avoids overwriting a different song with the same name (two "In The End"s)
  /// by appending " (2)", " (3)"... — for the file and its cover sidecar.
  String _uniquePath(String dir, String base, String ext) {
    final claimed = {for (final t in state) t.filePath};
    var candidate = '$dir/$base.$ext';
    var n = 1;
    while (claimed.contains(candidate) || File(candidate).existsSync()) {
      candidate = '$dir/$base (${++n}).$ext';
    }
    return candidate;
  }

  void _pump() {
    for (final t in state) {
      if (_running.length >= _maxConcurrent) break;
      if (t.status == DownloadStatus.enqueued &&
          !_running.contains(t.id) &&
          _jobs.containsKey(t.id)) {
        _running.add(t.id);
        unawaited(_run(t));
      }
    }
  }

  Future<void> _run(DownloadTask task) async {
    final job = _jobs[task.id];
    if (job == null) {
      _running.remove(task.id);
      return;
    }
    try {
      await _resolveIfNeeded(job);
      if (job.enrich && task.isAudio) {
        job.meta = await MetadataEnricher.enrich(task.title, task.author);
      }
      if (task.isAudio) {
        await _runAudio(task, job);
      } else {
        await _runVideo(task, job);
      }
      _patch(task.copyWith(status: DownloadStatus.complete, progress: 100));
      _refreshLibrary();
    } catch (e) {
      debugPrint('[TubeDL] download error: $e');
      _cleanupTemps(task);
      if (_byId(task.id)?.status != DownloadStatus.canceled) {
        _deleteFile(task.filePath);
        _patch(task.copyWith(status: DownloadStatus.failed));
        ref.read(lastDownloadErrorProvider.notifier).state =
            e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      _subs.remove(task.id);
      _completers.remove(task.id);
      _running.remove(task.id);
      _pump();
    }
  }

  Future<void> _resolveIfNeeded(_Job job) async {
    if (job.audioStream != null) return;
    // Spotify tracks arrive without a videoId — find it by searching.
    if (job.videoId.isEmpty && job.searchQuery != null) {
      final results = await ref
          .read(youtubeExplodeProvider)
          .search
          .searchContent(job.searchQuery!, filter: TypeFilters.video);
      final videos = results.whereType<SearchVideo>().toList();
      if (videos.isEmpty) {
        throw Exception('Sin resultados para "${job.searchQuery}"');
      }
      job.videoId = videos.first.id.value;
    }
    final svc = ref.read(extractorServiceProvider);
    final m = await svc.manifest(job.videoId);
    job.audioStream = svc.pickAudio(m);
    if (!job.isAudio) {
      job.videoStream = svc.pickVideoByQuality(m, job.quality);
    }
  }

  Future<void> _runAudio(DownloadTask task, _Job job) async {
    final src = '${task.filePath}.src';
    await _downloadTo(task, job.audioStream!, src, report: true);
    _patch(task.copyWith(status: DownloadStatus.converting));
    final cover = await _prepareCover(task, coverUrl: job.meta?.coverUrl);
    final codec = job.audioFormat == 'mp3'
        ? '-c:a libmp3lame -b:a 320k -id3v2_version 3'
        : '-c:a copy';
    await _transcodeWithCover(
        '-i "$src"', codec, cover, _metaArgs(task, job.meta), task.filePath);
    _deleteFile(src);
  }

  Future<void> _runVideo(DownloadTask task, _Job job) async {
    final vtmp = '${task.filePath}.v';
    final atmp = '${task.filePath}.a';
    await _downloadTo(task, job.videoStream!, vtmp, report: true);
    _patch(task.copyWith(status: DownloadStatus.converting));
    await _downloadTo(task, job.audioStream!, atmp, report: false);
    await _prepareCover(task); // sidecar thumbnail for the library grid
    await _ffmpeg('-y -i "$vtmp" -i "$atmp" -map 0:v:0 -map 1:a:0 -c copy '
        '${_metaArgs(task, job.meta)} "${task.filePath}"');
    _deleteFile(vtmp);
    _deleteFile(atmp);
  }

  Future<void> _ffmpeg(String args) async {
    final session = await FFmpegKit.execute(args);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('ffmpeg rc=$rc ${(await session.getAllLogsAsString()) ?? ''}');
    }
  }

  /// Transcodes/remuxes audio, embedding [cover] as attached cover art when
  /// available. Falls back to no-cover if the embed fails, so a thumbnail
  /// problem never breaks the download.
  Future<void> _transcodeWithCover(
    String input,
    String codec,
    String? cover,
    String meta,
    String output,
  ) async {
    if (cover != null) {
      try {
        await _ffmpeg('-y $input -i "$cover" -map 0:a:0 -map 1:0 $codec '
            '-c:v copy -disposition:v:0 attached_pic $meta "$output"');
        return;
      } catch (e) {
        debugPrint('[TubeDL] cover embed failed, retrying plain: $e');
      }
    }
    await _ffmpeg('-y $input -vn $codec $meta "$output"');
  }

  String _metaArgs(DownloadTask task, TrackMeta? meta) {
    final artist =
        (meta != null && meta.artist.isNotEmpty) ? meta.artist : task.author;
    final b = StringBuffer('-metadata title="${_q(task.title)}"');
    if (artist.isNotEmpty) b.write(' -metadata artist="${_q(artist)}"');
    if (meta != null) {
      if (meta.album.isNotEmpty) {
        b.write(' -metadata album="${_q(meta.album)}"'
            ' -metadata album_artist="${_q(artist)}"');
      }
      if (meta.genre.isNotEmpty) b.write(' -metadata genre="${_q(meta.genre)}"');
      if (meta.year != null) b.write(' -metadata date="${meta.year}"');
      if (meta.trackNumber != null) {
        b.write(' -metadata track="${meta.trackNumber}"');
      }
    }
    return b.toString();
  }

  String _q(String s) => s.replaceAll('"', '');

  /// Downloads the video thumbnail into the app-private thumbs folder, named by
  /// the file's base name so the library can find it. Returns its path (also
  /// used as the FFmpeg cover source), or null on failure.
  Future<String?> _prepareCover(DownloadTask task, {String? coverUrl}) async {
    try {
      final url = (coverUrl != null && coverUrl.isNotEmpty)
          ? coverUrl
          : 'https://i.ytimg.com/vi/${task.videoId}/hqdefault.jpg';
      final dir = await FilePaths.thumbsDir();
      final path = '${dir.path}/${FilePaths.baseName(task.filePath)}.jpg';
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse(url));
        final resp = await req.close();
        if (resp.statusCode != 200) return null;
        await resp.pipe(File(path).openWrite());
        return path;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Downloads via youtube_explode's chunked client, which fetches the stream
  /// in small ranged segments. A single long GET gets throttled / dropped by
  /// YouTube ("connection closed"); segmented requests stay fast.
  Future<void> _downloadTo(
    DownloadTask task,
    StreamInfo stream,
    String path, {
    required bool report,
  }) async {
    final yt = ref.read(youtubeExplodeProvider);
    final total = stream.size.totalBytes;
    final sw = Stopwatch()..start();
    IOSink? sink;
    try {
      sink = File(path).openWrite();
      var received = 0;
      var lastPercent = -1;
      final completer = Completer<void>();

      final sub = yt.videos.streamsClient.get(stream).listen(
        (chunk) {
          sink!.add(chunk);
          received += chunk.length;
          if (report) {
            final percent = total > 0 ? (received * 100 ~/ total) : 0;
            if (percent >= lastPercent + 5 || percent == 100) {
              lastPercent = percent;
              _patch(task.copyWith(
                status: DownloadStatus.running,
                progress: percent.clamp(0, 100),
              ));
            }
          }
        },
        onError: (Object e, StackTrace s) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      _subs[task.id] = sub;
      _completers[task.id] = completer;
      await completer.future;
      await sink.flush();
      await sink.close();
      sink = null;
      final kbps = (received / 1024) / (sw.elapsedMilliseconds / 1000);
      debugPrint('[TubeDL] done $received/$total bytes in '
          '${sw.elapsedMilliseconds}ms (${kbps.toStringAsFixed(0)} KB/s)');
    } finally {
      _completers.remove(task.id);
      await _subs.remove(task.id)?.cancel();
      try {
        await sink?.close();
      } catch (_) {}
    }
  }

  Future<void> cancel(String id) async {
    final task = _byId(id);
    if (task != null) _patch(task.copyWith(status: DownloadStatus.canceled));
    final completer = _completers[id];
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('canceled'));
    }
    await _subs[id]?.cancel();
    if (task != null) _cleanupTemps(task);
  }

  Future<void> retry(String id) async {
    final task = _byId(id);
    if (task == null || _jobs[id] == null) return;
    _patch(task.copyWith(status: DownloadStatus.enqueued, progress: 0));
    _pump();
  }

  Future<void> remove(String id) async {
    final completer = _completers[id];
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('removed'));
    }
    await _subs[id]?.cancel();
    final task = _byId(id);
    if (task != null) {
      _deleteFile(task.filePath);
      _cleanupTemps(task);
    }
    _jobs.remove(id);
    _running.remove(id);
    await _db?.delete(id);
    state = state.where((t) => t.id != id).toList();
    _pump();
    unawaited(_syncNotification());
  }

  Future<void> clearFinished() async {
    final finished = state.where((t) => !t.status.isActive).toList();
    for (final t in finished) {
      _jobs.remove(t.id);
      await _db?.delete(t.id);
    }
    state = state.where((t) => t.status.isActive).toList();
  }

  void _cleanupTemps(DownloadTask task) {
    _deleteFile('${task.filePath}.v');
    _deleteFile('${task.filePath}.a');
    _deleteFile('${task.filePath}.src');
  }

  DownloadTask? _byId(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _patch(DownloadTask task) {
    state = [
      for (final t in state) if (t.id == task.id) task else t,
    ];
    _db?.update(task);
    unawaited(_syncNotification());
  }

  /// Keeps the foreground service + progress notification in sync with the
  /// active downloads. The service keeps downloads running while minimized.
  Future<void> _syncNotification() async {
    final active = state.where((t) => t.status.isActive).toList();
    if (active.isEmpty) {
      if (_serviceOn) {
        _serviceOn = false;
        await FlutterForegroundTask.stopService();
      }
      return;
    }
    final first = active.first;
    final detail = switch (first.status) {
      DownloadStatus.converting => 'procesando…',
      DownloadStatus.enqueued => 'en cola…',
      _ => '${first.progress}%',
    };
    final title =
        active.length == 1 ? 'Descargando' : 'Descargando (${active.length})';
    final text = '${first.title} · $detail';
    if (_serviceOn) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } else {
      _serviceOn = true;
      await FlutterForegroundTask.startService(
        serviceId: 256,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  void _deleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _refreshLibrary() {
    try {
      ref.read(libraryProvider.notifier).refresh();
    } catch (_) {}
  }
}
