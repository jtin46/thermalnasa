import 'package:flutter/material.dart';

class IotSetupScreen extends StatefulWidget {
  const IotSetupScreen({super.key});

  @override
  State<IotSetupScreen> createState() => _IotSetupScreenState();
}

class _IotSetupScreenState extends State<IotSetupScreen> {
  bool _isScanning = false;

  void _simulateScan() {
    setState(() => _isScanning = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF181A20),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E222D),
          foregroundColor: Colors.white,
          title: const Text('Connect Hardware'),
          bottom: const TabBar(
            indicatorColor: Colors.deepOrange,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth Pair'),
              Tab(icon: Icon(Icons.wifi), text: 'Wi-Fi Provision'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBluetoothTab(),
            _buildWifiTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_searching, size: 80, color: _isScanning ? Colors.blueAccent : Colors.white24),
          const SizedBox(height: 24),
          Text(
            _isScanning ? 'Scanning for nearby sensors...' : 'Pair a new Thermal Sensor via BLE',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 32),
          if (!_isScanning)
            ElevatedButton(
              onPressed: _simulateScan,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              child: const Text('Scan Devices', style: TextStyle(color: Colors.white)),
            ),
          if (!_isScanning) ...[
            const SizedBox(height: 32),
            ListTile(
              tileColor: const Color(0xFF252A34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.memory, color: Colors.white),
              title: const Text('THERMAL_ESP32_01', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Tap to pair & assign facility', style: TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => Navigator.pop(context), // Returns to map after pairing
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildWifiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Provision Sensor to Wi-Fi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Enter local network details to connect the hardware to the MQTT broker.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Wi-Fi SSID',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF252A34),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Wi-Fi Password',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF252A34),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provisioning sent to device...')));
              Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
            },
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('Send Credentials to Hardware', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}