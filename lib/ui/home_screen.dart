import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers.dart';
import '../services/youtube_service.dart';
import '../services/settings_service.dart';

/// Translations map for full RU and EN locales
const Map<String, Map<String, String>> _translations = {
  'en': {
    'title': 'YouTube Downloader',
    'urlHint': 'Paste YouTube / Shorts URL here...',
    'analyze': 'Analyze',
    'analyzing': 'Analyzing...',
    'settings': 'Bypass Settings',
    'cookies': 'Cookies for Authorization:',
    'cookiesHint': 'Paste Cookies (e.g., VISITOR_INFO1_LIVE=...)',
    'cookiesInfo': 'Helps bypass rate limit (429) if YouTube flags your IP.',
    'userAgent': 'Browser User-Agent:',
    'userAgentHint': 'User-Agent string...',
    'userAgentInfo': 'Simulates a real browser to prevent automated blocks.',
    'reset': 'Reset',
    'cancel': 'Cancel',
    'close': 'Close',
    'save': 'Save',
    'settingsSaved': 'Settings saved! Try analyzing again.',
    'customDownloadTitle': 'Select Download Quality',
    'tabMerge': 'Video + Audio',
    'tabVideo': 'Video Only',
    'tabAudio': 'Audio Only',
    'selectVideoTrack': 'SELECT VIDEO TRACK:',
    'selectAudioTrack': 'SELECT AUDIO TRACK:',
    'selectVideoOnlyTrack': 'SELECT VIDEO TRACK (NO SOUND):',
    'selectAudioOnlyTrack': 'SELECT AUDIO TRACK (CONVERTS TO MP3):',
    'estSize': 'ESTIMATED SIZE:',
    'downloadBtn': 'DOWNLOAD',
    'toastSaved': 'Done. Saved successfully.',
    'toastFailed': 'Download failed:',
    'toastPlaylistDone': 'Playlist download completed.',
    'toastNoVideo': 'Please paste a YouTube URL first.',
    'toastNeedAnalyze': 'Analyze the URL before downloading.',
    'toastSelectAtLeastOne': 'Please select at least one video to download.',
    'playlistTitle': 'Playlist',
    'playlistAuthor': 'Author:',
    'selectedVideosCount': 'Selected: {} of {}',
    'selectAll': 'Select All',
    'deselectAll': 'Deselect All',
    'duration': 'Duration:',
    'audioMode': 'Audio (MP3)',
    'bestMode': 'Best (Merge)',
    'fastMode': 'Fast (720p)',
    'playlistAudio': 'Playlist MP3',
    'playlistBest': 'Playlist Best',
    'playlistFast': 'Playlist Fast',
    'customDownload': 'Custom Download',
    'terminalTitle': 'Terminal Logs',
    'copyLogs': 'Copy logs',
    'logsCopied': 'Logs copied to clipboard',
    'online': 'ONLINE',
    'waitingLogs': '>> Waiting for commands...',
    'progressLabel': 'Status:',
    'speed': 'Speed:',
    'eta': 'ETA:',
    'videoProgress': 'Video stream:',
    'audioProgress': 'Audio stream:',
    'mergeProgress': 'Processing / Merge:',
    'showDetailedProgress': 'Detailed Progress Bars',
    'showDetailedProgressDesc': 'Display separate status indicators for video, audio, and conversion phases.',
    'tooltipUrlInput': 'Enter a YouTube video or playlist link',
    'tooltipAnalyze': 'Scan the link to fetch resolutions, titles, and details',
    'tooltipSettings': 'Configure cookies and User-Agent to bypass YouTube blocks',
    'tooltipCustomDownload': 'Manually select video resolution and audio stream to merge or download separately',
    'tooltipAudio': 'Download only audio and convert it to MP3 format',
    'tooltipBest': 'Download highest possible video and audio streams and merge them using FFmpeg',
    'tooltipFast': 'Quick download of single stream 720p muxed video with sound',
    'tooltipPlaylistAudio': 'Download all checked playlist items as MP3 audio files',
    'tooltipPlaylistBest': 'Download all checked playlist items in best merged quality',
    'tooltipPlaylistFast': 'Download all checked playlist items in fast muxed 720p quality',
    'tooltipCancel': 'Immediately abort download and clean up all temporary files',
    'tooltipLogs': 'Tap to expand/collapse detailed console logs',
    'tooltipLanguage': 'Switch interface language (RU / EN)',
    'tooltipProgressMode': 'Toggle unified vs. split progress bars',
    'cancelled': 'Cancelled by user',
    'idle': 'Ready',
    'downloading': 'Downloading...',
    'converting': 'Processing / Merging...',
    'exporting': 'Saving to gallery...',
    'done': 'Completed!',
    'error': 'Failed / Error',
    'advancedSettings': 'Developer Settings (Cookies & UA)',
    'devWarning': 'WARNING: Developer Settings. Modify these values ONLY if you know what you are doing. Incorrect configurations can break YouTube bypass mechanisms.',
  },
  'ru': {
    'title': 'YouTube Downloader',
    'urlHint': 'Вставьте ссылку на YouTube / Shorts...',
    'analyze': 'Анализ',
    'analyzing': 'Анализ...',
    'settings': 'Настройки обхода',
    'cookies': 'Куки (Cookies) для авторизации:',
    'cookiesHint': 'Вставьте Cookie (например, VISITOR_INFO1_LIVE=...)',
    'cookiesInfo': 'Помогает обойти rate limit (429), если YouTube считает ваш IP подозрительным.',
    'userAgent': 'User-Agent браузера:',
    'userAgentHint': 'User-Agent строка...',
    'userAgentInfo': 'Имитирует реальный браузер для защиты от автоматической блокировки.',
    'reset': 'Сбросить',
    'cancel': 'Отмена',
    'close': 'Закрыть',
    'save': 'Сохранить',
    'settingsSaved': 'Настройки сохранены! Попробуйте нажать Анализ снова.',
    'customDownloadTitle': 'Выбор качества загрузки',
    'tabMerge': 'Видео+Звук',
    'tabVideo': 'Только Видео',
    'tabAudio': 'Только Аудио',
    'selectVideoTrack': 'ВЫБЕРИТЕ ВИДЕОДОРОЖКУ:',
    'selectAudioTrack': 'ВЫБЕРИТЕ АУДИОДОРОЖКУ:',
    'selectVideoOnlyTrack': 'ВЫБЕРИТЕ ВИДЕОДОРОЖКУ (БЕЗ ЗВУКА):',
    'selectAudioOnlyTrack': 'ВЫБЕРИТЕ АУДИОДОРОЖКУ (КОНВЕРТИРУЕТСЯ В MP3):',
    'estSize': 'ОЦЕНКА РАЗМЕРА:',
    'downloadBtn': 'СКАЧАТЬ',
    'toastSaved': 'Готово. Успешно сохранено.',
    'toastFailed': 'Ошибка загрузки:',
    'toastPlaylistDone': 'Загрузка плейлиста завершена.',
    'toastNoVideo': 'Пожалуйста, вставьте ссылку на YouTube.',
    'toastNeedAnalyze': 'Проанализируйте ссылку перед загрузкой.',
    'toastSelectAtLeastOne': 'Пожалуйста, выберите хотя бы одно видео для загрузки.',
    'playlistTitle': 'Плейлист',
    'playlistAuthor': 'Автор:',
    'selectedVideosCount': 'Выбрано: {} из {}',
    'selectAll': 'Выбрать все',
    'deselectAll': 'Снять все',
    'duration': 'Длительность:',
    'audioMode': 'Аудио (MP3)',
    'bestMode': 'Лучшее (Merge)',
    'fastMode': 'Быстрое (720p)',
    'playlistAudio': 'Плейлист MP3',
    'playlistBest': 'Плейлист Best',
    'playlistFast': 'Плейлист Fast',
    'customDownload': 'Настроить и скачать',
    'terminalTitle': 'Логи терминала',
    'copyLogs': 'Скопировать логи',
    'logsCopied': 'Логи скопированы в буфер обмена',
    'online': 'ОНЛАЙН',
    'waitingLogs': '>> Ожидание команд...',
    'progressLabel': 'Статус:',
    'speed': 'Скорость:',
    'eta': 'Осталось:',
    'videoProgress': 'Видеопоток:',
    'audioProgress': 'Аудиопоток:',
    'mergeProgress': 'Обработка / Слияние:',
    'showDetailedProgress': 'Детальный прогресс-бар',
    'showDetailedProgressDesc': 'Показывать отдельные индикаторы для видео, аудио и этапа конвертации.',
    'tooltipUrlInput': 'Введите ссылку на YouTube видео или плейлист',
    'tooltipAnalyze': 'Сканировать ссылку для получения разрешений, названий и деталей',
    'tooltipSettings': 'Настроить cookies и User-Agent для обхода блокировок YouTube',
    'tooltipCustomDownload': 'Вручную выбрать разрешение видео и аудиопоток для слияния или скачать раздельно',
    'tooltipAudio': 'Скачать только аудиопоток и конвертировать в MP3',
    'tooltipBest': 'Скачать видео и аудио в максимальном качестве и объединить их через FFmpeg',
    'tooltipFast': 'Быстро скачать видео одним потоком в 720p со звуком',
    'tooltipPlaylistAudio': 'Скачать все отмеченные видео из плейлиста в формате MP3',
    'tooltipPlaylistBest': 'Скачать все отмеченные видео из плейлиста в лучшем качестве с объединением',
    'tooltipPlaylistFast': 'Скачать все отмеченные видео из плейлиста в 720p',
    'tooltipCancel': 'Немедленно прервать загрузку и удалить все временные файлы',
    'tooltipLogs': 'Нажмите, чтобы развернуть/свернуть подробный терминал логов',
    'tooltipLanguage': 'Переключить язык интерфейса (RU / EN)',
    'tooltipProgressMode': 'Переключить режим прогресс-бара (один общий или раздельные)',
    'cancelled': 'Отменено пользователем',
    'idle': 'Готов',
    'downloading': 'Загрузка...',
    'converting': 'Обработка / Слияние...',
    'exporting': 'Сохранение в галерею...',
    'done': 'Завершено!',
    'error': 'Ошибка',
    'advancedSettings': 'Настройки разработчика (Cookies и UA)',
    'devWarning': 'ВНИМАНИЕ: Настройки разработчика. Изменяйте эти параметры только в том случае, если понимаете, что делаете. Неверные настройки могут нарушить работу обхода.',
  }
};

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _hasAnalysis = false;
  bool _isAnalyzing = false;
  bool _isWorking = false;
  bool _isLogsExpanded = false;
  YoutubeAnalysis? _analysis;
  bool _showPlaylistMode = false;
  final Set<String> _selectedPlaylistVideoIds = {};

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    try {
      await Gal.requestAccess();
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String t(String key) {
    final lang = ref.watch(languageProvider);
    return _translations[lang]?[key] ?? key;
  }

  void _appendLog(String message) {
    ref.read(logsProvider.notifier).add(message);
  }

  /// Custom themed floating SnackBar notification
  void _showCustomSnackBar(String message, {bool isError = false, bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F111E),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError
                ? Colors.redAccent.withOpacity(0.5)
                : (isSuccess ? Colors.greenAccent.withOpacity(0.5) : Colors.deepPurpleAccent.withOpacity(0.5)),
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : (isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded),
              color: isError ? Colors.redAccent : (isSuccess ? Colors.greenAccent : Colors.deepPurpleAccent),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAnalyzePressed() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      _showCustomSnackBar(t('toastNoVideo'), isError: true);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _hasAnalysis = false;
      _analysis = null;
    });

    ref.read(logsProvider.notifier).clear();
    ref.read(progressProvider.notifier).set(0.0);
    ref.read(detailedProgressProvider.notifier).reset();
    ref.read(downloadStatsProvider.notifier).clear();

    final service = ref.read(youtubeServiceProvider);

    try {
      final analysis = await service.analyzeUrl(
        rawUrl,
        onLog: _appendLog,
      );

      setState(() {
        _analysis = analysis;
        _hasAnalysis = true;
        _showPlaylistMode = analysis.playlist != null;
        _selectedPlaylistVideoIds.clear();
        if (analysis.playlist != null) {
          _selectedPlaylistVideoIds.addAll(analysis.playlist!.videos.map((v) => v.id));
        }
      });
    } catch (e) {
      _appendLog('Analyze failed: $e');
      _showCustomSnackBar('${t('toastFailed')} $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _cancelOperation() {
    ref.read(youtubeServiceProvider).cancelDownload();
    setState(() {
      _isWorking = false;
    });
    ref.read(statusProvider.notifier).set('cancelled');
    _appendLog('--- Download cancelled by user ---');
  }

  Future<void> _startDownload(String mode) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      _showCustomSnackBar(t('toastNoVideo'), isError: true);
      return;
    }

    if (!_hasAnalysis) {
      _showCustomSnackBar(t('toastNeedAnalyze'), isError: true);
      return;
    }

    setState(() {
      _isWorking = true;
    });

    ref.read(progressProvider.notifier).set(0.0);
    ref.read(detailedProgressProvider.notifier).reset();
    ref.read(downloadStatsProvider.notifier).clear();
    _appendLog('--- Starting $mode download ---');

    final service = ref.read(youtubeServiceProvider);
    final progressNotifier = ref.read(progressProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);
    final statsNotifier = ref.read(downloadStatsProvider.notifier);
    final detailedNotifier = ref.read(detailedProgressProvider.notifier);

    try {
      await service.downloadVideo(
        rawUrl,
        mode: mode,
        onLog: _appendLog,
        onProgress: (value) => progressNotifier.set(value),
        onStatus: (status) => statusNotifier.set(status),
        onStats: (speed, eta) => statsNotifier.setStats(speed, eta),
        onDetailedProgress: ({videoProgress, audioProgress, currentAction}) {
          detailedNotifier.update(
            videoProgress: videoProgress,
            audioProgress: audioProgress,
            currentAction: currentAction,
          );
        },
      );

      if (mounted && !_isWorking) return; // cancelled

      _showCustomSnackBar(t('toastSaved'), isSuccess: true);
    } catch (e) {
      if (e is! CancellationException) {
        _appendLog('Download failed: $e');
        statusNotifier.set('error');
        _showCustomSnackBar('${t('toastFailed')} $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _startCustomDownload(int? videoTag, int? audioTag) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _isWorking = true;
    });

    ref.read(progressProvider.notifier).set(0.0);
    ref.read(detailedProgressProvider.notifier).reset();
    ref.read(downloadStatsProvider.notifier).clear();
    _appendLog('--- Starting custom download (Video: $videoTag, Audio: $audioTag) ---');

    final service = ref.read(youtubeServiceProvider);
    final progressNotifier = ref.read(progressProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);
    final statsNotifier = ref.read(downloadStatsProvider.notifier);
    final detailedNotifier = ref.read(detailedProgressProvider.notifier);

    try {
      await service.downloadCustomFormat(
        url: rawUrl,
        videoTag: videoTag,
        audioTag: audioTag,
        onLog: _appendLog,
        onProgress: (value) => progressNotifier.set(value),
        onStatus: (status) => statusNotifier.set(status),
        onStats: (speed, eta) => statsNotifier.setStats(speed, eta),
        onDetailedProgress: ({videoProgress, audioProgress, currentAction}) {
          detailedNotifier.update(
            videoProgress: videoProgress,
            audioProgress: audioProgress,
            currentAction: currentAction,
          );
        },
      );

      if (mounted && !_isWorking) return; // cancelled

      _showCustomSnackBar(t('toastSaved'), isSuccess: true);
    } catch (e) {
      if (e is! CancellationException) {
        _appendLog('Download failed: $e');
        statusNotifier.set('error');
        _showCustomSnackBar('${t('toastFailed')} $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _startPlaylistDownload(String mode) async {
    if (_analysis == null || _analysis!.playlist == null) return;
    final selectedIds = _analysis!.playlist!.videos
        .map((v) => v.id)
        .where((id) => _selectedPlaylistVideoIds.contains(id))
        .toList();

    if (selectedIds.isEmpty) {
      _showCustomSnackBar(t('toastSelectAtLeastOne'), isError: true);
      return;
    }

    setState(() {
      _isWorking = true;
    });

    ref.read(progressProvider.notifier).set(0.0);
    ref.read(detailedProgressProvider.notifier).reset();
    ref.read(downloadStatsProvider.notifier).clear();
    ref.read(playlistProgressProvider.notifier).reset();
    _appendLog('--- Starting playlist download (Mode: $mode, Videos: ${selectedIds.length}) ---');

    final service = ref.read(youtubeServiceProvider);
    final progressNotifier = ref.read(progressProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);
    final statsNotifier = ref.read(downloadStatsProvider.notifier);
    final detailedNotifier = ref.read(detailedProgressProvider.notifier);
    final playlistProgressNotifier = ref.read(playlistProgressProvider.notifier);

    try {
      await service.downloadPlaylist(
        videoIds: selectedIds,
        mode: mode,
        playlistTitle: _analysis!.playlist!.title,
        onLog: _appendLog,
        onProgress: (value) => progressNotifier.set(value),
        onStatus: (status) => statusNotifier.set(status),
        onStats: (speed, eta) => statsNotifier.setStats(speed, eta),
        onDetailedProgress: ({videoProgress, audioProgress, currentAction}) {
          detailedNotifier.update(
            videoProgress: videoProgress,
            audioProgress: audioProgress,
            currentAction: currentAction,
          );
        },
        onVideoProgress: (videoId, p) {
          playlistProgressNotifier.updateProgress(videoId, p);
        },
      );

      if (mounted && !_isWorking) return; // cancelled

      _showCustomSnackBar(t('toastPlaylistDone'), isSuccess: true);
    } catch (e) {
      if (e is! CancellationException) {
        _appendLog('Playlist download failed: $e');
        statusNotifier.set('error');
        _showCustomSnackBar('${t('toastFailed')} $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  void _showFormatSelectionSheet(BuildContext context) {
    if (_analysis == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: FormatSelectionSheet(
            analysis: _analysis!,
            onDownload: _startCustomDownload,
            t: t,
          ),
        );
      },
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final settingsService = ref.read(settingsServiceProvider);
    final settings = await settingsService.loadSettings();

    final cookiesController = TextEditingController(text: settings.cookies);
    final userAgentController = TextEditingController(text: settings.userAgent);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111E),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF2B2E4A), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.deepPurpleAccent, size: 24),
              const SizedBox(width: 10),
              Text(
                t('settings'),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detailed Progress Toggle inside settings (Reactive using Consumer!)
                Consumer(
                  builder: (context, ref, child) {
                    final isDetailedProgress = ref.watch(separateProgressBarsProvider);
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16192C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF262A4E)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: SwitchListTile(
                        value: isDetailedProgress,
                        activeColor: Colors.deepPurpleAccent,
                        title: Text(
                          t('showDetailedProgress'),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          t('showDetailedProgressDesc'),
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                        onChanged: (val) {
                          ref.read(separateProgressBarsProvider.notifier).set(val);
                        },
                      ),
                    );
                  },
                ),
                
                // Collapsible Advanced Settings
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      t('advancedSettings'),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                    leading: const Icon(Icons.security_rounded, color: Color(0xFFFBBF24), size: 18),
                    childrenPadding: const EdgeInsets.all(4),
                    children: [
                      // Yellow Warning banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFBBF24), // amber/yellow with opacity
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFBBF24), width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t('devWarning'),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFBBF24),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Cookies Input
                      Text(
                        t('cookies'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: cookiesController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF16192C),
                          hintText: t('cookiesHint'),
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF262A4E)),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () => cookiesController.clear(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('cookiesInfo'),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                      const SizedBox(height: 20),
                      
                      // User-Agent Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t('userAgent'),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              userAgentController.text = AppSettings.defaultSettings().userAgent;
                            },
                            child: Text(t('reset'), style: const TextStyle(fontSize: 12, color: Colors.deepPurpleAccent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: userAgentController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF16192C),
                          hintText: t('userAgentHint'),
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF262A4E)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('userAgentInfo'),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t('cancel'),
                style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () async {
                final newSettings = AppSettings(
                  userAgent: userAgentController.text.trim(),
                  cookies: cookiesController.text.trim(),
                );
                await settingsService.saveSettings(newSettings);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showCustomSnackBar(t('settingsSaved'), isSuccess: true);
                }
              },
              child: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _formatSpeed(double bytesPerSec) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytesPerSec >= mb) {
      return '${(bytesPerSec / mb).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSec >= kb) {
      return '${(bytesPerSec / kb).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(logsProvider);
    final progress = ref.watch(progressProvider);
    final status = ref.watch(statusProvider);
    final stats = ref.watch(downloadStatsProvider);
    final detailedProgress = ref.watch(detailedProgressProvider);
    final separateProgress = ref.watch(separateProgressBarsProvider);
    final activeLanguage = ref.watch(languageProvider);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080F),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.pinkAccent,
          surface: Color(0xFF0F111E),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0C15),
          elevation: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              t('title'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
          actions: [
            // Lang Switcher Button
            Tooltip(
              message: t('tooltipLanguage'),
              child: TextButton(
                onPressed: () => ref.read(languageProvider.notifier).toggle(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                child: Text(
                  activeLanguage == 'ru' ? 'RU' : 'EN',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurpleAccent),
                ),
              ),
            ),
            // Progress Mode Button
            Tooltip(
              message: t('tooltipProgressMode'),
              child: IconButton(
                icon: Icon(
                  separateProgress ? Icons.splitscreen_outlined : Icons.menu_open_rounded,
                  color: Colors.grey.shade300,
                ),
                onPressed: () {
                  ref.read(separateProgressBarsProvider.notifier).set(!separateProgress);
                },
              ),
            ),
            // Settings Button
            Tooltip(
              message: t('tooltipSettings'),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => _showSettingsDialog(context),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0C15),
                  Color(0xFF07080F),
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 850;
                
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Input, Action buttons, Progress bars
                      Expanded(
                        flex: 12,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUrlInputCard(),
                              const SizedBox(height: 20),
                              if (_isAnalyzing) _buildAnalyzingCard(),
                              if (_hasAnalysis && _analysis != null) ...[
                                _buildActionButtonsRow(),
                                const SizedBox(height: 20),
                              ],
                              _buildProgressAndStatsSection(progress, status, stats, detailedProgress, separateProgress),
                            ],
                          ),
                        ),
                      ),
                      // Divider
                      VerticalDivider(color: Colors.grey.shade900, width: 1.5),
                      // Right Column - Video Info, Playlist checklist, logs
                      Expanded(
                        flex: 11,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    if (_hasAnalysis && _analysis != null) ...[
                                      _buildAnalysisCard(),
                                      const SizedBox(height: 20),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            _buildConsoleSection(logs),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile view: single column scrollable
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUrlInputCard(),
                              const SizedBox(height: 16),
                              if (_isAnalyzing) _buildAnalyzingCard(),
                              if (_hasAnalysis && _analysis != null) ...[
                                _buildAnalysisCard(),
                                const SizedBox(height: 16),
                                _buildActionButtonsRow(),
                                const SizedBox(height: 16),
                              ],
                              _buildProgressAndStatsSection(progress, status, stats, detailedProgress, separateProgress),
                            ],
                          ),
                        ),
                      ),
                      _buildConsoleSection(logs),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1D2036)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: t('tooltipUrlInput'),
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF16192C),
                      hintText: t('urlHint'),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.link, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF262A4E)),
                      ),
                    ),
                    onSubmitted: (_) => _isAnalyzing || _isWorking ? null : _onAnalyzePressed(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: t('tooltipAnalyze'),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isAnalyzing || _isWorking ? null : _onAnalyzePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            t('analyze'),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111322),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222647)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('analyzing'),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final data = _analysis!;
    final hasPlaylist = data.playlist != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1D2036)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPlaylist) _buildPlaylistToggler(),
          if (_showPlaylistMode && data.playlist != null) ...[
            Text(
              data.playlist!.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${t('playlistTitle')} • ${t('playlistAuthor')} ${data.playlist!.author}',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            _buildPlaylistVideosList(data.playlist!),
          ] else ...[
            // Thumbnail image with rounded borders and shadow
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  data.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.movie_creation_rounded, size: 48, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (data.duration != null)
                  Text(
                    '${t('duration')} ${_formatDuration(data.duration!)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistToggler() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF16192C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262A4E)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showPlaylistMode = false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_showPlaylistMode ? Colors.deepPurpleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t('tabVideo'),
                  style: GoogleFonts.outfit(
                    color: !_showPlaylistMode ? Colors.white : Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showPlaylistMode = true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _showPlaylistMode ? Colors.deepPurpleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t('playlistTitle'),
                  style: GoogleFonts.outfit(
                    color: _showPlaylistMode ? Colors.white : Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistVideosList(YoutubePlaylistAnalysis playlist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('selectedVideosCount')
                  .replaceAll('{}', _selectedPlaylistVideoIds.length.toString())
                  .replaceAll('{}', playlist.videos.length.toString()),
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _isWorking
                  ? null
                  : () {
                      setState(() {
                        if (_selectedPlaylistVideoIds.length == playlist.videos.length) {
                          _selectedPlaylistVideoIds.clear();
                        } else {
                          _selectedPlaylistVideoIds.clear();
                          _selectedPlaylistVideoIds.addAll(playlist.videos.map((v) => v.id));
                        }
                      });
                    },
              child: Text(
                _selectedPlaylistVideoIds.length == playlist.videos.length
                    ? t('deselectAll')
                    : t('selectAll'),
                style: const TextStyle(fontSize: 12, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2139)),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlist.videos.length,
            itemBuilder: (context, idx) {
              final video = playlist.videos[idx];
              final isSelected = _selectedPlaylistVideoIds.contains(video.id);
              final playlistProgress = ref.watch(playlistProgressProvider);
              final progress = playlistProgress[video.id];

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF15192C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.deepPurpleAccent,
                      title: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${video.author}${video.duration != null ? " • ${_formatDuration(video.duration!)}" : ""}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                      onChanged: _isWorking
                          ? null
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPlaylistVideoIds.add(video.id);
                                } else {
                                  _selectedPlaylistVideoIds.remove(video.id);
                                }
                              });
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    if (progress != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFF1D2038),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.deepPurpleAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsRow() {
    if (_showPlaylistMode && _analysis?.playlist != null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: t('tooltipPlaylistAudio'),
                    child: _ActionButton(
                      label: t('playlistAudio'),
                      icon: Icons.music_note_rounded,
                      color: const Color(0xFF16192C),
                      onTap: _isWorking
                          ? null
                          : () => _startPlaylistDownload(YoutubeService.modeAudio),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: t('tooltipPlaylistBest'),
                    child: _ActionButton(
                      label: t('playlistBest'),
                      icon: Icons.high_quality_rounded,
                      color: const Color(0xFF16192C),
                      onTap: _isWorking
                          ? null
                          : () => _startPlaylistDownload(YoutubeService.modeMerge),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Tooltip(
                message: t('tooltipPlaylistFast'),
                child: _ActionButton(
                  label: t('playlistFast'),
                  icon: Icons.flash_on_rounded,
                  color: const Color(0xFF16192C),
                  onTap: _isWorking
                      ? null
                      : () => _startPlaylistDownload(YoutubeService.modeMuxed),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Tooltip(
              message: t('tooltipCustomDownload'),
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : () => _showFormatSelectionSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.settings_suggest_rounded, size: 22),
                label: Text(
                  t('customDownload'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: t('tooltipAudio'),
                  child: _ActionButton(
                    label: t('audioMode'),
                    icon: Icons.music_note_rounded,
                    color: const Color(0xFF16192C),
                    onTap: _isWorking ? null : () => _startDownload(YoutubeService.modeAudio),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: t('tooltipBest'),
                  child: _ActionButton(
                    label: t('bestMode'),
                    icon: Icons.high_quality_rounded,
                    color: const Color(0xFF16192C),
                    onTap: _isWorking ? null : () => _startDownload(YoutubeService.modeMerge),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: t('tooltipFast'),
                  child: _ActionButton(
                    label: t('fastMode'),
                    icon: Icons.flash_on_rounded,
                    color: const Color(0xFF16192C),
                    onTap: _isWorking ? null : () => _startDownload(YoutubeService.modeMuxed),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressAndStatsSection(
    double progress,
    String status,
    DownloadStats? stats,
    DetailedProgressState detailedProgress,
    bool separateProgress,
  ) {
    if (!_isWorking && status == 'idle') {
      return const SizedBox.shrink();
    }

    final percent = progress.clamp(0.0, 1.0);
    final statusLabel = switch (status) {
      'downloading' => t('downloading'),
      'converting' => t('converting'),
      'exporting' => t('exporting'),
      'done' => t('done'),
      'error' => t('error'),
      'cancelled' => t('cancelled'),
      _ => t('idle'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1D2036)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cancel button at the top of progress card
          if (_isWorking)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Tooltip(
                  message: t('tooltipCancel'),
                  child: ElevatedButton.icon(
                    onPressed: _cancelOperation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: Text(t('cancel'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ),
          
          // Stats Row (Speed & ETA)
          if (_isWorking && stats != null) ...[
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('${t('speed')} ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(_formatSpeed(stats.speedBytesPerSec), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('${t('eta')} ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(stats.eta, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          if (separateProgress && (status == 'downloading' || status == 'converting' || status == 'exporting'))
            _buildDetailedProgressBars(detailedProgress)
          else ...[
            // Unified progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent.isNaN ? 0.0 : percent,
                minHeight: 10,
                backgroundColor: const Color(0xFF16192C),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusLabel,
                  style: GoogleFonts.outfit(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    color: Colors.deepPurpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedProgressBars(DetailedProgressState state) {
    final isDownloadingVideo = state.currentAction == 'downloading_video';
    final isDownloadingAudio = state.currentAction == 'downloading_audio';
    final isConverting = state.currentAction == 'converting';
    final isExporting = state.currentAction == 'exporting';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video Progress
        _buildDetailedProgressItem(
          label: t('videoProgress'),
          progress: state.videoProgress,
          isActive: isDownloadingVideo,
          isCompleted: !isDownloadingVideo && (isDownloadingAudio || isConverting || isExporting),
        ),
        const SizedBox(height: 10),
        // Audio Progress
        _buildDetailedProgressItem(
          label: t('audioProgress'),
          progress: state.audioProgress,
          isActive: isDownloadingAudio,
          isCompleted: !isDownloadingAudio && (isConverting || isExporting),
        ),
        const SizedBox(height: 10),
        // Merge/Processing Progress
        _buildDetailedProgressItem(
          label: t('mergeProgress'),
          progress: (isConverting || isExporting) ? 1.0 : 0.0,
          isActive: isConverting || isExporting,
          isCompleted: isExporting && !isConverting,
          isIndeterminate: isConverting,
        ),
      ],
    );
  }

  Widget _buildDetailedProgressItem({
    required String label,
    required double progress,
    required bool isActive,
    required bool isCompleted,
    bool isIndeterminate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade500,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (isCompleted)
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 15)
            else if (isActive)
              Text(
                isIndeterminate ? '...' : '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              )
            else
              const Text(
                '0%',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: isCompleted ? 1.0 : (isIndeterminate && isActive ? null : (isActive ? progress : 0.0)),
            backgroundColor: const Color(0xFF16192C),
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted
                  ? Colors.greenAccent
                  : (isActive ? Colors.deepPurpleAccent : Colors.grey.shade800),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleSection(List<String> logs) {
    final lastLine = logs.isNotEmpty ? logs.last : '';
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF05060A),
        border: Border(top: BorderSide(color: Color(0xFF1E2139), width: 1.5)),
      ),
      child: Column(
        children: [
          // Header Bar that toggles expansion
          InkWell(
            onTap: () => setState(() => _isLogsExpanded = !_isLogsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t('terminalTitle'),
                    style: GoogleFonts.outfit(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Last log line preview when collapsed
                  if (!_isLogsExpanded)
                    Expanded(
                      child: Text(
                        lastLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  Icon(
                    _isLogsExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded console content
          if (_isLogsExpanded)
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Action buttons for logs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          if (logs.isNotEmpty) {
                            final text = logs.map((l) => '> $l').join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                            _showCustomSnackBar(t('logsCopied'), isSuccess: true);
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.greenAccent),
                        label: Text(t('copyLogs'), style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => ref.read(logsProvider.notifier).clear(),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 14, color: Colors.redAccent),
                        label: Text(t('reset'), style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Terminal View list
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1A1D36)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: SelectionArea(
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.greenAccent,
                          ),
                          child: logs.isEmpty
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    t('waitingLogs'),
                                    style: TextStyle(
                                      color: Colors.greenAccent.withOpacity(0.5),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) {
                                    return Text('> ${logs[index]}');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? const Color(0xFF131524) : color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDisabled ? Colors.transparent : const Color(0xFF262A4E),
              width: 1.2,
            ),
          ),
          elevation: isDisabled ? 0 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isDisabled ? Colors.grey : Colors.deepPurpleAccent),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDisabled ? Colors.grey : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormatSelectionSheet extends StatefulWidget {
  final YoutubeAnalysis analysis;
  final Function(int? videoTag, int? audioTag) onDownload;
  final String Function(String) t;

  const FormatSelectionSheet({
    super.key,
    required this.analysis,
    required this.onDownload,
    required this.t,
  });

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late List<YoutubeStreamFormat> _videoFormats;
  late List<YoutubeStreamFormat> _audioFormats;

  int? _selectedMergeVideoTag;
  int? _selectedMergeAudioTag;
  int? _selectedOnlyVideoTag;
  int? _selectedOnlyAudioTag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _videoFormats = widget.analysis.formats
        .where((f) => f.type == 'video_only' || f.type == 'muxed')
        .toList()
      ..sort((a, b) => b.bitrateKbps.compareTo(a.bitrateKbps));

    _audioFormats = widget.analysis.formats
        .where((f) => f.type == 'audio_only')
        .toList()
      ..sort((a, b) => b.bitrateKbps.compareTo(a.bitrateKbps));

    _selectedMergeVideoTag = _videoFormats.firstOrNull?.tag;
    _selectedMergeAudioTag = _audioFormats.firstOrNull?.tag;
    _selectedOnlyVideoTag = _videoFormats.firstOrNull?.tag;
    _selectedOnlyAudioTag = _audioFormats.firstOrNull?.tag;

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  YoutubeStreamFormat? _findFormat(List<YoutubeStreamFormat> list, int? tag) {
    if (tag == null) return null;
    for (final f in list) {
      if (f.tag == tag) return f;
    }
    return null;
  }

  double _getSelectedSizeMb() {
    if (_tabController.index == 0) {
      final vSize = _findFormat(_videoFormats, _selectedMergeVideoTag)?.sizeMb ?? 0.0;
      final aSize = _findFormat(_audioFormats, _selectedMergeAudioTag)?.sizeMb ?? 0.0;
      return vSize + aSize;
    } else if (_tabController.index == 1) {
      return _findFormat(_videoFormats, _selectedOnlyVideoTag)?.sizeMb ?? 0.0;
    } else {
      return _findFormat(_audioFormats, _selectedOnlyAudioTag)?.sizeMb ?? 0.0;
    }
  }

  void _onDownloadPressed() {
    Navigator.pop(context);
    if (_tabController.index == 0) {
      widget.onDownload(_selectedMergeVideoTag, _selectedMergeAudioTag);
    } else if (_tabController.index == 1) {
      widget.onDownload(_selectedOnlyVideoTag, null);
    } else {
      widget.onDownload(null, _selectedOnlyAudioTag);
    }
  }

  Widget _buildFormatTile({
    required YoutubeStreamFormat format,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E1738) : const Color(0xFF111322),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? Colors.deepPurpleAccent : const Color(0xFF222647),
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(
          format.type == 'audio_only'
              ? Icons.audiotrack_rounded
              : Icons.video_collection_rounded,
          color: isSelected ? Colors.deepPurpleAccent : Colors.grey,
        ),
        title: Text(
          '${format.qualityLabel} (${format.container.toUpperCase()})',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          'Codec: ${format.codec} | Bitrate: ${format.bitrateKbps} kbps',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${format.sizeMb.toStringAsFixed(1)} MB',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade300,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? Colors.deepPurpleAccent : Colors.grey.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final size = _getSelectedSizeMb();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0C15),
        border: Border(
          top: BorderSide(color: Color(0xFF1E2139), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.t('estSize'),
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${size.toStringAsFixed(1)} MB',
                  style: GoogleFonts.outfit(
                    color: Colors.greenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _onDownloadPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    widget.t('downloadBtn'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F111E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.t('customDownloadTitle'),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.video_library_rounded, size: 20),
                text: widget.t('tabMerge'),
              ),
              Tab(
                icon: const Icon(Icons.video_collection_rounded, size: 20),
                text: widget.t('tabVideo'),
              ),
              Tab(
                icon: const Icon(Icons.audiotrack_rounded, size: 20),
                text: widget.t('tabAudio'),
              ),
            ],
            indicatorColor: Colors.deepPurpleAccent,
            labelColor: Colors.deepPurpleAccent,
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Video + Audio (Merge)
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _videoFormats.length + _audioFormats.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          widget.t('selectVideoTrack'),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      );
                    }
                    if (index <= _videoFormats.length) {
                      final f = _videoFormats[index - 1];
                      return _buildFormatTile(
                        format: f,
                        isSelected: _selectedMergeVideoTag == f.tag,
                        onTap: () => setState(() => _selectedMergeVideoTag = f.tag),
                      );
                    }
                    if (index == _videoFormats.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 12),
                        child: Text(
                          widget.t('selectAudioTrack'),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      );
                    }
                    final f = _audioFormats[index - _videoFormats.length - 2];
                    return _buildFormatTile(
                      format: f,
                      isSelected: _selectedMergeAudioTag == f.tag,
                      onTap: () => setState(() => _selectedMergeAudioTag = f.tag),
                    );
                  },
                ),
                // Tab 2: Only Video
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _videoFormats.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          widget.t('selectVideoOnlyTrack'),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      );
                    }
                    final f = _videoFormats[index - 1];
                    return _buildFormatTile(
                      format: f,
                      isSelected: _selectedOnlyVideoTag == f.tag,
                      onTap: () => setState(() => _selectedOnlyVideoTag = f.tag),
                    );
                  },
                ),
                // Tab 3: Only Audio
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _audioFormats.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          widget.t('selectAudioOnlyTrack'),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      );
                    }
                    final f = _audioFormats[index - 1];
                    return _buildFormatTile(
                      format: f,
                      isSelected: _selectedOnlyAudioTag == f.tag,
                      onTap: () => setState(() => _selectedOnlyAudioTag = f.tag),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }
}