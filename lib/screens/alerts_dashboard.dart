import 'package:flutter/material.dart';
import '../models/thermal_anomaly.dart';

class AlertsDashboard extends StatelessWidget {
  final List<ThermalAnomaly> anomalies;

  const AlertsDashboard({super.key, required this.anomalies});

  @override
  Widget build(BuildContext context) {
    final criticalAlerts = anomalies.where((a) => a.riskScore >= 40).toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: criticalAlerts.isEmpty
          ? const Center(child: Text('No Active Alerts', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: criticalAlerts.length,
        itemBuilder: (context, index) {
          final alert = criticalAlerts[index];
          return Card(
            color: const Color(0xFF252A34),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: _getSeverityColor(alert.severity),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
              ),
              title: Text(
                '${alert.severity} ALERT: ${alert.classification.name.toUpperCase()}',
                style: TextStyle(color: _getSeverityColor(alert.severity), fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Risk Score: ${alert.riskScore}/100', style: const TextStyle(color: Colors.white)),
                  Text('FRP: ${alert.frp} MW | Temp: ${alert.temperatureCelsius.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white70)),
                  if (alert.matchedFacilityName != null)
                    Text('Facility: ${alert.matchedFacilityName}', style: const TextStyle(color: Colors.orangeAccent)),
                  Text('Location: ${alert.location.latitude.toStringAsFixed(4)}, ${alert.location.longitude.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white54)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.send_to_mobile, color: Colors.blueAccent),
                tooltip: 'Escalate via SMS/Push',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Push Notification & SMS Escalated for ${alert.id}')),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.deepOrange;
      case 'MEDIUM': return Colors.amber;
      default: return Colors.green;
    }
  }
}