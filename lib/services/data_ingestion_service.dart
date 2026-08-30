import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import '../models/thermal_anomaly.dart'; // From previous architecture

class DataIngestionService {
  Future<List<ThermalAnomaly>> loadNasaFirmsData(String assetPath, List<IndustrialPolygon> facilities) async {
    final rawData = await rootBundle.loadString(assetPath);
    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter(eol: '\n').convert(rawData);

    List<ThermalAnomaly> anomalies = [];

    // Skip header row (index 0)
    for (int i = 1; i < rowsAsListOfValues.length; i++) {
      final row = rowsAsListOfValues[i];
      if (row.length < 13) continue; // Ensure row has all FIRMS columns

      // Columns based on uploaded fire_nrt_J2V-C2_793578.csv:
      // latitude[0], longitude[1], brightness[2], scan[3], track[4], acq_date[5], acq_time[6], satellite[7], instrument[8], confidence[9], version[10], bright_t31[11], frp[12], daynight[13]
      final lat = double.parse(row[0].toString());
      final lon = double.parse(row[1].toString());
      final bright = double.parse(row[2].toString());

      // Some confidence values are missing or character-based ('N', 'H') depending on the satellite (VIIRS vs MODIS).
      final confString = row[9].toString();
      double conf = 50.0;
      if (confString == 'l' || confString == 'low') conf = 30.0;
      if (confString == 'n' || confString == 'nominal') conf = 70.0;
      if (confString == 'h' || confString == 'high') conf = 100.0;
      if (double.tryParse(confString) != null) conf = double.parse(confString);

      final frpVal = double.tryParse(row[12].toString()) ?? 0.0;

      anomalies.add(ThermalAnomaly.fromFirmsCsv(
          lat: lat,
          lon: lon,
          brightness: bright,
          frp: frpVal,
          confidence: conf,
          facilities: facilities
      ));
    }

    return anomalies;
  }
}