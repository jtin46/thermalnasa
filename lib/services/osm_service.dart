import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/thermal_anomaly.dart';

class OsmService {
  // We query a bounding box around the densest thermal anomalies in your dataset
  Future<List<IndustrialPolygon>> fetchIndustrialZones() async {
    const String overpassUrl = 'https://overpass-api.de/api/interpreter';

    // OSM Query: Find industrial landuse and power plants within a specific bounding box
    const String query = '''
      [out:json];
      (
        way["landuse"="industrial"](20.0, 84.0, 25.0, 89.0);
        way["power"="plant"](20.0, 84.0, 25.0, 89.0);
      );
      out geom;
    ''';

    try {
      final response = await http.post(Uri.parse(overpassUrl), body: query);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<IndustrialPolygon> facilities = [];

        for (var element in data['elements']) {
          if (element['type'] == 'way' && element['geometry'] != null) {
            List<LatLng> boundary = [];
            for (var geo in element['geometry']) {
              boundary.add(LatLng(geo['lat'], geo['lon']));
            }
            facilities.add(IndustrialPolygon(
              id: element['id'].toString(),
              name: element['tags']?['name'] ?? 'Unknown Industrial Facility',
              type: element['tags']?['power'] ?? element['tags']?['landuse'] ?? 'Industrial',
              boundary: boundary,
            ));
          }
        }
        return facilities;
      }
    } catch (e) {
      // In a production app, handle network errors here
    }
    return [];
  }
}