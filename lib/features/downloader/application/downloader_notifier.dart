import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../shared/providers/youtube_explode_provider.dart';
import '../../library/application/library_notifier.dart';
import '../data/download_database.dart';
import '../data/file_paths.dart';
import '../domain/download_request.dart';
import '../domain/download_task.dart';

final downloaderProvider =
    NotifierProvider<DownloaderNotifier, List<DownloadTask>>(
  DownloaderNotifier.new,
);

const _userAgent =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

const _maxConcurrent = 2; // ponytail: fixed gate; tune if throughput matters
const _playlistCap = 50; // ponytail: cap huge playlists

/// In-memory (not persisted) download job. [streamInfo] is null for playlist
/// items, which resolve their muxed stream lazily in [_run].
class _Job {
  _Job({
    required this.videoId,
    required this.wantAudio,
    required this.audioCodec,
    required this.quality,
    this.streamInfo,
  });
  final String videoId;
  final bool wantAudio;
  final String? audioCodec;
  final String quality;
  StreamInfo? streamInfo;
}

class DownloaderNotifier extends Notifier<List<DownloadTask>> {
  DownloadDatabase? _db;
  final Map<String, StreamSubscription<List<int>>> _subs = {};
  final Map<String, HttpClient> _clients = {};
  final Map<String, _Job> _jobs = {};
  final Set<String> _running = {};
  int _seq = 0;

  @override
  List<DownloadTask> build() {
    _init();
    ref.onDispose(() {
      for (final s in _subs.values) {
        s.cancel();
      }
      for (final c in _clients.values) {
        c.close(force: true);
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
      audioCodec: req.audioCodec,
      quality: req.quality,
      streamInfo: req.streamInfo,
    );
    _pump();
  }

  /// Enqueues every video of a playlist with one chosen format.
  Future<void> enqueuePlaylist({
    required String playlistId,
    required bool isAudio,
    required String container,
    required String? audioCodec,
    required String quality,
  }) async {
    final yt = ref.read(youtubeExplodeProvider);
    final videos =
        await yt.playlists.getVideos(playlistId).take(_playlistCap).toList();
    for (final v in videos) {
      await _addTask(
        videoId: v.id.value,
        title: v.title,
        author: v.author,
        thumbnailUrl: v.thumbnails.highResUrl,
        container: container,
        isAudio: isAudio,
        audioCodec: audioCodec,
        quality: quality,
      );
    }
    _pump();
  }

  Future<void> _addTask({
    required String videoId,
    required String title,
    required String author,
    required String thumbnailUrl,
    required String container,
    required bool isAudio,
    required String? audioCodec,
    required String quality,
    StreamInfo? streamInfo,
  }) async {
    final db = _db ??= await DownloadDatabase.open();
    final dir = isAudio ? await FilePaths.audioDir() : await FilePaths.videosDir();
    final base = FilePaths.sanitize('$title [$quality]');
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_seq++}';

    final task = DownloadTask(
      id: id,
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      filePath: '${dir.path}/$base.$container',
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
      wantAudio: isAudio,
      audioCodec: audioCodec,
      quality: quality,
      streamInfo: streamInfo,
    );
    await db.insert(task);
    state = [task, ...state];
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
    final downloadPath = task.isAudio ? '${task.filePath}.src' : task.filePath;
    final client = HttpClient();
    _clients[task.id] = client;
    IOSink? sink;

    try {
      final streamInfo = job.streamInfo ?? await _resolveStream(job);
      final request = await client.getUrl(streamInfo.url);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : streamInfo.size.totalBytes;
      sink = File(downloadPath).openWrite();
      var received = 0;
      var lastPercent = -1;
      final completer = Completer<void>();

      final sub = response.listen(
        (chunk) {
          sink!.add(chunk);
          received += chunk.length;
          final percent = total > 0 ? (received * 100 ~/ total) : 0;
          // ponytail: update every 5% to avoid rebuild spam / jank.
          if (percent >= lastPercent + 5 || percent == 100) {
            lastPercent = percent;
            _patch(task.copyWith(
              status: DownloadStatus.running,
              progress: percent.clamp(0, 100),
            ));
          }
        },
        onError: completer.completeError,
        onDone: completer.complete,
        cancelOnError: true,
      );
      _subs[task.id] = sub;

      await completer.future;
      await sink.flush();
      await sink.close();
      sink = null;
      _subs.remove(task.id);

      if (task.isAudio) {
        await _extractAudio(task, downloadPath, job.audioCodec ?? 'copy');
      } else {
        _patch(task.copyWith(status: DownloadStatus.complete, progress: 100));
        _refreshLibrary();
      }
    } catch (e) {
      debugPrint('[TubeDL] download error: $e');
      _subs.remove(task.id);
      try {
        await sink?.close();
      } catch (_) {}
      _deleteFile(downloadPath);
      if (_byId(task.id)?.status != DownloadStatus.canceled) {
        _patch(task.copyWith(status: DownloadStatus.failed));
      }
    } finally {
      _clients.remove(task.id)?.close(force: true);
      _running.remove(task.id);
      _pump();
    }
  }

  Future<StreamInfo> _resolveStream(_Job job) async {
    final yt = ref.read(youtubeExplodeProvider);
    final manifest = await yt.videos.streamsClient.getManifest(job.videoId);
    final muxed = manifest.muxed.sortByVideoQuality();
    if (muxed.isEmpty) throw const HttpException('Sin streams disponibles');
    final info = job.wantAudio
        ? muxed.first
        : muxed.firstWhere((m) => m.qualityLabel == job.quality,
            orElse: () => muxed.first);
    job.streamInfo = info;
    return info;
  }

  Future<void> _extractAudio(
    DownloadTask task,
    String sourcePath,
    String codec,
  ) async {
    _patch(task.copyWith(status: DownloadStatus.converting));
    final args = codec == 'copy'
        ? '-y -i "$sourcePath" -vn -c:a copy "${task.filePath}"'
        : '-y -i "$sourcePath" -vn -c:a $codec -b:a 320k "${task.filePath}"';

    final session = await FFmpegKit.execute(args);
    final rc = await session.getReturnCode();
    _deleteFile(sourcePath);

    if (ReturnCode.isSuccess(rc)) {
      _patch(task.copyWith(status: DownloadStatus.complete, progress: 100));
      _refreshLibrary();
    } else {
      debugPrint('[TubeDL] ffmpeg failed rc=$rc '
          'logs=${(await session.getAllLogsAsString()) ?? ''}');
      _patch(task.copyWith(status: DownloadStatus.failed));
    }
  }

  Future<void> cancel(String id) async {
    await _subs.remove(id)?.cancel();
    _clients.remove(id)?.close(force: true);
    _running.remove(id);
    final task = _byId(id);
    if (task != null) {
      _deleteFile(task.isAudio ? '${task.filePath}.src' : task.filePath);
      _patch(task.copyWith(status: DownloadStatus.canceled));
    }
    _pump();
  }

  Future<void> retry(String id) async {
    final task = _byId(id);
    if (task == null || _jobs[id] == null) return;
    _patch(task.copyWith(status: DownloadStatus.enqueued, progress: 0));
    _pump();
  }

  Future<void> remove(String id) async {
    await _subs.remove(id)?.cancel();
    _clients.remove(id)?.close(force: true);
    _running.remove(id);
    final task = _byId(id);
    if (task != null) {
      _deleteFile(task.filePath);
      _deleteFile('${task.filePath}.src');
    }
    _jobs.remove(id);
    await _db?.delete(id);
    state = state.where((t) => t.id != id).toList();
    _pump();
  }

  Future<void> clearFinished() async {
    final finished = state.where((t) => !t.status.isActive).toList();
    for (final t in finished) {
      _jobs.remove(t.id);
      await _db?.delete(t.id);
    }
    state = state.where((t) => t.status.isActive).toList();
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
