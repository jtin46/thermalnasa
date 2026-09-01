import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../services/historical_baseline_service.dart';

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

  factory ThermalAnomaly.classifyEvent({
    required double lat,
    required double lon,
    required double brightness,
    required double frp,
    required double confidence,
    required List<OsmPolygon> contextPolygons,
    required HistoricalBaselineService baselineService,
  }) {
    final point = LatLng(lat, lon);

    OsmPolygon? closestIndustrial;
    OsmPolygon? matchedLandCover;
    double closestDistanceKm = double.infinity;

    // Scan all polygons for distance and containment
    for (final polygon in contextPolygons) {
      if (polygon.category == 'industrial') {
        double dist = polygon.distanceTo(point);
        if (dist < closestDistanceKm) {
          closestDistanceKm = dist;
          closestIndustrial = polygon;
        }
      } else if (polygon.contains(point)) {
        matchedLandCover = polygon;
      }
    }

    AnomalyType type = AnomalyType.unclassified;
    String? matchedName;

    // FLOWCHART LEFT BRANCH: Is it near an OSM industrial facility? (Buffer: 1.5 km)
    if (closestIndustrial != null && closestDistanceKm <= 1.5) {
      matchedName = closestIndustrial.name;

      // Update historical baseline with this new reading
      baselineService.recordFrpReading(closestIndustrial.id, frp);

      // FLOWCHART: Compare with historical baseline
      if (baselineService.isSuddenIncrease(closestIndustrial.id, frp)) {
        type = AnomalyType.industrialAccident;
      } else {
        type = AnomalyType.industrialFlare;
      }
    }
    // FLOWCHART RIGHT BRANCH: Check land cover (Outside industrial buffer)
    else {
      if (matchedLandCover?.category == 'agriculture' || (frp <= 50 && confidence <= 70)) {
        type = AnomalyType.agriculturalBurn;
      } else if (matchedLandCover?.category == 'forest' || (frp > 50 && confidence > 70)) {
        type = AnomalyType.wildfire;
      } else {
        type = AnomalyType.agriculturalBurn; // Default fallback for open areas
      }
    }

    return ThermalAnomaly(
      id: 'FIRMS_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}',
      location: point,
      brightnessTempKelvin: brightness,
      frp: frp,
      acquisitionTime: DateTime.now(),
      confidence: confidence,
      matchedFacilityName: matchedName,
      classification: type,
    );
  }
}

class OsmPolygon {
  final String id;
  final String name;
  final String category; // 'industrial', 'agriculture', or 'forest'
  final List<LatLng> boundary;

  OsmPolygon({
    required this.id,
    required this.name,
    required this.category,
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

  // Haversine formula to calculate proximity to the polygon's closest boundary vertex
  double distanceTo(LatLng point) {
    const double earthRadiusKm = 6371.0;
    double minDistance = double.infinity;

    for (var vertex in boundary) {
      double dLat = _degreesToRadians(vertex.latitude - point.latitude);
      double dLon = _degreesToRadians(vertex.longitude - point.longitude);

      double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_degreesToRadians(point.latitude)) * math.cos(_degreesToRadians(vertex.latitude)) *
              math.sin(dLon / 2) * math.sin(dLon / 2);

      double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      double distance = earthRadiusKm * c;

      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}