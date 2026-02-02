import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Simple analysis result for a YouTube URL.
class YoutubeAnalysis {
  YoutubeAnalysis({
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
  });

  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;
}

/// Core YouTube download / processing logic.
///
/// This service:
/// - Parses any YouTube URL (including Shorts) via [VideoId].
/// - ALWAYS downloads into the platform temporary directory.
/// - Uses FFmpeg for audio conversion / merging INSIDE the temp directory.
/// - Exports the final file to the user's gallery via [Gal.putVideo].
class YoutubeService {
  YoutubeService();

  /// Supported modes.
  static const String modeAudio = 'audio';
  static const String modeMerge = 'merge';
  static const String modeMuxed = 'muxed';

  /// Analyze a YouTube [url] and return basic metadata.
  ///
  /// This is lightweight and intended to power the UI "Analyze" step
  /// (enabling buttons, showing title, etc.).
  Future<YoutubeAnalysis> analyzeUrl(
    String url, {
    required void Function(String) onLog,
  }) async {
    final yt = YoutubeExplode();

    try {
      onLog('Analyzing URL...');
      final videoId = VideoId(url.trim());
      final video = await yt.videos.get(videoId);

      onLog('Title: ${video.title}');
      onLog('Channel: ${video.author}');
      if (video.duration != null) {
        onLog('Duration: ${video.duration}');
      }

      final thumbnailUrl =
          video.thumbnails.highResUrl ?? video.thumbnails.standardResUrl;

      return YoutubeAnalysis(
        title: video.title,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: thumbnailUrl,
      );
    } finally {
      yt.close();
    }
  }

  /// Download a YouTube video in the given [mode].
  ///
  /// - [url] can be any YouTube URL (short, share link, etc.).
  /// - [mode] must be one of: `audio`, `merge`, `muxed`.
  /// - [onLog] is used for real-time logging to the UI.
  /// - [onProgress] is optional and reports 0.0–1.0 during network downloads.
  /// - [onStatus] is optional and can be used to drive a status provider
  ///   (`idle`, `downloading`, `converting`, `exporting`, `done`, `error`).
  Future<void> downloadVideo(
    String url, {
    required String mode,
    required void Function(String) onLog,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final yt = YoutubeExplode();

    void log(String message) {
      onLog(message);
    }

    void setStatus(String status) {
      if (onStatus != null) {
        onStatus(status);
      }
    }

    try {
      log('Parsing URL...');
      // CRITICAL: always use VideoId(url.trim()) so Shorts / dirty URLs work.
      final videoId = VideoId(url.trim());

      setStatus('downloading');

      log('Fetching video details...');
      final video = await yt.videos.get(videoId);
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      final tempDir = await getTemporaryDirectory();
      final safeTitle = _sanitizeFileName(video.title);

      log('Resolved video: "${video.title}"');
      log('Using temporary directory: ${tempDir.path}');

      switch (mode) {
        case modeAudio:
          await _downloadAudioAsMp3(
            yt: yt,
            manifest: manifest,
            baseDir: tempDir,
            baseName: safeTitle,
            onLog: log,
            onProgress: onProgress,
            onStatus: setStatus,
          );
          break;
        case modeMerge:
          await _downloadAndMergeBestVideoAndAudio(
            yt: yt,
            manifest: manifest,
            baseDir: tempDir,
            baseName: safeTitle,
            onLog: log,
            onProgress: onProgress,
            onStatus: setStatus,
          );
          break;
        case modeMuxed:
          await _downloadMuxed(
            yt: yt,
            manifest: manifest,
            baseDir: tempDir,
            baseName: safeTitle,
            onLog: log,
            onProgress: onProgress,
            onStatus: setStatus,
          );
          break;
        default:
          throw ArgumentError.value(
            mode,
            'mode',
            'Unsupported mode. Expected one of: $modeAudio, $modeMerge, $modeMuxed.',
          );
      }

      setStatus('done');
      log('Done.');
    } catch (e, stackTrace) {
      setStatus('error');
      log('Error: $e');
      log(stackTrace.toString());
      rethrow;
    } finally {
      yt.close();
    }
  }

  /// Make a filesystem-safe file name from a video title.
  String _sanitizeFileName(String input) {
    // Strip control characters.
    final withoutControl = input.replaceAll(RegExp(r'[\x00-\x1F]'), '');
    // Replace characters that are invalid on typical filesystems.
    final sanitized =
        withoutControl.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_').trim();

    if (sanitized.isEmpty) {
      return 'video';
    }

    const maxLength = 120;
    if (sanitized.length > maxLength) {
      return sanitized.substring(0, maxLength);
    }
    return sanitized;
  }

  /// Selects the stream with the highest bitrate from [streams].
  T? _withHighestBitrate<T extends StreamInfo>(Iterable<T> streams) {
    if (streams.isEmpty) return null;
    return streams.reduce(
      (a, b) => a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b,
    );
  }

  /// Download a YouTube stream into [file], reporting progress.
  Future<void> _downloadStreamToFile({
    required Stream<List<int>> stream,
    required File file,
    required int totalBytes,
    required void Function(String) onLog,
    void Function(double progress)? onProgress,
  }) async {
    onLog(
      'Downloading to ${file.path} (${_formatBytes(totalBytes)})...',
    );

    final sink = file.openWrite();
    var received = 0;

    try {
      await for (final data in stream) {
        received += data.length;
        sink.add(data);

        if (onProgress != null && totalBytes > 0) {
          onProgress(received / totalBytes);
        }
      }
    } finally {
      await sink.close();
    }

    if (onProgress != null) {
      onProgress(1.0);
    }

    onLog('Download finished: ${file.path}');
  }

  String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  /// Mode `audio`:
  /// - Download best audio-only stream.
  /// - Convert to MP3 using FFmpeg (`libmp3lame`).
  /// - Export to gallery via [Gal.putVideo].
  Future<void> _downloadAudioAsMp3({
    required YoutubeExplode yt,
    required StreamManifest manifest,
    required Directory baseDir,
    required String baseName,
    required void Function(String) onLog,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    // Prefer M4A (AAC) if available, otherwise fall back to any audio-only.
    final preferred = _withHighestBitrate(
      manifest.audioOnly
          .where((a) => a.container == StreamContainer.mp4),
    );
    final audio = preferred ?? manifest.audioOnly.withHighestBitrate();

    if (audio == null) {
      throw StateError('No suitable audio-only stream found.');
    }

    onLog(
      'Selected audio stream: ${audio.codec} @ ${audio.bitrate.kiloBitsPerSecond.round()} kbps (${audio.container})',
    );

    final audioTempPath =
        p.join(baseDir.path, '$baseName.audio.${audio.container.name}');
    final audioTempFile = File(audioTempPath);

    if (audioTempFile.existsSync()) {
      await audioTempFile.delete();
    }

    final audioStream = yt.videos.streamsClient.get(audio);
    await _downloadStreamToFile(
      stream: audioStream,
      file: audioTempFile,
      totalBytes: audio.size.totalBytes,
      onLog: onLog,
      onProgress: onProgress,
    );

    // Convert to MP3 via FFmpeg INSIDE the temp directory.
    final mp3Path = p.join(baseDir.path, '$baseName.mp3');
    final mp3File = File(mp3Path);
    if (mp3File.existsSync()) {
      await mp3File.delete();
    }

    onStatus?.call('converting');
    onLog('Converting audio to MP3 via FFmpeg...');

    // Use libmp3lame for encoding as requested.
    final ffmpegCommand =
        '-y -i "${audioTempFile.path}" -vn -codec:a libmp3lame -qscale:a 2 "$mp3Path"';

    final session = await FFmpegKit.execute(ffmpegCommand);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      onLog('FFmpeg failed with code $returnCode. Output:\n$output');
      throw StateError('FFmpeg audio conversion failed.');
    }

    onLog('MP3 created: $mp3Path');

    // Export to gallery (Music) using Gal.
    onStatus?.call('exporting');
    onLog('Saving MP3 to gallery via Gal.putVideo...');
    await Gal.putVideo(mp3Path);
    onLog('MP3 exported to gallery.');

    // Best-effort cleanup of intermediate file.
    try {
      if (audioTempFile.existsSync()) {
        await audioTempFile.delete();
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  /// Mode `merge`:
  /// - Download best MP4 video-only stream + best M4A audio-only stream.
  /// - Merge with FFmpeg (`-c:v copy -c:a aac`).
  /// - Export to gallery via [Gal.putVideo].
  Future<void> _downloadAndMergeBestVideoAndAudio({
    required YoutubeExplode yt,
    required StreamManifest manifest,
    required Directory baseDir,
    required String baseName,
    required void Function(String) onLog,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    // Prefer mp4 video; fall back to any video-only.
    final preferredVideo = _withHighestBitrate(
      manifest.videoOnly
          .where((v) => v.container == StreamContainer.mp4),
    );
    final video = preferredVideo ?? manifest.videoOnly.withHighestBitrate();

    if (video == null) {
      throw StateError('No suitable video-only stream found.');
    }

    // Prefer m4a audio; fall back to any audio-only.
    final preferredAudio = _withHighestBitrate(
      manifest.audioOnly
          .where((a) => a.container == StreamContainer.mp4),
    );
    final audio = preferredAudio ?? manifest.audioOnly.withHighestBitrate();

    if (audio == null) {
      throw StateError('No suitable audio-only stream found.');
    }

    onLog(
      'Selected video: ${video.videoResolution} @ ${video.bitrate.kiloBitsPerSecond.round()} kbps (${video.container})',
    );
    onLog(
      'Selected audio: ${audio.codec} @ ${audio.bitrate.kiloBitsPerSecond.round()} kbps (${audio.container})',
    );

    final videoPath =
        p.join(baseDir.path, '$baseName.video.${video.container.name}');
    final audioPath =
        p.join(baseDir.path, '$baseName.audio.${audio.container.name}');

    final videoFile = File(videoPath);
    final audioFile = File(audioPath);

    if (videoFile.existsSync()) {
      await videoFile.delete();
    }
    if (audioFile.existsSync()) {
      await audioFile.delete();
    }

    final videoStream = yt.videos.streamsClient.get(video);
    final audioStream = yt.videos.streamsClient.get(audio);

    await _downloadStreamToFile(
      stream: videoStream,
      file: videoFile,
      totalBytes: video.size.totalBytes,
      onLog: onLog,
      onProgress: onProgress,
    );

    await _downloadStreamToFile(
      stream: audioStream,
      file: audioFile,
      totalBytes: audio.size.totalBytes,
      onLog: onLog,
      onProgress: onProgress,
    );

    // Merge inside temp directory.
    final outputPath = p.join(baseDir.path, '$baseName.merged.mp4');
    final outputFile = File(outputPath);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }

    onStatus?.call('converting');
    onLog('Merging video and audio via FFmpeg...');

    final ffmpegCommand =
        '-y -i "${videoFile.path}" -i "${audioFile.path}" -c:v copy -c:a aac "$outputPath"';

    final session = await FFmpegKit.execute(ffmpegCommand);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      onLog('FFmpeg failed with code $returnCode. Output:\n$output');
      throw StateError('FFmpeg merge failed.');
    }

    onLog('Merged file created: $outputPath');

    onStatus?.call('exporting');
    onLog('Saving merged video to gallery via Gal.putVideo...');
    await Gal.putVideo(outputPath);
    onLog('Merged video exported to gallery.');

    // Best-effort cleanup of intermediate files.
    try {
      if (videoFile.existsSync()) {
        await videoFile.delete();
      }
      if (audioFile.existsSync()) {
        await audioFile.delete();
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  /// Mode `muxed`:
  /// - Download best muxed stream from `manifest.muxed`.
  /// - Save directly (no FFmpeg processing).
  /// - Export to gallery via [Gal.putVideo].
  Future<void> _downloadMuxed({
    required YoutubeExplode yt,
    required StreamManifest manifest,
    required Directory baseDir,
    required String baseName,
    required void Function(String) onLog,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final muxed = manifest.muxed.withHighestBitrate();

    if (muxed == null) {
      throw StateError('No muxed stream available for this video.');
    }

    onLog(
      'Selected muxed: ${muxed.videoResolution} @ ${muxed.bitrate.kiloBitsPerSecond.round()} kbps (${muxed.container})',
    );

    final muxedPath =
        p.join(baseDir.path, '$baseName.muxed.${muxed.container.name}');
    final muxedFile = File(muxedPath);

    if (muxedFile.existsSync()) {
      await muxedFile.delete();
    }

    final muxedStream = yt.videos.streamsClient.get(muxed);

    await _downloadStreamToFile(
      stream: muxedStream,
      file: muxedFile,
      totalBytes: muxed.size.totalBytes,
      onLog: onLog,
      onProgress: onProgress,
    );

    onStatus?.call('exporting');
    onLog('Saving muxed video to gallery via Gal.putVideo...');
    await Gal.putVideo(muxedPath);
    onLog('Muxed video exported to gallery.');
  }
}

