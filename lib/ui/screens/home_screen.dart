import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../services/youtube_service.dart';

final youtubeServiceProvider = Provider((ref) => YoutubeService());
final logProvider = StateNotifierProvider<LogNotifier, List<String>>((ref) => LogNotifier());

class LogNotifier extends StateNotifier<List<String>> {
  LogNotifier() : super([]);

  void addLog(String log) {
    state = [...state, log];
  }

  void clearLogs() {
    state = [];
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _urlController = TextEditingController();
  String? _savePath;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(logProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('YouTube Downloader', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickSavePath,
                  child: const Text('Select Save Folder'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(_savePath ?? 'No folder selected', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _analyzeUrl,
              child: const Text('Analyze'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Text(logs[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSavePath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _savePath = result;
      });
    }
  }

  Future<void> _analyzeUrl() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }

    if (_savePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a save folder')));
      return;
    }

    ref.read(logProvider.notifier).addLog('Analyzing URL...');
    try {
      final video = await ref.read(youtubeServiceProvider).getVideoInfo(_urlController.text);
      final manifest = await ref.read(youtubeServiceProvider).getStreamManifest(_urlController.text);
      ref.read(logProvider.notifier).addLog('Analysis complete: ${video.title}');
      _showDownloadOptions(video, manifest);
    } catch (e) {
      ref.read(logProvider.notifier).addLog('Error analyzing URL: $e');
    }
  }

  void _showDownloadOptions(Video video, StreamManifest manifest) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(video.title, style: GoogleFonts.roboto(fontSize: 18)),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Audio Only'),
                  Tab(text: 'Video Only'),
                  Tab(text: 'Merge'),
                  Tab(text: 'Muxed'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildAudioList(manifest.audioOnly, video.title),
                _buildVideoList(manifest.videoOnly, video.title),
                _buildMergeUI(manifest.videoOnly, manifest.audioOnly, video.title),
                _buildMuxedList(manifest.muxed, video.title),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioList(List<AudioOnlyStreamInfo> streams, String videoTitle) {
    return ListView.builder(
      itemCount: streams.length,
      itemBuilder: (context, index) {
        final stream = streams[index];
        return ListTile(
          title: Text('${stream.audioCodec} - ${stream.bitrate}'),
          subtitle: Text('${stream.size.totalMegaBytes.toStringAsFixed(2)} MB'),
          onTap: () async {
            final savePath = '$_savePath/$videoTitle.mp3';
            ref.read(logProvider.notifier).addLog('Downloading audio...');
            await ref.read(youtubeServiceProvider).downloadAudio(stream as MuxedStreamInfo, savePath);
            ref.read(logProvider.notifier).addLog('Audio downloaded to $savePath');
          },
        );
      },
    );
  }

  Widget _buildVideoList(List<VideoOnlyStreamInfo> streams, String videoTitle) {
    return ListView.builder(
      itemCount: streams.length,
      itemBuilder: (context, index) {
        final stream = streams[index];
        return ListTile(
          title: Text('${stream.videoResolution} - ${stream.videoCodec}'),
          subtitle: Text('${stream.size.totalMegaBytes.toStringAsFixed(2)} MB'),
          onTap: () async {
            final savePath = '$_savePath/$videoTitle.mp4';
            ref.read(logProvider.notifier).addLog('Downloading video...');
            await ref.read(youtubeServiceProvider).downloadVideo(stream as MuxedStreamInfo, savePath);
            ref.read(logProvider.notifier).addLog('Video downloaded to $savePath');
          },
        );
      },
    );
  }

  Widget _buildMuxedList(List<MuxedStreamInfo> streams, String videoTitle) {
    return ListView.builder(
      itemCount: streams.length,
      itemBuilder: (context, index) {
        final stream = streams[index];
        return ListTile(
          title: Text('${stream.videoResolution} - ${stream.videoCodec}'),
          subtitle: Text('${stream.size.totalMegaBytes.toStringAsFixed(2)} MB'),
          onTap: () async {
            final savePath = '$_savePath/$videoTitle.mp4';
            ref.read(logProvider.notifier).addLog('Downloading muxed stream...');
            await ref.read(youtubeServiceProvider).downloadVideo(stream, savePath);
            ref.read(logProvider.notifier).addLog('Muxed stream downloaded to $savePath');
          },
        );
      },
    );
  }

  Widget _buildMergeUI(List<VideoOnlyStreamInfo> videoStreams, List<AudioOnlyStreamInfo> audioStreams, String videoTitle) {
    VideoStreamInfo? selectedVideo;
    AudioOnlyStreamInfo? selectedAudio;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            DropdownButton<VideoStreamInfo>(
              hint: const Text('Select Video Stream'),
              value: selectedVideo,
              onChanged: (value) {
                setState(() {
                  selectedVideo = value;
                });
              },
              items: videoStreams.map((stream) {
                return DropdownMenuItem(
                  value: stream,
                  child: Text('${stream.videoResolution} - ${stream.videoCodec}'),
                );
              }).toList(),
            ),
            DropdownButton<AudioOnlyStreamInfo>(
              hint: const Text('Select Audio Stream'),
              value: selectedAudio,
              onChanged: (value) {
                setState(() {
                  selectedAudio = value;
                });
              },
              items: audioStreams.map((stream) {
                return DropdownMenuItem(
                  value: stream,
                  child: Text('${stream.audioCodec} - ${stream.bitrate}'),
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: (selectedVideo != null && selectedAudio != null)
                  ? () async {
                      final savePath = '$_savePath/$videoTitle.mp4';
                      ref.read(logProvider.notifier).addLog('Merging streams...');
                      await ref.read(youtubeServiceProvider).mergeStreams(selectedVideo!, selectedAudio!, savePath);
                      ref.read(logProvider.notifier).addLog('Streams merged and saved to $savePath');
                    }
                  : null,
              child: const Text('Merge and Download'),
            ),
          ],
        );
      },
    );
  }
}
