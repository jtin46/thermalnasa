import 'package:shared_preferences/shared_preferences.dart';

class HistoricalBaselineService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Updates the historical average FRP for a specific industrial facility
  Future<void> recordFrpReading(String facilityId, double currentFrp) async {
    final key = 'baseline_frp_$facilityId';
    final countKey = 'baseline_count_$facilityId';

    double currentAvg = _prefs.getDouble(key) ?? currentFrp;
    int count = _prefs.getInt(countKey) ?? 1;

    // Calculate rolling average
    double newAvg = ((currentAvg * count) + currentFrp) / (count + 1);

    await _prefs.setDouble(key, newAvg);
    await _prefs.setInt(countKey, count + 1);
  }

  /// Returns the historical average FRP, defaulting to 25.0 MW if no history exists
  double getBaselineFrp(String facilityId) {
    return _prefs.getDouble('baseline_frp_$facilityId') ?? 25.0;
  }

  /// Checks if a current reading is a sudden spike (e.g., > 1.5x the normal baseline)
  bool isSuddenIncrease(String facilityId, double currentFrp) {
    double baseline = getBaselineFrp(facilityId);
    return currentFrp > (baseline * 1.5) || currentFrp > 150.0;
  }
}