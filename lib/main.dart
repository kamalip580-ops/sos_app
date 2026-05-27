import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shake/shake.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      darkMode = prefs.getBool("darkMode") ?? false;
    });
  }

  Future<void> changeTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool("darkMode", value);

    setState(() {
      darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Smart Silent SOS",
      theme: darkMode ? ThemeData.dark() : ThemeData.light(),
      home: HomePage(
        darkMode: darkMode,
        onThemeChanged: changeTheme,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool darkMode;
  final Function(bool) onThemeChanged;

  const HomePage({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? mapController;

  double latitude = 11.618065;
  double longitude = 78.455278;

  String status = "SAFE";

  late stt.SpeechToText speech;

  // ======================================================
  // ADD EMERGENCY CONTACT NUMBERS HERE
  // ======================================================

  final List<String> emergencyContacts = [
    "7418809974",
    "9751076974",
  ];

  // ======================================================

  @override
  void initState() {
    super.initState();

    speech = stt.SpeechToText();

    requestPermissions();

    getLocation();

    startShakeDetection();
  }

  Future<void> requestPermissions() async {
    await Permission.location.request();
    await Permission.microphone.request();
    await Permission.sms.request();
  }

  // ======================================================
  // SHAKE DETECTION
  // ======================================================

  void startShakeDetection() {
    ShakeDetector.autoStart(
      onPhoneShake: (ShakeEvent event) {
        sendSOS();
      },
    );
  }

  // ======================================================
  // VOICE SOS
  // ======================================================

  Future<void> startVoiceListening() async {
    bool available = await speech.initialize();

    if (available) {
      speech.listen(
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();

          if (words.contains("help") ||
              words.contains("save me") ||
              words.contains("emergency")) {
            sendSOS();
          }
        },
      );
    }
  }

  // ======================================================
  // LOCATION
  // ======================================================

  Future<void> getLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });
  }

  // ======================================================
  // SEND SOS
  // ======================================================

  Future<void> sendSOS() async {
    setState(() {
      status = "SOS SENT";
    });

    String mapUrl =
        "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";

    for (String number in emergencyContacts) {
      final Uri smsUri = Uri.parse(
        "sms:$number?body=🚨 EMERGENCY! I need help! My location: $mapUrl",
      );

      await launchUrl(smsUri);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚨 SOS Sent Successfully"),
      ),
    );
  }

  // ======================================================
  // UI
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Silent SOS"),
        backgroundColor: Colors.red,
        actions: [
          Switch(
            value: widget.darkMode,
            onChanged: widget.onThemeChanged,
          ),
        ],
      ),

      body: Column(
        children: [
          // ================= MAP =================

          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(latitude, longitude),
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                mapController = controller;
              },
              markers: {
                Marker(
                  markerId: const MarkerId("me"),
                  position: LatLng(latitude, longitude),
                ),
              },
            ),
          ),

          // ================= DETAILS =================

          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "STATUS: $status",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Latitude: $latitude",
                    style: const TextStyle(fontSize: 18),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Longitude: $longitude",
                    style: const TextStyle(fontSize: 18),
                  ),

                  const SizedBox(height: 30),

                  // ================= SOS BUTTON =================

                  ElevatedButton.icon(
                    onPressed: sendSOS,
                    icon: const Icon(Icons.warning),
                    label: const Text("SEND SOS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(250, 60),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ================= VOICE BUTTON =================

                  ElevatedButton.icon(
                    onPressed: startVoiceListening,
                    icon: const Icon(Icons.mic),
                    label: const Text("VOICE SOS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(250, 60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}