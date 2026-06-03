import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppSettings {
  final String userAgent;
  final String cookies;

  AppSettings({
    required this.userAgent,
    required this.cookies,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      cookies: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userAgent': userAgent,
      'cookies': cookies,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      userAgent: json['userAgent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      cookies: json['cookies'] ?? '',
    );
  }
}

class SettingsService {
  static const _fileName = 'app_settings.json';

  Future<File> _getSettingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AppSettings> loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (!await file.exists()) {
        return AppSettings.defaultSettings();
      }
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings.defaultSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final file = await _getSettingsFile();
      final contents = jsonEncode(settings.toJson());
      await file.writeAsString(contents);
    } catch (_) {
      // Ignore saving errors
    }
  }
}
