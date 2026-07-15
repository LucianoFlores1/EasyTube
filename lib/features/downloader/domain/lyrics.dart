/// Song lyrics in both flavours: [plain] is embedded in the file's tags,
/// [synced] (LRC, timestamped) is written as a .lrc sidecar.
class Lyrics {
  const Lyrics({this.plain, this.synced});

  final String? plain;
  final String? synced;
}
