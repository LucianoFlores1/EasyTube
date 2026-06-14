import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.preferAudio = false,
    this.showNotifications = true,
    this.storagePath = '',
  });

  final bool preferAudio;
  final bool showNotifications;
  final String storagePath;

  SettingsState copyWith({
    bool? preferAudio,
    bool? showNotifications,
    String? storagePath,
  }) {
    return SettingsState(
      preferAudio: preferAudio ?? this.preferAudio,
      showNotifications: showNotifications ?? this.showNotifications,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsState> {
  static const _kPreferAudio = 'prefer_audio';
  static const _kShowNotifications = 'show_notifications';

  SharedPreferences? _prefs;

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      preferAudio: prefs.getBool(_kPreferAudio) ?? false,
      showNotifications: prefs.getBool(_kShowNotifications) ?? true,
    );
  }

  Future<void> setPreferAudio(bool value) async {
    state = state.copyWith(preferAudio: value);
    await _prefs?.setBool(_kPreferAudio, value);
  }

  Future<void> setShowNotifications(bool value) async {
    state = state.copyWith(showNotifications: value);
    await _prefs?.setBool(_kShowNotifications, value);
  }

  void setStoragePath(String path) =>
      state = state.copyWith(storagePath: path);
}
