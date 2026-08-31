import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/thermal_anomaly.dart';
import '../services/iot_sensor_service.dart';
import '../services/data_ingestion_service.dart';
import '../services/osm_service.dart';
import 'alerts_dashboard.dart';
import 'iot_setup_screen.dart'; // Import the new hardware setup screen

class GisMonitoringScreen extends StatefulWidget {
  const GisMonitoringScreen({super.key});

  @override
  State<GisMonitoringScreen> createState() => _GisMonitoringScreenState();
}

class _GisMonitoringScreenState extends State<GisMonitoringScreen> {
  final MapController _mapController = MapController();
  bool _showIndustrialOnly = false;
  bool _showIoTSensors = true;
  int _currentIndex = 0;

  List<ThermalAnomaly> _firmsAnomalies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataset();
  }

  Future<void> _loadDataset() async {
    final ingestionService = DataIngestionService();
    final osmService = OsmService();

    try {
      final facilities = await osmService.fetchIndustrialZones();
      final anomalies = await ingestionService.loadNasaFirmsData(
          'assets/fire_nrt_J2V-C2_793578.csv',
          facilities
      );

      if (mounted) {
        setState(() {
          _firmsAnomalies = anomalies;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Data Load Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getMarkerColor(AnomalyType type) {
    switch (type) {
      case AnomalyType.industrialFlare:
        return Colors.orangeAccent;
      case AnomalyType.industrialAccident:
        return Colors.redAccent;
      case AnomalyType.wildfire:
        return Colors.deepOrange;
      case AnomalyType.agriculturalBurn:
        return Colors.amber;
      case AnomalyType.unclassified:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GIS Thermal Intelligence'),
        backgroundColor: const Color(0xFF1E222D),
        foregroundColor: Colors.white,
        actions: _currentIndex == 0 ? [
          IconButton(
            icon: Icon(_showIndustrialOnly ? Icons.factory : Icons.filter_alt),
            tooltip: 'Toggle Industrial Filter',
            onPressed: () => setState(() => _showIndustrialOnly = !_showIndustrialOnly),
          ),
          IconButton(
            icon: Icon(_showIoTSensors ? Icons.sensors : Icons.sensors_off),
            tooltip: 'Toggle IoT Sensors',
            onPressed: () => setState(() => _showIoTSensors = !_showIoTSensors),
          ),
        ] : [],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IotSetupScreen()),
          );
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add_chart, color: Colors.white),
        label: const Text('Connect IoT Sensor', style: TextStyle(color: Colors.white)),
      ) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : IndexedStack(
        index: _currentIndex,
        children: [
          _buildMapView(context),
          AlertsDashboard(anomalies: _firmsAnomalies),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E222D),
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Live GIS Map'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_rounded), label: 'Alerts & Events'),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    final iotService = Provider.of<IoTSensorService>(context);
    final displayedAnomalies = _showIndustrialOnly
        ? _firmsAnomalies.where((a) => a.classification == AnomalyType.industrialFlare || a.classification == AnomalyType.industrialAccident).toList()
        : _firmsAnomalies;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(22.38, 87.28),
            initialZoom: 6.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.thermal_sentinel',
            ),
            MarkerLayer(
              markers: displayedAnomalies.map((anomaly) {
                return Marker(
                  point: anomaly.location,
                  width: 12,
                  height: 12,
                  child: GestureDetector(
                    onTap: () => _showAnomalyDetails(context, anomaly),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getMarkerColor(anomaly.classification).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_showIoTSensors)
              MarkerLayer(
                markers: iotService.sensors.values.map((sensor) {
                  return Marker(
                    point: sensor.coordinates,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showSensorDetails(context, sensor),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sensor.alertActive ? Colors.red : Colors.blueAccent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.sensors, color: Colors.white, size: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        _buildClassificationLegend(),
      ],
    );
  }

  Widget _buildClassificationLegend() {
    return Positioned(
      bottom: 24,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E222D).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Classification Overlay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _legendItem(Colors.orangeAccent, 'Industrial Flare/Process'),
            _legendItem(Colors.redAccent, 'Industrial Thermal Anomaly'),
            _legendItem(Colors.deepOrange, 'Wildfire / Forest Fire'),
            _legendItem(Colors.amber, 'Agricultural Burn'),
            _legendItem(Colors.blueAccent, 'IoT Ground Sensor'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  void _showAnomalyDetails(BuildContext context, ThermalAnomaly anomaly) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252A34),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detection ID: ${anomaly.id}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text('Risk: ${anomaly.riskScore}/100', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('Classification: ${anomaly.classification.name}', style: TextStyle(color: _getMarkerColor(anomaly.classification), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Satellite Temp: ${anomaly.temperatureCelsius.toStringAsFixed(1)} °C (${anomaly.brightnessTempKelvin} K)', style: const TextStyle(color: Colors.white70)),
            Text('Fire Radiative Power (FRP): ${anomaly.frp} MW', style: const TextStyle(color: Colors.white70)),
            Text('Facility Matched: ${anomaly.matchedFacilityName ?? "None (Open Area)"}', style: const TextStyle(color: Colors.white70)),
            Text('Confidence Score: ${anomaly.confidence}%', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  void _showSensorDetails(BuildContext context, IoTSensorNode sensor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252A34),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sensor: ${sensor.deviceId}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Facility: ${sensor.facilityName}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
            Text('Live Ground Temperature: ${sensor.liveTemperatureCelsius} °C', style: TextStyle(color: sensor.alertActive ? Colors.redAccent : Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Last Heartbeat: ${sensor.lastUpdated.toLocal()}', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}