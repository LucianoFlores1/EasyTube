import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_downloader/flutter_downloader.dart' show FlutterDownloader;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../library/application/library_notifier.dart';
import '../data/download_callback.dart';
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

class DownloaderNotifier extends Notifier<List<DownloadTask>> {
  DownloadDatabase? _db;
  ReceivePort? _port;

  @override
  List<DownloadTask> build() {
    _init();
    ref.onDispose(_disposeResources);
    return const [];
  }

  Future<void> _init() async {
    _db = await DownloadDatabase.open();
    state = await _db!.getAll();
    _bindPort();
  }

  void _bindPort() {
    final port = ReceivePort();
    _port = port;
    IsolateNameServer.removePortNameMapping(downloaderPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, downloaderPortName);
    port.listen((dynamic data) {
      final list = data as List<dynamic>;
      _onUpdate(list[0] as String, list[1] as int, list[2] as int);
    });
    FlutterDownloader.registerCallback(downloadCallback, step: 2);
  }

  void _disposeResources() {
    _port?.close();
    IsolateNameServer.removePortNameMapping(downloaderPortName);
  }

  Future<void> enqueue(DownloadRequest req) async {
    final db = _db ??= await DownloadDatabase.open();
    final dir =
        req.isAudio ? await FilePaths.audioDir() : await FilePaths.videosDir();
    final downloadContainer = req.convertToMp3 ? 'm4a' : req.container;
    final base = FilePaths.sanitize('${req.title} [${req.quality}]');
    final fileName = '$base.$downloadContainer';

    final taskId = await FlutterDownloader.enqueue(
      url: req.url,
      savedDir: dir.path,
      fileName: fileName,
      headers: {'User-Agent': _userAgent},
      showNotification: true,
      openFileFromNotification: false,
    );
    if (taskId == null) throw const DownloadFailure();

    final task = DownloadTask(
      id: taskId,
      videoId: req.videoId,
      title: req.title,
      author: req.author,
      thumbnailUrl: req.thumbnailUrl,
      filePath: '${dir.path}/$fileName',
      status: DownloadStatus.enqueued,
      progress: 0,
      createdAt: DateTime.now(),
      isAudio: req.isAudio,
      convertToMp3: req.convertToMp3,
      quality: req.quality,
      container: downloadContainer,
    );
    await db.insert(task);
    state = [task, ...state];
  }

  void _onUpdate(String id, int statusCode, int progress) {
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final current = state[index];
    final status = DownloadStatus.fromPluginCode(statusCode);

    if (status == DownloadStatus.complete &&
        current.convertToMp3 &&
        current.container != 'mp3') {
      _patch(current.copyWith(progress: 100));
      _convertToMp3(current);
      return;
    }

    _patch(current.copyWith(status: status, progress: progress));

    if (status == DownloadStatus.complete) _refreshLibrary();
  }

  Future<void> _convertToMp3(DownloadTask task) async {
    _patch(task.copyWith(status: DownloadStatus.converting));
    final input = task.filePath;
    final output = '${input.substring(0, input.lastIndexOf('.'))}.mp3';

    final session = await FFmpegKit.execute(
      '-y -i "$input" -vn -codec:a libmp3lame -b:a 320k "$output"',
    );
    final rc = await session.getReturnCode();

    if (ReturnCode.isSuccess(rc)) {
      try {
        final f = File(input);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      _patch(task.copyWith(
        filePath: output,
        container: 'mp3',
        status: DownloadStatus.complete,
        progress: 100,
      ));
      _refreshLibrary();
    } else {
      _patch(task.copyWith(status: DownloadStatus.failed));
    }
  }

  void _patch(DownloadTask task) {
    state = [
      for (final t in state) if (t.id == task.id) task else t,
    ];
    _db?.update(task);
  }

  Future<void> pause(String id) => FlutterDownloader.pause(taskId: id);

  Future<void> resume(String id) async {
    final newId = await FlutterDownloader.resume(taskId: id);
    if (newId != null) await _swapId(id, newId);
  }

  Future<void> retry(String id) async {
    final newId = await FlutterDownloader.retry(taskId: id);
    if (newId != null) await _swapId(id, newId);
  }

  Future<void> cancel(String id) => FlutterDownloader.cancel(taskId: id);

  Future<void> remove(String id) async {
    await FlutterDownloader.remove(taskId: id, shouldDeleteContent: true);
    await _db?.delete(id);
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> clearFinished() async {
    final finished = state.where((t) => !t.status.isActive).toList();
    for (final t in finished) {
      await FlutterDownloader.remove(taskId: t.id, shouldDeleteContent: false);
      await _db?.delete(t.id);
    }
    state = state.where((t) => t.status.isActive).toList();
  }

  Future<void> _swapId(String oldId, String newId) async {
    await _db?.updateId(oldId, newId);
    state = [
      for (final t in state)
        if (t.id == oldId)
          t.copyWith(id: newId, status: DownloadStatus.enqueued)
        else
          t,
    ];
  }

  void _refreshLibrary() {
    try {
      ref.read(libraryProvider.notifier).refresh();
    } catch (_) {}
  }
}
