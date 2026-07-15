import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MJApp());
}

class MJApp extends StatelessWidget {
  const MJApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MJ System Assistant',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const MJHomeScreen(),
    );
  }
}

class MJHomeScreen extends StatefulWidget {
  const MJHomeScreen({super.key});

  @override
  State<MJHomeScreen> createState() => _MJHomeScreenState();
}

class _MJHomeScreenState extends State<MJHomeScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isSpeaking = false;
  String _displayText =
      "सिस्टम तैयार है बॉस!\n\nमुझे बुलाने के लिए कहें:\n'MJ, कॉल लगाओ' या\n'MJ, यूट्यूब पर गाने चलाओ'";

  // आपकी Groq AI की चाबी
  final String apiKey =
      "Gsk_4WnSQaRMyEQGeZggXETOWGdyb3FY0NPwVxH1u9S0VIZE6SUxcdre";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initTts();
    _initSpeech();
  }

  // सभी परमिशन्स एक साथ मांगना
  void _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.phone,
      Permission.sms,
    ].request();
  }

  void _initSpeech() async {
    await _speechToText.initialize(onStatus: (status) {
      if ((status == 'done' || status == 'notListening') && !_isSpeaking) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isSpeaking) {
            _startListening();
          }
        });
      }
    });
    _startListening();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("hi-IN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _displayText = "मैं सुन रहा हूँ बॉस... ('MJ' बोलकर कमांड दें)";
      });
      _startListening();
    });
  }

  void _speak(String text) async {
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    await _speechToText.stop();
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_isSpeaking) {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: 'hi_IN',
        listenFor: const Duration(seconds: 30),
      );
      setState(() {
        _isListening = true;
      });
    }
  }

  void _onSpeechResult(result) async {
    if (result.finalResult && !_isSpeaking) {
      String userText = result.recognizedWords.toLowerCase();

      // वेक वर्ड चेक (Wake Word)
      if (userText.contains("mj") ||
          userText.contains("एमजे") ||
          userText.contains("एम जे")) {
        setState(() {
          _displayText = "कमांड मिली: $userText\n\nMJ प्रोसेस कर रहा है... ⚙️";
        });

        await _processCommand(userText);
      }
    }
  }

  // असली सिस्टम कंट्रोलर (दिमाग)
  Future<void> _processCommand(String text) async {
    // 1. YouTube खोलने का लॉजिक
    if (text.contains("यूट्यूब") ||
        text.contains("youtube") ||
        text.contains("गाने चलाओ")) {
      String query = text
          .replaceAll("mj", "")
          .replaceAll("यूट्यूब पर", "")
          .replaceAll("youtube", "")
          .replaceAll("गाने चलाओ", "")
          .trim();
      _speak("यूट्यूब खोल रहा हूँ बॉस");
      String searchUrl = "https://www.youtube.com/results?search_query=$query";
      await launchUrl(Uri.parse(searchUrl),
          mode: LaunchMode.externalApplication);
    }
    // 2. WhatsApp मैसेज का लॉजिक
    else if (text.contains("व्हाट्सएप") ||
        text.contains("whatsapp") ||
        text.contains("मैसेज करो")) {
      _speak("व्हाट्सएप ओपन कर रहा हूँ");
      // सीधे WhatsApp ऐप खोलने के लिए
      await launchUrl(Uri.parse("whatsapp://send?text=Hello"),
          mode: LaunchMode.externalApplication);
    }
    // 3. कॉलिंग का लॉजिक
    else if (text.contains("कॉल") ||
        text.contains("फोन लगाओ") ||
        text.contains("call")) {
      _speak("कॉल डायलर खोल रहा हूँ बॉस");
      // यह फोन का डायलर खोल देगा (आप बाद में इसमें नंबर ढूँढने का एडवांस फीचर भी जोड़ सकते हैं)
      await launchUrl(Uri.parse("tel:"), mode: LaunchMode.externalApplication);
    }
    // 4. अगर कोई सिस्टम कमांड नहीं है, तो AI (Groq) से पूछें
    else {
      String aiResponse = await _getAIResponse(text);
      setState(() {
        _displayText = "आपने कहा: $text\n\nMJ: $aiResponse";
      });
      _speak(aiResponse);
    }
  }

  // AI से बात करने का फंक्शन
  Future<String> _getAIResponse(String text) async {
    try {
      var url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      var response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": [
            {
              "role": "system",
              "content":
                  "तुम एक बहुत ही स्मार्ट AI असिस्टेंट हो, तुम्हारा नाम MJ है। तुम्हें विशाल ने बनाया है। यूज़र के सवालों का जवाब हिंदी में और छोटे वाक्यों में दो।"
            },
            {"role": "user", "content": text}
          ]
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        return "बॉस, मुझे इंटरनेट से जुड़ने में दिक्कत हो रही है।";
      }
    } catch (e) {
      return "माफ़ करना बॉस, मेरे दिमाग में कोई तकनीकी खराबी आ गई है।";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MJ System Assistant',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Text(
              _displayText,
              style: const TextStyle(
                  fontSize: 22, color: Colors.white, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // अब यह ऑटोमेटिक है
        backgroundColor: _isListening ? Colors.green : Colors.grey,
        child: Icon(_isListening ? Icons.mic : Icons.mic_off,
            size: 35, color: Colors.white),
      ),
    );
  }
}
