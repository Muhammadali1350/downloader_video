import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/youtube_service.dart';
import 'services/settings_service.dart';

/// Provides a singleton [SettingsService] instance.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// Provides a singleton [YoutubeService] instance.
final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return YoutubeService(settingsService);
});

/// UI Language Provider ('ru' or 'en')
class LanguageNotifier extends Notifier<String> {
  @override
  String build() => 'ru';

  void toggle() {
    state = state == 'ru' ? 'en' : 'ru';
  }

  void setLanguage(String lang) {
    if (lang == 'ru' || lang == 'en') {
      state = lang;
    }
  }
}
final languageProvider = NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

/// Toggles whether we show separate progress bars for Video, Audio, and Merge processes.
class SeparateProgressBarsNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.read(settingsServiceProvider).loadSettings().then((settings) {
      state = settings.separateProgressBars;
    });
    return false;
  }

  void set(bool value) async {
    state = value;
    final settingsService = ref.read(settingsServiceProvider);
    final settings = await settingsService.loadSettings();
    final updatedSettings = AppSettings(
      userAgent: settings.userAgent,
      cookies: settings.cookies,
      separateProgressBars: value,
    );
    await settingsService.saveSettings(updatedSettings);
  }
}
final separateProgressBarsProvider = NotifierProvider<SeparateProgressBarsNotifier, bool>(SeparateProgressBarsNotifier.new);

/// Aggregated logs to show in the UI.
class LogsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void add(String message) {
    state = [...state, message];
  }

  void clear() {
    state = [];
  }
}
final logsProvider = NotifierProvider<LogsNotifier, List<String>>(LogsNotifier.new);

/// Overall download progress (0.0 - 1.0)
class ProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void set(double value) {
    state = value;
  }
}
final progressProvider = NotifierProvider<ProgressNotifier, double>(ProgressNotifier.new);

/// Detailed progress state for separate video, audio, and conversion stages
class DetailedProgressState {
  final double videoProgress;
  final double audioProgress;
  final String currentAction; // 'idle', 'downloading_video', 'downloading_audio', 'converting', 'exporting'
  final bool hasVideo;
  final bool hasAudio;

  DetailedProgressState({
    this.videoProgress = 0.0,
    this.audioProgress = 0.0,
    this.currentAction = 'idle',
    this.hasVideo = true,
    this.hasAudio = true,
  });
}

class DetailedProgressNotifier extends Notifier<DetailedProgressState> {
  @override
  DetailedProgressState build() => DetailedProgressState();

  void update({double? videoProgress, double? audioProgress, String? currentAction}) {
    state = DetailedProgressState(
      videoProgress: videoProgress ?? state.videoProgress,
      audioProgress: audioProgress ?? state.audioProgress,
      currentAction: currentAction ?? state.currentAction,
      hasVideo: state.hasVideo,
      hasAudio: state.hasAudio,
    );
  }

  void initialize({required bool hasVideo, required bool hasAudio}) {
    state = DetailedProgressState(
      videoProgress: 0.0,
      audioProgress: 0.0,
      currentAction: 'idle',
      hasVideo: hasVideo,
      hasAudio: hasAudio,
    );
  }

  void reset() {
    state = DetailedProgressState();
  }
}
final detailedProgressProvider = NotifierProvider<DetailedProgressNotifier, DetailedProgressState>(DetailedProgressNotifier.new);

/// Download Speed and ETA Stats
class DownloadStats {
  final double speedBytesPerSec;
  final String eta;

  DownloadStats({required this.speedBytesPerSec, required this.eta});
}

class DownloadStatsNotifier extends Notifier<DownloadStats?> {
  @override
  DownloadStats? build() => null;

  void setStats(double speed, String eta) {
    state = DownloadStats(speedBytesPerSec: speed, eta: eta);
  }

  void clear() {
    state = null;
  }
}
final downloadStatsProvider = NotifierProvider<DownloadStatsNotifier, DownloadStats?>(DownloadStatsNotifier.new);

/// Individual video download progress inside a playlist (videoId -> progress 0.0 - 1.0)
class PlaylistProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};

  void updateProgress(String videoId, double progress) {
    state = {...state, videoId: progress};
  }

  void reset() {
    state = {};
  }
}
final playlistProgressProvider = NotifierProvider<PlaylistProgressNotifier, Map<String, double>>(PlaylistProgressNotifier.new);

/// High-level status of the current job.
class StatusNotifier extends Notifier<String> {
  @override
  String build() => 'idle';

  void set(String status) {
    state = status;
  }
}
final statusProvider = NotifierProvider<StatusNotifier, String>(StatusNotifier.new);