import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'services/iot_sensor_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IoTSensorService()..initializeSensors()),
      ],
      child: const ThermalSentinelApp(),
    ),
  );
}

class ThermalSentinelApp extends StatelessWidget {
  const ThermalSentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermal Sentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181A20),
        primarySwatch: Colors.deepOrange,
      ),
      home: const LoginScreen(),
    );
  }
}