import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class VideoProcessingService {
  final CameraController controller;
  final FlutterTts flutterTts;
  final Function(bool) onRecordingStateChanged;

  VideoProcessingService({
    required this.controller,
    required this.flutterTts,
    required this.onRecordingStateChanged,
  });

  Future<void> startVideoRecording() async {
    if (!controller.value.isInitialized) {
      await _speak("Camera is not initialized.");
      return;
    }
    try {
      await controller.startVideoRecording();
      onRecordingStateChanged(true);
      await _speak("Scanning. Tap again to stop.");
    } catch (e) {
      await _speak("Failed to start recording due to $e");
    }
  }

  Future<String> stopAndProcessVideo() async {
    if (!controller.value.isRecordingVideo) {
      await _speak("No video is currently being recorded.");
      throw Exception("No video recording in progress.");
    }
    try {
      final videoFile = await controller.stopVideoRecording();
      onRecordingStateChanged(false);
      await _speak("Finished Scanning. Analyzing your surroundings.");
      final extractedFrame = await extractMiddleFrame(videoFile.path);
      return extractedFrame;
    } catch (e) {
      await _speak("Error during video processing: $e");
      throw e;
    }
  }

  Future<String> extractMiddleFrame(String videoFilePath) async {
    final tempDir = await getTemporaryDirectory();
    final frameExtractionDirectory = path.join(tempDir.path, 'frames');
    final outputPath = path.join(frameExtractionDirectory,
        '${path.basenameWithoutExtension(videoFilePath)}_middle.jpg');
    await Directory(frameExtractionDirectory).create(recursive: true);

    // Use ffprobe_kit to retrieve media info
    final probeSession = await FFprobeKit.getMediaInformation(videoFilePath);
    final mediaInformation = probeSession.getMediaInformation();
    final durationString = mediaInformation?.getDuration();
    if (durationString == null) {
      throw Exception("Failed to retrieve video duration.");
    }

    final duration = double.parse(durationString) / 1000; // Convert milliseconds to seconds
    final middleTime = duration / 2;

    final command = "-i $videoFilePath -ss $middleTime -vframes 1 $outputPath";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print("Middle frame was extracted successfully.");
      cleanupFiles(videoFilePath);
      return outputPath;
    } else {
      throw Exception("Failed to extract middle frame with FFmpeg error code: $returnCode");
    }
  }

  Future<void> _speak(String message) async {
    await flutterTts.speak(message);
  }

  Future<void> cleanupFiles(String videoFilePath) async {
    try {
      var videoFile = File(videoFilePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
        print("Original video file deleted successfully.");
      }
    } catch (e) {
      print("Failed to delete files: $e");
    }
  }
}
