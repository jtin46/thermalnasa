import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/thermal_anomaly.dart';
import 'historical_baseline_service.dart';

class DataIngestionService {
  static const String _nasaApiKey = '77bc6f7a09acc13c9577c1cf4224d6d8';

  Future<List<ThermalAnomaly>> loadNasaFirmsData(
      String localAssetPath,
      List<OsmPolygon> contextPolygons,
      HistoricalBaselineService baselineService
      ) async {
    final liveApiUrl = Uri.parse(
        'https://firms.modaps.eosdis.nasa.gov/api/country/csv/$_nasaApiKey/VIIRS_NOAA20_NRT/IND/1'
    );

    try {
      final response = await http.get(liveApiUrl).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && !response.body.contains('Invalid Map Key')) {
        return _parseFirmsCsv(response.body, contextPolygons, baselineService);
      }
    } catch (e) {
      debugPrint('NASA API failed, using local asset fallback.');
    }

    final rawData = await rootBundle.loadString(localAssetPath);
    return _parseFirmsCsv(rawData, contextPolygons, baselineService);
  }

  List<ThermalAnomaly> _parseFirmsCsv(String rawCsv, List<OsmPolygon> contextPolygons, HistoricalBaselineService baselineService) {
    List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(rawCsv);
    List<ThermalAnomaly> anomalies = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 13) continue;

      final lat = double.parse(row[0].toString());
      final lon = double.parse(row[1].toString());
      final bright = double.parse(row[2].toString());

      final confString = row[9].toString().toLowerCase();
      double conf = 50.0;
      if (confString == 'l' || confString == 'low') conf = 30.0;
      if (confString == 'n' || confString == 'nominal') conf = 70.0;
      if (confString == 'h' || confString == 'high') conf = 100.0;
      if (double.tryParse(confString) != null) conf = double.parse(confString);

      final frpVal = double.tryParse(row[12].toString()) ?? 0.0;

      anomalies.add(ThermalAnomaly.classifyEvent(
          lat: lat,
          lon: lon,
          brightness: bright,
          frp: frpVal,
          confidence: conf,
          contextPolygons: contextPolygons,
          baselineService: baselineService
      ));
    }
    return anomalies;
  }
}