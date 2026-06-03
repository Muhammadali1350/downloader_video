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

/// Aggregated logs to show in the UI (e.g. a console panel).
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

/// Overall download progress in range 0.0–1.0.
class ProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void set(double value) {
    state = value;
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, double>(ProgressNotifier.new);

/// High-level status of the current job.
///
/// Expected values:
/// - `idle`
/// - `downloading`
/// - `converting`
/// - `exporting`
/// - `done`
/// - `error`
class StatusNotifier extends Notifier<String> {
  @override
  String build() => 'idle';

  void set(String status) {
    state = status;
  }
}

final statusProvider = NotifierProvider<StatusNotifier, String>(StatusNotifier.new);

