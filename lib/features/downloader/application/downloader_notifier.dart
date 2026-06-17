import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../shared/providers/youtube_explode_provider.dart';
import '../../extractor/application/extractor_service.dart';
import '../../library/application/library_notifier.dart';
import '../data/download_database.dart';
import '../data/file_paths.dart';
import '../domain/download_request.dart';
import '../domain/download_task.dart';

final downloaderProvider =
    NotifierProvider<DownloaderNotifier, List<DownloadTask>>(
  DownloaderNotifier.new,
);

const _userAgent = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';
const _maxConcurrent = 2;
const _playlistCap = 50;

/// In-memory job. Streams are null for playlist items (resolved in [_run]).
class _Job {
  _Job({
    required this.videoId,
    required this.isAudio,
    required this.audioFormat,
    required this.quality,
    this.videoStream,
    this.audioStream,
  });
  final String videoId;
  final bool isAudio;
  final String? audioFormat; // 'm4a' | 'mp3' (audio only)
  final String quality;
  StreamInfo? videoStream;
  StreamInfo? audioStream;
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
      audioFormat: req.audioFormat,
      quality: req.quality,
      videoStream: req.videoStream,
      audioStream: req.audioStream,
    );
    _pump();
  }

  Future<void> enqueuePlaylist({
    required String playlistId,
    required bool isAudio,
    required String container,
    required String? audioFormat,
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
        audioFormat: audioFormat,
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
    required String? audioFormat,
    required String quality,
    StreamInfo? videoStream,
    StreamInfo? audioStream,
  }) async {
    final db = _db ??= await DownloadDatabase.open();
    final dir =
        isAudio ? await FilePaths.audioDir() : await FilePaths.videosDir();
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
      isAudio: isAudio,
      audioFormat: audioFormat,
      quality: quality,
      videoStream: videoStream,
      audioStream: audioStream,
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
    try {
      await _resolveIfNeeded(job);
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
      }
    } finally {
      _subs.remove(task.id);
      _clients.remove(task.id)?.close(force: true);
      _running.remove(task.id);
      _pump();
    }
  }

  Future<void> _resolveIfNeeded(_Job job) async {
    if (job.audioStream != null) return;
    final svc = ref.read(extractorServiceProvider);
    final m = await svc.manifest(job.videoId);
    job.audioStream = svc.pickAudio(m);
    if (!job.isAudio) {
      job.videoStream = svc.pickVideoByQuality(m, job.quality);
    }
  }

  Future<void> _runAudio(DownloadTask task, _Job job) async {
    if (job.audioFormat == 'mp3') {
      final src = '${task.filePath}.src';
      await _downloadTo(task, job.audioStream!, src, report: true);
      _patch(task.copyWith(status: DownloadStatus.converting));
      await _ffmpeg('-y -i "$src" -vn -c:a libmp3lame -b:a 320k "${task.filePath}"');
      _deleteFile(src);
    } else {
      // m4a: the AAC audio-only stream is already an .m4a — save directly.
      await _downloadTo(task, job.audioStream!, task.filePath, report: true);
    }
  }

  Future<void> _runVideo(DownloadTask task, _Job job) async {
    final vtmp = '${task.filePath}.v';
    final atmp = '${task.filePath}.a';
    await _downloadTo(task, job.videoStream!, vtmp, report: true);
    _patch(task.copyWith(status: DownloadStatus.converting));
    await _downloadTo(task, job.audioStream!, atmp, report: false);
    await _ffmpeg(
      '-y -i "$vtmp" -i "$atmp" -map 0:v:0 -map 1:a:0 -c copy "${task.filePath}"',
    );
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

  Future<void> _downloadTo(
    DownloadTask task,
    StreamInfo stream,
    String path, {
    required bool report,
  }) async {
    final client = HttpClient();
    _clients[task.id] = client;
    IOSink? sink;
    try {
      final request = await client.getUrl(stream.url);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : stream.size.totalBytes;
      sink = File(path).openWrite();
      var received = 0;
      var lastPercent = -1;
      final completer = Completer<void>();

      final sub = response.listen(
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
        onError: completer.completeError,
        onDone: completer.complete,
        cancelOnError: true,
      );
      _subs[task.id] = sub;
      await completer.future;
      await sink.flush();
      await sink.close();
      sink = null;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      _clients.remove(task.id)?.close(force: true);
    }
  }

  Future<void> cancel(String id) async {
    final task = _byId(id);
    if (task != null) _patch(task.copyWith(status: DownloadStatus.canceled));
    // Closing the client errors the active download; _run's catch sees the
    // canceled status and stops.
    _clients[id]?.close(force: true);
    if (task != null) _cleanupTemps(task);
  }

  Future<void> retry(String id) async {
    final task = _byId(id);
    if (task == null || _jobs[id] == null) return;
    _patch(task.copyWith(status: DownloadStatus.enqueued, progress: 0));
    _pump();
  }

  Future<void> remove(String id) async {
    _clients[id]?.close(force: true);
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
