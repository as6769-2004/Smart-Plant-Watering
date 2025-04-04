import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  _SoilMonitoringPageState createState() => _SoilMonitoringPageState();
}

class _SoilMonitoringPageState extends State<SoilMonitoringPage> {
  String ip = "192.168.104.51";
  bool isConnected = false;
  String selectedMode = "Fetching...";

  @override
  void initState() {
    super.initState();
    _checkConnection(ip).then((success) {
      setState(() {
        isConnected = success;
        if (success) _fetchMode();
      });
    });
  }

  void _setIP() {
    TextEditingController ipController = TextEditingController(text: ip);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Set IP Address"),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(hintText: "Enter IP Address"),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String newIp = ipController.text.trim();
                if (newIp.isNotEmpty) {
                  bool success = await _checkConnection(newIp);
                  setState(() {
                    ip = newIp;
                    isConnected = success;
                    if (success) _fetchMode();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkConnection(String ip) async {
    try {
      final response = await http.get(Uri.parse("http://$ip/moisture"));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _fetchMode() {
    http
        .get(Uri.parse("http://$ip/mode/status"))
        .then((response) {
          if (response.statusCode == 200) {
            setState(() {
              selectedMode =
                  response.body.trim() == "0" ? "Automatic" : "Manual";
            });
          }
        })
        .catchError((_) {
          setState(() => selectedMode = "Unknown");
        });
  }

  void _setMode(bool manual) {
    String url = manual ? "http://$ip/mode/manual" : "http://$ip/mode/auto";
    http
        .get(Uri.parse(url))
        .then((response) {
          if (response.statusCode == 200) {
            setState(() {
              selectedMode = manual ? "Manual" : "Automatic";
            });
          }
        })
        .catchError((_) {});
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
            Row(
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
            ),
            const SizedBox(height: 20),
            Text(
              'IP Address: $ip',
              style: const TextStyle(fontSize: 16, color: Colors.white),
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
            Container(
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
