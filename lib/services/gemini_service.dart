import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:google_generative_ai/google_generative_ai.dart' as genai;

void main() async {
  final service = GeminiProcessingService(
    flutterTts: FlutterTts(),
    apiKey: 'AIzaSyBTvsDIfoK6N7GGXA6ULSHEQji17Bj1QCM',
  );

  await service.initializeModel(); // Wait for initialization
  await service.processVideo('path_to_your_frame'); // Now process the video
}

class GeminiProcessingService {
  final FlutterTts flutterTts;
  final String apiKey;
  genai.GenerativeModel? _model;
  genai.ChatSession? _chat;

  GeminiProcessingService({required this.flutterTts, required this.apiKey}) {
    initializeModel();
  }

  Future<String> loadEnvFile() async {
    final String contents = await rootBundle.loadString('assets/.env');
    print('Contents of .env file: $contents'); // Debug print
    return contents;
  }

  String? parseApiKey(String fileContents) {
    final List<String> lines = fileContents.split('\n');
    final apiKeyLine = lines.firstWhere(
          (line) => line.startsWith('API_KEY='),
      orElse: () => '',
    );
    return apiKeyLine.isNotEmpty ? apiKeyLine.split('=')[1].trim() : null;
  }

  Future<void> initializeModel() async {
    try {
      final apiKeyContents = await loadEnvFile();
      final apiKey = parseApiKey(apiKeyContents);
      print('Parsed API Key: $apiKey'); // Debug print
      if (apiKey == null || apiKey.isEmpty) {
        print('API key not found. Please check your configuration.');
        return;
      }
      final _model = genai.GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      print("Final model loaded ");
      _chat = _model!.startChat(history: [
        genai.Content.model([
          genai.TextPart(
              "Provide concise descriptions of obstacles or key objects in the blind user's path, focusing solely on what is necessary for avoiding collisions or understanding surroundings.")
        ])
      ]);
      print('Model and chat initialized successfully.');
    } catch (e) {
      print('Error initializing model: $e');
    }
  }

  Future<void> processVideo(String? framePath) async {
    if (_chat == null) {
      print('Chat session not initialized. Please initialize the model first.');
      return; // Prevent further execution
    }

    if (framePath != null && await File(framePath).exists()) {
      // Process the frame
      final extractedImage = await File(framePath).readAsBytes();
      var userVideo = genai.Content.data('image/jpeg', extractedImage);

      StringBuffer responseBuffer = StringBuffer(); // String buffer to accumulate the chunks

      await for (final chunk in _chat!.sendMessageStream(userVideo)) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          print('Received chunk from API: ${chunk.text}');
          responseBuffer.write(chunk.text!); // Append the chunk to the buffer
        } else {
          print('No description available or chunk is empty.');
        }
      }

      // Now pass the accumulated string to TTS
      String finalResponse = responseBuffer.toString();
      print('Final accumulated response: $finalResponse');
      await _speak(finalResponse);

      cleanupFrame(framePath);
    } else {
      print('Frame path is null or file does not exist.');
    }
  }

  Future<void> processAudio(String? audioText) async {
    if (audioText != null && audioText.isNotEmpty) {
      var userAudio = genai.Content.text(audioText);

      StringBuffer responseBuffer = StringBuffer(); // String buffer to accumulate the chunks

      await for (final chunk in _chat!.sendMessageStream(userAudio)) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          print('Received chunk from API: ${chunk.text}');
          responseBuffer.write(chunk.text!); // Append the chunk to the buffer
        } else {
          print('No description available or chunk is empty.');
        }
      }

      // Now pass the accumulated string to TTS
      String finalResponse = responseBuffer.toString();
      print('Final accumulated response: $finalResponse');
      await _speak(finalResponse);
    } else {
      print('Audio text is null or empty.');
    }
  }

  Future<void> cleanupFrame(String framePath) async {
    try {
      var frameFile = File(framePath);
      if (await frameFile.exists()) {
        await frameFile.delete();
        print("Extracted frame file deleted successfully.");
      }
    } catch (e) {
      print("Failed to delete files: $e");
    }
  }

  Future<void> _speak(String message) async {
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
    await flutterTts.speak(message);
  }
}
