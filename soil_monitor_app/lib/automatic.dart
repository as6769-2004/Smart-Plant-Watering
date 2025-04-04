import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AutomaticPage extends StatefulWidget {
  final String ip;

  const AutomaticPage({super.key, required this.ip});

  @override
  State<AutomaticPage> createState() => _AutomaticPageState();
}

class _AutomaticPageState extends State<AutomaticPage> {
  String controlMode = "---";
  int dryThreshold = 20;
  int wetThreshold = 50;
  double moistureLevel = 0.0;

  Timer? controlModeTimer;
  Timer? moistureTimer;
  Timer? saveTimer;

  late String apiUrl;
  late TextEditingController dryController;
  late TextEditingController wetController;

  @override
  void initState() {
    super.initState();
    apiUrl = "http://${widget.ip}";

    dryController = TextEditingController(text: dryThreshold.toString());
    wetController = TextEditingController(text: wetThreshold.toString());

    _loadLocalThresholds();
    _loadInitialState();
    _startLiveUpdates();
  }

  void _startLiveUpdates() {
    _fetchControlMode();
    _fetchMoisture();

    controlModeTimer?.cancel();
    controlModeTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      _fetchControlMode();
    });

    moistureTimer?.cancel();
    moistureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchMoisture();
    });
  }

  Future<void> _fetchControlMode() async {
    try {
      final response = await http
          .get(Uri.parse("$apiUrl/mode/status"))
          .timeout(const Duration(milliseconds: 500));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          controlMode = response.body.trim() == '0' ? "Automatic" : "Manual";
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMoisture() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/moisture"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            moistureLevel = double.tryParse(data['moisture'].toString()) ?? 0.0;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveThresholds() async {
    try {
      final response = await http.get(
        Uri.parse(
          "$apiUrl/thresholds/save?dry=$dryThreshold&wet=$wetThreshold",
        ),
      );
      if (response.statusCode == 200) {
        await _saveLocalThresholds();
      }
    } catch (_) {}
  }

  void _onThresholdChanged(String value, bool isDry) {
    int? newThreshold = int.tryParse(value);
    if (newThreshold == null) return;

    setState(() {
      if (isDry) {
        dryThreshold = newThreshold;
        dryController.text = newThreshold.toString();
      } else {
        wetThreshold = newThreshold;
        wetController.text = newThreshold.toString();
      }
    });

    _saveLocalThresholds();

    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveThresholds();
    });
  }

  Future<void> _loadInitialState() async {
    try {
      final modeResponse = await http
          .get(Uri.parse("$apiUrl/mode/status"))
          .timeout(const Duration(seconds: 2));
      final thresholdResponse = await http
          .get(Uri.parse("$apiUrl/thresholds/get"))
          .timeout(const Duration(seconds: 2));

      if (modeResponse.statusCode == 200) {
        setState(() {
          controlMode =
              modeResponse.body.trim() == '0' ? "Automatic" : "Manual";
        });
      }

      if (thresholdResponse.statusCode == 200) {
        final data = json.decode(thresholdResponse.body);
        if (data['dry'] != null && data['wet'] != null) {
          setState(() {
            dryThreshold = data['dry'];
            wetThreshold = data['wet'];
            dryController.text = dryThreshold.toString();
            wetController.text = wetThreshold.toString();
          });
          await _saveLocalThresholds();
        }
      }
    } catch (_) {
      setState(() => controlMode = "Error loading state");
    }
  }

  Future<void> _saveLocalThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dryThreshold', dryThreshold);
    await prefs.setInt('wetThreshold', wetThreshold);
  }

  Future<void> _loadLocalThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      dryThreshold = prefs.getInt('dryThreshold') ?? dryThreshold;
      wetThreshold = prefs.getInt('wetThreshold') ?? wetThreshold;
      dryController.text = dryThreshold.toString();
      wetController.text = wetThreshold.toString();
    });
  }

  @override
  void dispose() {
    controlModeTimer?.cancel();
    moistureTimer?.cancel();
    saveTimer?.cancel();
    dryController.dispose();
    wetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatic Mode'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Automatic Control',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 200,
                ), // Reduced animation duration
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Column(
                  key: ValueKey(moistureLevel), // Key the Column now
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Moisture Level:",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${moistureLevel.toStringAsFixed(2)}%",
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                'Control Mode: $controlMode',
                key: ValueKey(controlMode),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text("Dry Threshold"),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: dryController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _onThresholdChanged(value, true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    const Text("Wet Threshold"),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: wetController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _onThresholdChanged(value, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
