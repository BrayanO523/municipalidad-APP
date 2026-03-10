import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/platform/printer_persistence_datasource.dart';

class PrinterPersistenceLocalDataSource implements PrinterPersistenceDataSource {
  static const String _keyMac = 'last_connected_printer_mac';

  @override
  Future<void> saveLastPrinterMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMac, mac);
  }

  @override
  Future<String?> getLastPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMac);
  }

  @override
  Future<void> removeLastPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMac);
  }
}
