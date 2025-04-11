import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

import 'manual.dart';
import 'automatic.dart';

void main() {
  runApp(const SoilMonitoringApp());
}

class SoilMonitoringApp extends StatelessWidget {
  const SoilMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121E2F),
      ),
      home: const SoilMonitoringPage(),
    );
  }
}

class SoilMonitoringPage extends StatefulWidget {
  const SoilMonitoringPage({super.key});

  @override
  State<SoilMonitoringPage> createState() => _SoilMonitoringPageState();
}

class _SoilMonitoringPageState extends State<SoilMonitoringPage> {
  String ip = "192.168.104.51";
  bool isConnected = false;
  String selectedMode = "Fetching...";
  String moistureLevel = "Fetching...";
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  void _initializeConnection() async {
    final success = await _checkConnection(ip);
    if (!mounted) return;
    setState(() => isConnected = success);

    if (success) {
      _fetchMode();
      _fetchMoisture();
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isConnected) {
        _fetchMode();
        _fetchMoisture();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<bool> _checkConnection(String ip) async {
    try {
      final response = await http.get(Uri.parse("http://$ip/moisture"));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _setIP() {
    final ipController = TextEditingController(text: ip);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Set IP Address"),
            content: TextField(
              controller: ipController,
              decoration: const InputDecoration(hintText: "Enter IP Address"),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final newIp = ipController.text.trim();
                  if (newIp.isNotEmpty) {
                    final success = await _checkConnection(newIp);
                    if (!mounted) return;
                    setState(() {
                      ip = newIp;
                      isConnected = success;
                    });
                    if (success) {
                      _fetchMode();
                      _fetchMoisture();
                      _startPolling();
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  Future<void> _fetchMode() async {
    try {
      final response = await http.get(Uri.parse("http://$ip/mode/status"));
      if (response.statusCode == 200) {
        final mode = response.body.trim();
        if (!mounted) return;
        setState(() => selectedMode = mode == "0" ? "Automatic" : "Manual");
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => selectedMode = "Unknown");
    }
  }

  Future<void> _fetchMoisture() async {
    try {
      final response = await http.get(Uri.parse("http://$ip/moisture"));
      if (response.statusCode == 200) {
        if (!mounted) return;
        final raw = response.body.trim();
        final match = RegExp(r"[-+]?[0-9]*\.?[0-9]+").firstMatch(raw);
        if (match != null) {
          double value = double.parse(match.group(0)!);
          if (value < 0) value = 0;
          setState(() => moistureLevel = "${value.toStringAsFixed(1)}%");
        } else {
          setState(() => moistureLevel = "Unavailable");
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => moistureLevel = "Unavailable");
    }
  }

  Future<void> _setMode(bool toManual) async {
    final url = toManual ? "http://$ip/mode/manual" : "http://$ip/mode/auto";
    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200) {
        _fetchMode();
      }
    } catch (_) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soil Monitoring System'),
        backgroundColor: Colors.blueGrey[900],
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _setIP),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 20),
            Text(
              'IP Address: $ip',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder:
                  (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
              child: Text(
                moistureLevel,
                key: ValueKey(moistureLevel),
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Current Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              selectedMode,
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            _buildModeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Connection Status:',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 10,
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildModeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildModeButton(
            label: 'Automatic Mode',
            color: Colors.green,
            mode: "Automatic",
            page: AutomaticPage(ip: ip),
          ),
          const SizedBox(height: 15),
          _buildModeButton(
            label: 'Manual Mode',
            color: Colors.orange,
            mode: "Manual",
            page: ManualPage(ip: ip),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed:
                isConnected
                    ? () => _setMode(selectedMode == "Automatic")
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              selectedMode == "Automatic"
                  ? "Switch to Manual Mode"
                  : "Switch to Automatic Mode",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required Color color,
    required String mode,
    required Widget page,
  }) {
    return ElevatedButton(
      onPressed:
          isConnected
              ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => page),
                );
              }
              : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.grey,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
