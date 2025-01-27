import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;



class Menu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech to Press Button',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SpeechButtonScreen(),
    );
  }
}

class SpeechButtonScreen extends StatefulWidget {
  @override
  _SpeechButtonScreenState createState() => _SpeechButtonScreenState();
}

class _SpeechButtonScreenState extends State<SpeechButtonScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = 'Say "press" to press the button';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(onResult: (val) {
        setState(() {
          _command = val.recognizedWords;
          // If the speech matches "press", trigger the button action
          if (_command.toLowerCase().contains("press")) {
            _pressButton();
          }
        });
      });
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _pressButton() {
    // Perform your button press action here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Button Pressed by Speech!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech to Press Button'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$_command',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pressButton,
              child: Text('Press Me'),
            ),
            SizedBox(height: 20),
            FloatingActionButton(
              onPressed: _isListening ? _stopListening : _startListening,
              child: Icon(_isListening ? Icons.mic_off : Icons.mic),
            ),
          ],
        ),
      ),
    );
  }
}
