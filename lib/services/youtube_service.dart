import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'settings_service.dart';

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
  final SettingsService _settingsService;
  YoutubeService(this._settingsService);

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
    final settings = await _settingsService.loadSettings();
    final client = ConfiguredHttpClient(
      userAgent: settings.userAgent,
      cookies: settings.cookies,
    );
    final yt = YoutubeExplode(httpClient: YoutubeHttpClient(client));

    try {
      onLog('Analyzing URL...');
      final videoId = VideoId(url.trim());
      
      YoutubeAnalysis analysis;
      try {
        final video = await yt.videos.get(videoId);
        onLog('Title: ${video.title}');
        onLog('Channel: ${video.author}');
        if (video.duration != null) {
          onLog('Duration: ${video.duration}');
        }
        final thumbnailUrl =
            video.thumbnails.highResUrl ?? video.thumbnails.standardResUrl;

        analysis = YoutubeAnalysis(
          title: video.title,
          author: video.author,
          duration: video.duration,
          thumbnailUrl: thumbnailUrl,
        );
      } catch (e) {
        onLog('Standard analyze failed: $e. Using fallback iOS API...');
        analysis = await _fetchMetadataViaIosApi(videoId.value);
        onLog('Fallback success!');
        onLog('Title: ${analysis.title}');
        onLog('Channel: ${analysis.author}');
        if (analysis.duration != null) {
          onLog('Duration: ${analysis.duration}');
        }
      }

      return analysis;
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
    final settings = await _settingsService.loadSettings();
    final client = ConfiguredHttpClient(
      userAgent: settings.userAgent,
      cookies: settings.cookies,
    );
    final customClient = CustomYoutubeHttpClient(client);
    final yt = YoutubeExplode(httpClient: customClient);

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
      String title;
      try {
        final video = await yt.videos.get(videoId);
        title = video.title;
      } catch (e) {
        log('Standard fetch details failed: $e. Using fallback iOS API...');
        final fallbackDetails = await _fetchMetadataViaIosApi(videoId.value);
        title = fallbackDetails.title;
      }

      StreamManifest manifest;
      try {
        log('Fetching stream manifest (with watch page)...');
        manifest = await yt.videos.streamsClient.getManifest(
          videoId,
          requireWatchPage: true,
          ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.androidSdkless],
        );
      } catch (e) {
        log('Failed to fetch manifest with watch page: $e. Using fallback player-only manifest...');
        manifest = await yt.videos.streamsClient.getManifest(
          videoId,
          requireWatchPage: false,
          ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.androidSdkless],
        );
      }

      final tempDir = await getTemporaryDirectory();
      final safeTitle = _sanitizeFileName(title);

      log('Resolved video: "$title"');
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
    var lastLoggedMb = 0;

    try {
      // Wrap stream with timeout to detect hangs (0% progress issue)
      final timedStream = stream.timeout(
        const Duration(seconds: 10),
        onTimeout: (sink) {
          sink.addError(TimeoutException('Stream timed out after 10 seconds of no data.'));
          sink.close();
        },
      );

      await for (final data in timedStream) {
        received += data.length;
        sink.add(data);

        if (onProgress != null && totalBytes > 0) {
          onProgress(received / totalBytes);
        }

        // Log every ~5 MB to verify activity without flooding logs
        final currentMb = received ~/ (1024 * 1024 * 5);
        if (currentMb > lastLoggedMb) {
           onLog('Downloaded ${_formatBytes(received)} / ${_formatBytes(totalBytes)}');
           lastLoggedMb = currentMb;
        }
      }
    } catch (e, st) {
      onLog('Stream error: $e');
      if (e is! TimeoutException) {
         onLog(st.toString());
      }
      rethrow;
    } finally {
      await sink.close();
    }

    if (onProgress != null) {
      onProgress(1.0);
    }

    onLog('Download finished: ${file.path} (Size: ${_formatBytes(received)})');
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
    // Use Muxed stream for audio download to avoid adaptive stream hangs.
    // We select the lowest quality video to save bandwidth, since we only want audio.
    final muxed = manifest.muxed.sortByBitrate().firstOrNull; // Lowest bitrate

    if (muxed == null) {
      throw StateError('No muxed stream found for audio download.');
    }

    onLog(
      'Selected muxed stream for audio source: ${muxed.videoResolution} @ ${muxed.bitrate.kiloBitsPerSecond.round()} kbps (${muxed.container})',
    );

    final audioTempPath =
        p.join(baseDir.path, '$baseName.audio_source.${muxed.container.name}');
    final audioTempFile = File(audioTempPath);

    if (audioTempFile.existsSync()) {
      await audioTempFile.delete();
    }

    final audioStream = yt.videos.streamsClient.get(muxed);
    await _downloadStreamToFile(
      stream: audioStream,
      file: audioTempFile,
      totalBytes: muxed.size.totalBytes,
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

    onLog('Executing FFmpeg: $ffmpegCommand');
    final session = await FFmpegKit.execute(ffmpegCommand);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      final failLog = await session.getFailStackTrace();
      onLog('FFmpeg failed with code $returnCode.\nOutput: $output\nFailLog: $failLog');
      throw StateError('FFmpeg audio conversion failed.');
    }

    onLog('MP3 created: $mp3Path');

    // Save to Music folder using MediaStore (Android 13+ compliant)
    onStatus?.call('exporting');
    onLog('Saving MP3 to Music folder via MediaStore...');

    try {
      if (Platform.isAndroid) {
        final mediaStore = MediaStore();
        await mediaStore.saveFile(
          tempFilePath: mp3Path,
          dirType: DirType.audio,
          dirName: DirName.music,
          relativePath: 'DownloadVideos_App', // Optional subfolder
        );
        onLog('MP3 saved to Music/DownloadVideos_App via MediaStore.');
      } else {
        // Fallback for non-Android (if any) or older behavior
        await Gal.putVideo(mp3Path);
        onLog('MP3 exported via Gal (non-Android/Older).');
      }
    } catch (e) {
      onLog('MediaStore saving failed: $e');
      onLog('Attempting direct save to Downloads folder (Android workaround)...');

      try {
         final downloadsPath = '/storage/emulated/0/Download';
         final newPath = p.join(downloadsPath, '$baseName.mp3');
         onLog('Copying to: $newPath');

         if (Platform.isAndroid) {
           final newFile = await mp3File.copy(newPath);
           onLog('Success! Saved to: ${newFile.path}');
         } else {
           rethrow;
         }
      } catch (e2) {
         onLog('Direct save failed: $e2');
         onLog('File remains at: $mp3Path');
         rethrow;
      }
    }

    // Best-effort cleanup of intermediate file.
    try {
      if (audioTempFile.existsSync()) {
        await audioTempFile.delete();
      }
      // Note: MediaStorePlus usually copies the file.
      // We might want to keep the temp file or delete it?
      // Usually temp file should be deleted if successful.
      // But let's leave mp3File for now in cache just in case.
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
    // Select the absolute highest quality video stream (MP4 or WebM/VP9)
    final video = manifest.videoOnly.withHighestBitrate();
 
    if (video == null) {
      throw StateError('No suitable video-only stream found.');
    }
 
    // Select the absolute highest quality audio stream
    final audio = manifest.audioOnly.withHighestBitrate();

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

    onLog('Starting download (Adaptive). If this hangs for 10s, app will auto-switch to Fast mode.');

    try {
      var videoBytesDownloaded = 0;
      var audioBytesDownloaded = 0;
      final totalExpectedBytes = video.size.totalBytes + audio.size.totalBytes;

      await _downloadStreamToFile(
        stream: videoStream,
        file: videoFile,
        totalBytes: video.size.totalBytes,
        onLog: onLog,
        onProgress: (p) {
          videoBytesDownloaded = (p * video.size.totalBytes).round();
          if (onProgress != null && totalExpectedBytes > 0) {
            onProgress((videoBytesDownloaded + audioBytesDownloaded) / totalExpectedBytes);
          }
        },
      );

      await _downloadStreamToFile(
        stream: audioStream,
        file: audioFile,
        totalBytes: audio.size.totalBytes,
        onLog: onLog,
        onProgress: (p) {
          audioBytesDownloaded = (p * audio.size.totalBytes).round();
          if (onProgress != null && totalExpectedBytes > 0) {
            onProgress((videoBytesDownloaded + audioBytesDownloaded) / totalExpectedBytes);
          }
        },
      );
    } catch (e) {
      onLog('Adaptive stream download failed: $e');
      onLog('Falling back to "Muxed" (Fast) strategy to ensure download completion...');

      // Clean up partial files
      try {
        if (videoFile.existsSync()) await videoFile.delete();
        if (audioFile.existsSync()) await audioFile.delete();
      } catch (_) {}

      // Fallback: Download Muxed stream directly
      await _downloadMuxed(
        yt: yt,
        manifest: manifest,
        baseDir: baseDir,
        baseName: baseName,
        onLog: onLog,
        onProgress: onProgress,
        onStatus: onStatus,
      );
      return; // Stop merge execution
    }

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

  Future<YoutubeAnalysis> _fetchMetadataViaIosApi(String videoId) async {
    final url = Uri.parse(
      'https://www.youtube.com/youtubei/v1/player?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc',
    );
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
    };
    final body = jsonEncode({
      'videoId': videoId,
      'context': {
        'client': {
          'clientName': 'IOS',
          'clientVersion': '20.10.4',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'userAgent': 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
          'hl': 'en',
          'platform': 'MOBILE',
          'osName': 'IOS',
          'osVersion': '18.1.0.22B83',
          'timeZone': 'UTC',
          'gl': 'US',
          'utcOffsetMinutes': 0
        }
      }
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw HttpException('Failed to fetch metadata from iOS API. Status code: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    
    final playabilityStatus = json['playabilityStatus'] as Map<String, dynamic>?;
    if (playabilityStatus != null && playabilityStatus['status'] == 'ERROR') {
      throw StateError(playabilityStatus['reason'] ?? 'Video is unavailable');
    }

    final videoDetails = json['videoDetails'] as Map<String, dynamic>?;
    if (videoDetails == null) {
      throw StateError('videoDetails not found in response');
    }

    final title = videoDetails['title'] ?? 'Unknown Video';
    final author = videoDetails['author'] ?? 'Unknown Channel';
    final lengthSeconds = int.tryParse(videoDetails['lengthSeconds'] ?? '');
    final duration = lengthSeconds != null ? Duration(seconds: lengthSeconds) : null;
    
    final thumbnailJson = videoDetails['thumbnail'] as Map<String, dynamic>?;
    final thumbnails = thumbnailJson?['thumbnails'] as List<dynamic>?;
    final thumbnailUrl = thumbnails != null && thumbnails.isNotEmpty
        ? thumbnails.last['url'] as String
        : 'https://img.youtube.com/vi/$videoId/0.jpg';

    return YoutubeAnalysis(
      title: title,
      author: author,
      duration: duration,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

class ConfiguredHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final String userAgent;
  final String cookies;

  ConfiguredHttpClient({
    required this.userAgent,
    required this.cookies,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (userAgent.isNotEmpty) {
      request.headers['User-Agent'] = userAgent;
    }
    if (cookies.isNotEmpty) {
      request.headers['Cookie'] = cookies;
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class CustomYoutubeHttpClient extends YoutubeHttpClient {
  CustomYoutubeHttpClient([http.Client? httpClient]) : super(httpClient);

  void customValidateResponse(http.BaseResponse response, int statusCode) {
    if (closed) return;

    final request = response.request!;

    if (request.url.host.endsWith('.google.com') &&
        request.url.path.startsWith('/sorry/')) {
      throw RequestLimitExceededException.httpRequest(response);
    }

    if (statusCode >= 500) {
      throw TransientFailureException.httpRequest(response);
    }

    if (statusCode == 429) {
      throw RequestLimitExceededException.httpRequest(response);
    }

    if (statusCode >= 400) {
      throw FatalFailureException.httpRequest(response);
    }
  }

  Uri _setQueryParam(Uri uri, String key, String value) {
    final params = Map<String, String>.from(uri.queryParameters);
    params[key] = value;
    return uri.replace(queryParameters: params);
  }

  Future<T> _retry<T>(Future<T> Function() fn, {int retries = 5}) async {
    int attempts = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempts++;
        if (attempts >= retries) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  @override
  Stream<List<int>> getStream(
    StreamInfo streamInfo, {
    Map<String, String> headers = const {},
    bool validate = true,
    int start = 0,
    int errorCount = 0,
    required StreamClient streamClient,
  }) {
    if (streamInfo.fragments.isNotEmpty) {
      return super.getStream(streamInfo,
          headers: headers,
          validate: validate,
          start: start,
          errorCount: errorCount,
          streamClient: streamClient);
    }
    if (streamInfo.runtimeType.toString().contains('Hls')) {
      return super.getStream(streamInfo,
          headers: headers,
          validate: validate,
          start: start,
          errorCount: errorCount,
          streamClient: streamClient);
    }
    return _getCustomStream(
      streamInfo,
      headers: headers,
      validate: validate,
      start: start,
      errorCount: errorCount,
      streamClient: streamClient,
    );
  }

  Stream<List<int>> _getCustomStream(
    StreamInfo streamInfo, {
    Map<String, String> headers = const {},
    bool validate = true,
    int start = 0,
    int errorCount = 0,
    required StreamClient streamClient,
  }) async* {
    var url = streamInfo.url;
    int bytesCount = start;
    const int chunkSize = 512 * 1024; // 512 KB chunks

    while (!closed && bytesCount < streamInfo.size.totalBytes) {
      try {
        final response = await _retry(() async {
          final from = bytesCount;
          var to = from + chunkSize - 1;
          if (to >= streamInfo.size.totalBytes) {
            to = streamInfo.size.totalBytes - 1;
          }

          late final http.Request request;
          final useRangeHeader = url.queryParameters['c']?.startsWith('ANDROID') ?? false;
          if (useRangeHeader) {
            request = http.Request('get', url);
            request.headers['Range'] = 'bytes=$from-$to';
          } else {
            request =
                http.Request('get', _setQueryParam(url, 'range', '$from-$to'));
          }
          return send(request);
        });

        if (validate) {
          try {
            customValidateResponse(response, response.statusCode);
          } on FatalFailureException {
            final newManifest =
                await streamClient.getManifest(streamInfo.videoId);
            StreamInfo? stream;
            for (final s in newManifest.streams) {
              if (s.tag == streamInfo.tag) {
                stream = s;
                break;
              }
            }
            if (stream == null) {
              rethrow;
            }
            url = stream.url;
            continue;
          }
        }

        final controller = StreamController<List<int>>();
        response.stream.listen(
          (List<int> data) {
            bytesCount += data.length;
            controller.add(data);
          },
          onError: (e) {
            // Ignore/handle
          },
          onDone: controller.close,
          cancelOnError: false,
        );
        errorCount = 0;
        yield* controller.stream;
      } on HttpClientClosedException {
        break;
      } on Exception {
        if (errorCount == 5) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
        yield* _getCustomStream(
          streamInfo,
          headers: headers,
          validate: validate,
          start: bytesCount,
          errorCount: errorCount + 1,
          streamClient: streamClient,
        );
        break;
      }
    }
  }
}

