enum DownloadStatus {
  enqueued,
  running,
  paused,
  converting,
  complete,
  failed,
  canceled;

  bool get isActive =>
      this == DownloadStatus.enqueued ||
      this == DownloadStatus.running ||
      this == DownloadStatus.converting;

  bool get isFinished => this == DownloadStatus.complete;

  /// Maps the raw integer status emitted by flutter_downloader's background
  /// isolate to our domain enum. The plugin's integer values are stable.
  static DownloadStatus fromPluginCode(int code) {
    return switch (code) {
      1 => DownloadStatus.enqueued,
      2 => DownloadStatus.running,
      3 => DownloadStatus.complete,
      4 => DownloadStatus.failed,
      5 => DownloadStatus.canceled,
      6 => DownloadStatus.paused,
      _ => DownloadStatus.enqueued,
    };
  }
}

/// A row in the `download_tasks` table and the unit of the reactive queue.
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.filePath,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.isAudio,
    required this.convertToMp3,
    required this.quality,
    required this.container,
  });

  /// flutter_downloader task id (changes on resume/retry).
  final String id;
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String filePath;
  final DownloadStatus status;
  final int progress; // 0-100
  final DateTime createdAt;
  final bool isAudio;
  final bool convertToMp3;
  final String quality;
  final String container;

  DownloadTask copyWith({
    String? id,
    String? filePath,
    DownloadStatus? status,
    int? progress,
    String? container,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      isAudio: isAudio,
      convertToMp3: convertToMp3,
      quality: quality,
      container: container ?? this.container,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'author': author,
        'thumbnailUrl': thumbnailUrl,
        'filePath': filePath,
        'status': status.index,
        'progress': progress,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isAudio': isAudio ? 1 : 0,
        'convertToMp3': convertToMp3 ? 1 : 0,
        'quality': quality,
        'container': container,
      };

  factory DownloadTask.fromMap(Map<String, Object?> map) => DownloadTask(
        id: map['id'] as String,
        videoId: map['videoId'] as String,
        title: map['title'] as String,
        author: (map['author'] as String?) ?? '',
        thumbnailUrl: map['thumbnailUrl'] as String,
        filePath: map['filePath'] as String,
        status: DownloadStatus.values[map['status'] as int],
        progress: map['progress'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        isAudio: (map['isAudio'] as int) == 1,
        convertToMp3: (map['convertToMp3'] as int) == 1,
        quality: (map['quality'] as String?) ?? '',
        container: (map['container'] as String?) ?? '',
      );
}
