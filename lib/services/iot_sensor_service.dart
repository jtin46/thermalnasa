import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class IoTSensorNode {
  final String deviceId;
  final String facilityName;
  final LatLng coordinates;
  double liveTemperatureCelsius;
  DateTime lastUpdated;
  bool alertActive;

  IoTSensorNode({
    required this.deviceId,
    required this.facilityName,
    required this.coordinates,
    required this.liveTemperatureCelsius,
    required this.lastUpdated,
    this.alertActive = false,
  });
}

class IoTSensorService extends ChangeNotifier {
  final Map<String, IoTSensorNode> _sensors = {};
  late MqttServerClient _client;

  Map<String, IoTSensorNode> get sensors => _sensors;

  void initializeSensors() async {
    // Connect to a public test broker (Replace with your own AWS/HiveMQ broker later)
    _client = MqttServerClient('test.mosquitto.org', 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    _client.port = 1883;
    _client.logging(on: false);
    _client.keepAlivePeriod = 60;

    // Add some default registered sensors for testing
    _sensors['IOT_REF_01'] = IoTSensorNode(
      deviceId: 'IOT_REF_01',
      facilityName: 'PetroChem Unit Alpha',
      coordinates: const LatLng(19.0760, 72.8777),
      liveTemperatureCelsius: 185.0,
      lastUpdated: DateTime.now(),
    );

    try {
      await _client.connect();
      debugPrint('MQTT Connected Successfully');

      // Subscribe to the global topic for all sensors
      _client.subscribe('thermal_sentinel/telemetry/#', MqttQos.atLeastOnce);

      _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);

        // Expected payload from hardware: {"device_id": "IOT_REF_01", "temp": 210.5}
        _updateSensorData(payload);
      });
    } catch (e) {
      debugPrint('MQTT Connection Failed: $e');
    }
  }

  void registerSensor(IoTSensorNode sensor) {
    _sensors[sensor.deviceId] = sensor;
    notifyListeners();
  }

  void _updateSensorData(String jsonPayload) {
    try {
      final data = json.decode(jsonPayload);
      final deviceId = data['device_id'];
      final temp = (data['temp'] as num).toDouble();

      if (_sensors.containsKey(deviceId)) {
        _sensors[deviceId]!.liveTemperatureCelsius = temp;
        _sensors[deviceId]!.lastUpdated = DateTime.now();
        _sensors[deviceId]!.alertActive = temp > 350.0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Invalid telemetry payload: $jsonPayload');
    }
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }
}