import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  final YoutubeExplode _youtubeExplode = YoutubeExplode();

  Future<Video> getVideoInfo(String url) async {
    final videoId = VideoId(url);
    return await _youtubeExplode.videos.get(videoId);
  }

  Future<StreamManifest> getStreamManifest(String url) async {
    final videoId = VideoId(url);
    return await _youtubeExplode.videos.streamsClient.getManifest(videoId);
  }

  Future<void> downloadAudio(MuxedStreamInfo streamInfo, String savePath) async {
    final stream = _youtubeExplode.videos.streamsClient.get(streamInfo);
    final file = File(savePath);
    final output = file.openWrite(mode: FileMode.writeOnlyAppend);
    await stream.pipe(output);
  }

  Future<void> downloadVideo(MuxedStreamInfo streamInfo, String savePath) async {
    final stream = _youtubeExplode.videos.streamsClient.get(streamInfo);
    final file = File(savePath);
    final output = file.openWrite(mode: FileMode.writeOnlyAppend);
    await stream.pipe(output);
  }

  Future<void> mergeStreams(VideoStreamInfo videoStreamInfo, AudioStreamInfo audioStreamInfo, String savePath) async {
    final tempDir = await getTemporaryDirectory();
    final videoPath = '${tempDir.path}/video.mp4';
    final audioPath = '${tempDir.path}/audio.mp4';

    await _downloadStream(videoStreamInfo, videoPath);
    await _downloadStream(audioStreamInfo, audioPath);

    final command = '-i $videoPath -i $audioPath -c:v copy -c:a aac $savePath';
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      throw Exception('FFmpeg process failed with return code $returnCode');
    }

    await File(videoPath).delete();
    await File(audioPath).delete();
  }

  Future<void> _downloadStream(StreamInfo streamInfo, String path) async {
    final stream = _youtubeExplode.videos.streamsClient.get(streamInfo);
    final file = File(path);
    final output = file.openWrite(mode: FileMode.writeOnlyAppend);
    await stream.pipe(output);
  }
}
