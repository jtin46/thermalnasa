import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/thermal_anomaly.dart';

class OsmService {
  Future<List<OsmPolygon>> fetchGeospatialContext() async {
    const String overpassUrl = 'https://overpass-api.de/api/interpreter';

    // Expanded query covering Industry, Farmland, and Forests
    const String query = '''
      [out:json][timeout:25];
      (
        way["landuse"="industrial"](20.0, 84.0, 25.0, 89.0);
        way["power"="plant"](20.0, 84.0, 25.0, 89.0);
        way["landuse"="farmland"](20.0, 84.0, 25.0, 89.0);
        way["natural"="wood"](20.0, 84.0, 25.0, 89.0);
      );
      out geom;
    ''';

    try {
      final response = await http.post(Uri.parse(overpassUrl), body: query);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<OsmPolygon> polygons = [];

        for (var element in data['elements']) {
          if (element['type'] == 'way' && element['geometry'] != null) {
            List<LatLng> boundary = [];
            for (var geo in element['geometry']) {
              boundary.add(LatLng(geo['lat'], geo['lon']));
            }

            String category = 'agriculture';
            if (element['tags']?['landuse'] == 'industrial' || element['tags']?.containsKey('power') == true) {
              category = 'industrial';
            } else if (element['tags']?['natural'] == 'wood') {
              category = 'forest';
            }

            polygons.add(OsmPolygon(
              id: element['id'].toString(),
              name: element['tags']?['name'] ?? 'Unknown $category Area',
              category: category,
              boundary: boundary,
            ));
          }
        }
        return polygons;
      }
    } catch (e) {
      // Handle network errors silently
    }
    return [];
  }
}