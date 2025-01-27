import 'dart:ffi';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:Pathfinder/MySplashPage.dart';
import 'main.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:Pathfinder/services/gemini_service.dart';
import 'package:Pathfinder/services/video_processing_service.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isWorking = false;
  String result = "";
  late CameraController cameraController;
  late VideoProcessingService _videoService;
  CameraImage? imgCamera;
  FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _spechEnabled = false;
  String _wordsSpoken = "";
  final GeminiProcessingService _geminiService =
  GeminiProcessingService(flutterTts: FlutterTts(), apiKey: 'YOUR_API_KEY');
  ValueNotifier<bool> _isVideoRecording = ValueNotifier(false);
  ValueNotifier<bool> _isListening = ValueNotifier(false);
  String _lastWords = '';
  late Timer _semanticsTimer;
  bool _allowSemanticUpdate = true;
  bool isTtsSpeaking = false;





  void _toggleVideoRecording() async {
    if (_isVideoRecording.value) {
      String? framePath = await _videoService.stopAndProcessVideo();
      if (framePath != null) {
        _geminiService.processVideo(framePath);
      } else {
        print("No frame path returned from video processing.");
      }
      _isVideoRecording.value = false;
    } else {
      await _videoService.startVideoRecording();
      _isVideoRecording.value = true;
    }
    if (_allowSemanticUpdate) {
      setState(() => _allowSemanticUpdate = false);
    }
  }
  void _startVideoRecording() async {
    try {
      await _videoService.startVideoRecording();
      _isVideoRecording.value = true;
      if (_allowSemanticUpdate) {
        setState(() => _allowSemanticUpdate = false);
      }
      print('Video recording started.');
    } catch (e) {
      print('Error starting video recording: $e');
    }
  }

  void _stopVideoRecording() async {
    try {
      String? framePath = await _videoService.stopAndProcessVideo();
      if (framePath != null) {
        _geminiService.processVideo(framePath);
      } else {
        print("No frame path returned from video processing.");
      }
      _isVideoRecording.value = false;
      print('Video recording stopped and frame processed.');
    } catch (e) {
      print('Error stopping video recording: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _initializeServices();
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
    flutterTts.setCompletionHandler(() {
      setState(() {
        isTtsSpeaking = false;
      });
    });
    _semanticsTimer = Timer.periodic(Duration(minutes: 1), (_) {
      if (!_allowSemanticUpdate) {
        setState(() => _allowSemanticUpdate = true);
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      cameraController = CameraController(cameras[0], ResolutionPreset.veryHigh);
      await cameraController.initialize();

      if (mounted) {
        setState(() {});
      }

      _videoService = VideoProcessingService(
        controller: cameraController,
        flutterTts: flutterTts,
        onRecordingStateChanged: (isRecording) =>
        _isVideoRecording.value = isRecording,
      );
      await _speechToText.initialize();
    } catch (e) {
      print("Error initializing services: $e");
    }
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    _spechEnabled = true;
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    _spechEnabled = false;
  }

  void _onSpeechResult(result) {
    setState(() {
        _wordsSpoken = "${result.recognizedWords}";
        _geminiService.processAudio(_wordsSpoken);

        // Use text-to-speech to speak the recognized words
        flutterTts.speak(_wordsSpoken).then((_) {
          print("Spoken: $_wordsSpoken");
        }).catchError((e) {
          print("Error with TTS: $e");
        });

    });
  }


  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(

        child: Scaffold(
          body: cameraController.value.isInitialized
              ? Stack(
            fit: StackFit.expand,
            children: [
              _buildCameraPreview(),

              Positioned(
                top: -15, // Align at the bottom of the screen
                left: 0,
                right: 0,
                child: Image.asset(
                  "assets/pathfinder.png", // Your image
                  // fit: BoxFit.cover, // Cover the area behind the buttons
                  height: 150, // Adjust height to match the black area
                ),
              ),



              Positioned(
                bottom: 20,
                left: 20,
                child:
                  ElevatedButton(
                    onPressed: _startVideoRecording,
                  style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(10),
                ),
                    child: const Icon(
                        Icons.play_arrow,
                        size: 50.0,
              ),

                  ),


              ),
              Positioned(
                bottom: 20,
                right: 20,
                child:
                ElevatedButton(
                  onPressed: _stopVideoRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10),
                  ),
                  child: const Icon(
                    Icons.stop,
                    size: 50.0,
                  ),

                ),


              ),
            ],
          )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          label: _allowSemanticUpdate
              ? 'Double Tap anywhere on the screen to toggle video recording'
              : '',
          child: GestureDetector(
            onTap: _toggleVideoRecording,
            child: CameraPreview(cameraController),
          ),
        ),
        // Positioned(
        //   bottom: 20.0,
        //   left: 0.0,
        //   right: 0.0,
        //   child: Center(
        //     child: ValueListenableBuilder<bool>(
        //       valueListenable: _isListening,
        //       builder: (_, isListening, __) {
        //         return Semantics(
        //             button: true,
        //             label: 'Microphone',
        //             child: Opacity(
        //               opacity: 1.0,
        //               child: ElevatedButton(
        //                 onPressed: () {
        //                   if (isListening) {
        //                     _stopListening();
        //                   } else {
        //                     _startListening();
        //                   }
        //                 },
        //                 style: ElevatedButton.styleFrom(
        //                   backgroundColor: Colors.blue[600],
        //                   foregroundColor: Colors.white,
        //                   shape: const CircleBorder(),
        //                   padding: const EdgeInsets.all(15),
        //                 ),
        //                 child: const Icon(
        //                   Icons.mic,
        //                   size: 50.0,
        //                 ),
        //               ),
        //             ));
        //       },
        //     ),
        //   ),
        // ),
      ],
    );
  }
}
