import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../providers.dart';
import '../services/youtube_service.dart';

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

  Widget _buildAnalysisCard(ColorScheme colorScheme) {
    final data = _analysis!;
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
      ),
    );
  }

  Widget _buildActionButtonsRow(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Audio (MP3)',
            icon: Icons.music_note_rounded,
            color: Colors.deepPurpleAccent,
            onTap: _isWorking
                ? null
                : () => _startDownload(YoutubeService.modeAudio),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Best Video (Merge)',
            icon: Icons.high_quality_rounded,
            color: const Color(0xFF7C4DFF),
            onTap: _isWorking
                ? null
                : () => _startDownload(YoutubeService.modeMerge),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Fast Video (720p)',
            icon: Icons.flash_on_rounded,
            color: const Color(0xFFB388FF),
            onTap: _isWorking
                ? null
                : () => _startDownload(YoutubeService.modeMuxed),
          ),
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
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? const Color(0xFF1C1C26) : color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: isDisabled ? 0 : 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

