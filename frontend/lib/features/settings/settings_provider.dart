import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool audioOnlyMode;

  const SettingsState({
    this.audioOnlyMode = false,
  });

  SettingsState copyWith({bool? audioOnlyMode}) {
    return SettingsState(
      audioOnlyMode: audioOnlyMode ?? this.audioOnlyMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void toggleAudioOnlyMode() {
    state = state.copyWith(audioOnlyMode: !state.audioOnlyMode);
  }

  void setAudioOnlyMode(bool value) {
    state = state.copyWith(audioOnlyMode: value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
