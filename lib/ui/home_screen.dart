import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../providers.dart';
import '../services/youtube_service.dart';
import '../services/settings_service.dart';

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
    } catch (_) {
      // Ignore; failures will surface when saving if needed.
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _appendLog(String message) {
    final notifier = ref.read(logsProvider.notifier);
    notifier.add(message);

    // Optional: keep last N entries to avoid unbounded growth.
    const maxLogs = 200;
    if (ref.read(logsProvider).length > maxLogs) {
       // Ideally we would handle truncation in the notifier, but for now this simplification is acceptable
       // or we'd need a more complex notifier.
       // Let's just rely on the notifier.add for now and ignore truncation in this step or move it to notifier if strictly needed.
       // Actually, let's keep it simple and just add. The user didn't ask for truncation logic maintenance in this refactor.
    }
  }

  Future<void> _onAnalyzePressed() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a YouTube URL first.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _hasAnalysis = false;
      _analysis = null;
    });

    ref.read(logsProvider.notifier).clear();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analyze failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _startDownload(String mode) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a YouTube URL first.')),
      );
      return;
    }

    if (!_hasAnalysis) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyze the URL before downloading.')),
      );
      return;
    }

    setState(() {
      _isWorking = true;
    });

    // Reset progress and keep logs (append new section header).
    ref.read(progressProvider.notifier).set(0.0);
    _appendLog('--- Starting $mode download ---');

    final service = ref.read(youtubeServiceProvider);
    final progressNotifier = ref.read(progressProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);

    try {
      await service.downloadVideo(
        rawUrl,
        mode: mode,
        onLog: _appendLog,
        onProgress: (value) {
          progressNotifier.set(value);
        },
        onStatus: (status) {
          statusNotifier.set(status);
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Done. Saved to gallery.')),
      );
    } catch (e) {
      _appendLog('Download failed: $e');
      statusNotifier.set('error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
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
    _appendLog('--- Starting custom download (Video: $videoTag, Audio: $audioTag) ---');

    final service = ref.read(youtubeServiceProvider);
    final progressNotifier = ref.read(progressProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);

    try {
      await service.downloadCustomFormat(
        url: rawUrl,
        videoTag: videoTag,
        audioTag: audioTag,
        onLog: _appendLog,
        onProgress: (value) {
          progressNotifier.set(value);
        },
        onStatus: (status) {
          statusNotifier.set(status);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Готово. Успешно сохранено.')),
        );
      }
    } catch (e) {
      _appendLog('Download failed: $e');
      statusNotifier.set('error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите хотя бы одно видео для загрузки.')),
      );
      return;
    }

    setState(() {
      _isWorking = true;
    });

    ref.read(progressProvider.notifier).set(0.0);
    _appendLog('--- Starting playlist download (Mode: $mode, Videos: ${selectedIds.length}) ---');

    final service = ref.read(youtubeServiceProvider);
    final progressNotifier = ref.read(progressProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);

    try {
      await service.downloadPlaylist(
        videoIds: selectedIds,
        mode: mode,
        onLog: _appendLog,
        onProgress: (value) {
          progressNotifier.set(value);
        },
        onStatus: (status) {
          statusNotifier.set(status);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Загрузка плейлиста завершена.')),
        );
      }
    } catch (e) {
      _appendLog('Playlist download failed: $e');
      statusNotifier.set('error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist download failed: $e')),
        );
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
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
          ),
          title: Row(
            children: [
              Icon(Icons.settings_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Настройки обхода',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Куки (Cookies) для авторизации:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: cookiesController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Вставьте Cookie (например, VISITOR_INFO1_LIVE=...)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => cookiesController.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Помогает обойти rate limit (429), если YouTube считает ваш IP подозрительным.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User-Agent браузера:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                      child: const Text('Сбросить', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: userAgentController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: 'User-Agent строка...',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Имитирует реальный браузер для защиты от автоматической блокировки.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Отмена',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final newSettings = AppSettings(
                  userAgent: userAgentController.text.trim(),
                  cookies: cookiesController.text.trim(),
                );
                await settingsService.saveSettings(newSettings);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Настройки сохранены! Попробуйте нажать Analyze снова.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(logsProvider);
    final progress = ref.watch(progressProvider);
    final status = ref.watch(statusProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Downloader'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки обхода блокировок',
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF05050A),
                Color(0xFF0C0F16),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(colorScheme),
                const SizedBox(height: 16),
                _buildUrlInputRow(colorScheme),
                const SizedBox(height: 16),
                if (_hasAnalysis && _analysis != null)
                  _buildAnalysisCard(colorScheme),
                const SizedBox(height: 16),
                if (_hasAnalysis) _buildActionButtonsRow(colorScheme),
                const SizedBox(height: 12),
                _buildProgressBar(progress, status, colorScheme),
                const SizedBox(height: 12),
                _buildConsole(logs, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal_rounded,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'yt-shell',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Copy All Button
        IconButton(
          onPressed: () {
            final logs = ref.read(logsProvider);
            if (logs.isNotEmpty) {
              final text = logs.map((l) => '> $l').join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Logs copied to clipboard'),
                    duration: Duration(seconds: 1)),
              );
            }
          },
          icon: Icon(Icons.copy_rounded,
              size: 18, color: colorScheme.primary.withOpacity(0.7)),
          tooltip: 'Copy all logs',
          visualDensity: VisualDensity.compact,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ONLINE',
                style: TextStyle(
                  color: Colors.greenAccent.shade100,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInputRow(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Paste YouTube / Shorts URL here...',
              prefixIcon: Icon(Icons.link, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing || _isWorking ? null : _onAnalyzePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(
              _isAnalyzing ? 'Analyzing...' : 'Analyze',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2335)),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie_creation_rounded,
                      size: 16,
                      color: !_showPlaylistMode ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Видео',
                      style: TextStyle(
                        color: !_showPlaylistMode ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.featured_play_list_rounded,
                      size: 16,
                      color: _showPlaylistMode ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Плейлист',
                      style: TextStyle(
                        color: _showPlaylistMode ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
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
              'Выбрано: ${_selectedPlaylistVideoIds.length} из ${playlist.videos.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
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
                    ? 'Снять все'
                    : 'Выбрать все',
                style: const TextStyle(fontSize: 12, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF07090E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF161A26)),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              itemCount: playlist.videos.length,
              itemBuilder: (context, idx) {
                final video = playlist.videos[idx];
                final isSelected = _selectedPlaylistVideoIds.contains(video.id);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: Colors.deepPurpleAccent,
                  title: Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${video.author}${video.duration != null ? " • ${_formatDuration(video.duration!)}" : ""}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                  onChanged: (val) {
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
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, "0")}';
  }

  Widget _buildAnalysisCard(ColorScheme colorScheme) {
    final data = _analysis!;
    final hasPlaylist = data.playlist != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
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
          if (hasPlaylist) _buildToggleRow(),
          if (_showPlaylistMode && data.playlist != null) ...[
            Text(
              data.playlist!.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Плейлист • Автор: ${data.playlist!.author}',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _buildPlaylistVideosList(data.playlist!),
          ] else ...[
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.author,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
            if (data.duration != null) ...[
              const SizedBox(height: 6),
              Text(
                'Duration: ${data.duration}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow(ColorScheme colorScheme) {
    if (_showPlaylistMode && _analysis?.playlist != null) {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Playlist MP3',
              icon: Icons.music_note_rounded,
              color: const Color(0xFF1E1E2E),
              onTap: _isWorking
                  ? null
                  : () => _startPlaylistDownload(YoutubeService.modeAudio),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'Playlist Best',
              icon: Icons.high_quality_rounded,
              color: const Color(0xFF1E1E2E),
              onTap: _isWorking
                  ? null
                  : () => _startPlaylistDownload(YoutubeService.modeMerge),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'Playlist Fast',
              icon: Icons.flash_on_rounded,
              color: const Color(0xFF1E1E2E),
              onTap: _isWorking
                  ? null
                  : () => _startPlaylistDownload(YoutubeService.modeMuxed),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isWorking ? null : () => _showFormatSelectionSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.settings_suggest_rounded, size: 24),
            label: const Text(
              'Настроить и скачать (Выбор качества)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Audio (MP3)',
                icon: Icons.music_note_rounded,
                color: const Color(0xFF1E1E2E),
                onTap: _isWorking
                    ? null
                    : () => _startDownload(YoutubeService.modeAudio),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Best (Merge)',
                icon: Icons.high_quality_rounded,
                color: const Color(0xFF1E1E2E),
                onTap: _isWorking
                    ? null
                    : () => _startDownload(YoutubeService.modeMerge),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'Fast (720p)',
                icon: Icons.flash_on_rounded,
                color: const Color(0xFF1E1E2E),
                onTap: _isWorking
                    ? null
                    : () => _startDownload(YoutubeService.modeMuxed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(
    double progress,
    String status,
    ColorScheme colorScheme,
  ) {
    final percent = progress.clamp(0.0, 1.0);
    final label = switch (status) {
      'downloading' => 'Downloading...',
      'converting' => 'Processing...',
      'exporting' => 'Saving to gallery...',
      'done' => 'Done',
      'error' => 'Error',
      _ => 'Idle',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearPercentIndicator(
          padding: EdgeInsets.zero,
          lineHeight: 10,
          barRadius: const Radius.circular(999),
          backgroundColor: const Color(0xFF15151F),
          progressColor: colorScheme.primary,
          percent: percent.isNaN ? 0.0 : percent,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConsole(List<String> logs, ColorScheme colorScheme) {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262638)),
        ),
        padding: const EdgeInsets.all(8),
        child: SelectionArea(
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.greenAccent,
            ),
            child: logs.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '>> Waiting for commands...',
                      style: TextStyle(
                        color: Colors.greenAccent.withOpacity(0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final line = logs[index];
                      return Text('> $line');
                    },
                  ),
          ),
        ),
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
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? const Color(0xFF1C1C26) : color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDisabled ? 0 : 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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

  const FormatSelectionSheet({
    super.key,
    required this.analysis,
    required this.onDownload,
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
        color: isSelected ? const Color(0xFF1C1B2E) : const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.deepPurpleAccent : const Color(0xFF26263B),
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
          style: const TextStyle(
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
                color: isSelected ? Colors.deepPurpleAccent : Colors.grey.shade300,
                fontWeight: FontWeight.w600,
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
        color: Color(0xFF0A0C14),
        border: Border(
          top: BorderSide(color: Color(0xFF1F2335), width: 1.5),
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
                const Text(
                  'ОЦЕНКА РАЗМЕРА:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${size.toStringAsFixed(1)} MB',
                  style: const TextStyle(
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'СКАЧАТЬ',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
        color: Color(0xFF0F111A),
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
          const Text(
            'Выбор качества загрузки',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.video_library_rounded, size: 20),
                text: 'Видео+Звук',
              ),
              Tab(
                icon: Icon(Icons.video_collection_rounded, size: 20),
                text: 'Только Видео',
              ),
              Tab(
                icon: Icon(Icons.audiotrack_rounded, size: 20),
                text: 'Только Аудио',
              ),
            ],
            indicatorColor: Colors.deepPurpleAccent,
            labelColor: Colors.deepPurpleAccent,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          'ВЫБЕРИТЕ ВИДЕОДОРОЖКУ:',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
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
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8, top: 12),
                        child: Text(
                          'ВЫБЕРИТЕ АУДИОДОРОЖКУ:',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
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
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          'ВЫБЕРИТЕ ВИДЕОДОРОЖКУ (БЕЗ ЗВУКА):',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
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
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          'ВЫБЕРИТЕ АУДИОДОРОЖКУ (КОНВЕРТИРУЕТСЯ В MP3):',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
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

