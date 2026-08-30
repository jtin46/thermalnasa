import 'package:latlong2/latlong.dart';

enum AnomalyType {
  industrialFlare,
  industrialAccident,
  wildfire,
  agriculturalBurn,
  unclassified
}

class ThermalAnomaly {
  final String id;
  final LatLng location;
  final double brightnessTempKelvin;
  final double frp;
  final DateTime acquisitionTime;
  final double confidence;
  final String? matchedFacilityName;
  final AnomalyType classification;

  ThermalAnomaly({
    required this.id,
    required this.location,
    required this.brightnessTempKelvin,
    required this.frp,
    required this.acquisitionTime,
    required this.confidence,
    this.matchedFacilityName,
    required this.classification,
  });

  double get temperatureCelsius => brightnessTempKelvin - 273.15;

  // AI/Heuristic Risk Scoring (0-100)
  int get riskScore {
    double score = (confidence * 0.4) + ((frp > 200 ? 200 : frp) * 0.3);
    if (classification == AnomalyType.industrialAccident) score += 30;
    if (classification == AnomalyType.wildfire && frp > 100) score += 20;
    return score.clamp(0, 100).toInt();
  }

  String get severity {
    if (riskScore >= 80) return 'CRITICAL';
    if (riskScore >= 60) return 'HIGH';
    if (riskScore >= 40) return 'MEDIUM';
    return 'LOW';
  }

  factory ThermalAnomaly.fromFirmsCsv({
    required double lat,
    required double lon,
    required double brightness,
    required double frp,
    required double confidence,
    required List<IndustrialPolygon> facilities,
  }) {
    final point = LatLng(lat, lon);

    IndustrialPolygon? matched;
    for (final facility in facilities) {
      if (facility.contains(point)) {
        matched = facility;
        break;
      }
    }

    AnomalyType type = AnomalyType.unclassified;
    if (matched != null) {
      type = (frp > 150 || brightness > 380)
          ? AnomalyType.industrialAccident
          : AnomalyType.industrialFlare;
    } else {
      type = (frp > 50 && confidence > 70)
          ? AnomalyType.wildfire
          : AnomalyType.agriculturalBurn;
    }

    return ThermalAnomaly(
      id: 'FIRMS_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}',
      location: point,
      brightnessTempKelvin: brightness,
      frp: frp,
      acquisitionTime: DateTime.now(),
      confidence: confidence,
      matchedFacilityName: matched?.name,
      classification: type,
    );
  }
}

class IndustrialPolygon {
  final String id;
  final String name;
  final String type;
  final List<LatLng> boundary;

  IndustrialPolygon({
    required this.id,
    required this.name,
    required this.type,
    required this.boundary,
  });

  bool contains(LatLng point) {
    int intersectCount = 0;
    for (int j = 0; j < boundary.length; j++) {
      int next = (j + 1) % boundary.length;
      if (_rayCrossesSegment(point, boundary[j], boundary[next])) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  bool _rayCrossesSegment(LatLng point, LatLng a, LatLng b) {
    double px = point.longitude, py = point.latitude;
    double ax = a.longitude, ay = a.latitude;
    double bx = b.longitude, by = b.latitude;

    if (ay > by) {
      ax = b.longitude; ay = b.latitude;
      bx = a.longitude; by = a.latitude;
    }
    if (py <= ay || py > by) return false;
    if (px >= ax && px >= bx) return false;
    if (px < ax && px < bx) return true;

    double edgeSlope = (by - ay) / (bx - ax);
    double pointSlope = (py - ay) / (px - ax);
    return pointSlope >= edgeSlope;
  }
}