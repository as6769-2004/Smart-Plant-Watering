import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ManualPage extends StatefulWidget {
  final String ip;
  const ManualPage({super.key, required this.ip});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  double moistureLevel = 0.0;
  bool isPumpOn = false; // Added for displaying pump status
  late String apiUrl;
  Timer? moistureTimer;

  @override
  void initState() {
    super.initState();
    apiUrl = "http://${widget.ip}";
    _startLiveUpdates();
  }

  Future<void> _fetchMoisture() async {
    try {
      final response = await http
          .get(Uri.parse("$apiUrl/moisture"))
          .timeout(const Duration(milliseconds: 200));

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

  void _startLiveUpdates() {
    _fetchMoisture();

    moistureTimer?.cancel();
    moistureTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _fetchMoisture();
    });
  }

  void _controlPump(bool turnOn) {
    String endpoint = turnOn ? "/pump/start" : "/pump/stop";

    http
        .get(Uri.parse("$apiUrl$endpoint"))
        .then((response) {
          if (mounted && response.statusCode == 200) {
            setState(() {
              isPumpOn = turnOn; // Update status manually based on button press
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    moistureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Mode'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Manual Control',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Column(
                  key: ValueKey(moistureLevel),
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
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Pump Status: ",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  isPumpOn ? "ON" : "OFF",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPumpOn ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _controlPump(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(130, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Start Pump',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _controlPump(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(130, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Stop Pump',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
