import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/platform/printer_persistence_datasource.dart';

class ConnectedPrinterMacNotifier extends Notifier<String?> {
  @override
  String? build() {
    _init();
    return null;
  }

  Future<void> _init() async {
    final persistence = ref.read(printerPersistenceDataSourceProvider);
    final savedMac = await persistence.getLastPrinterMac();
    if (savedMac != null) {
      state = savedMac;
    }
  }

  void setMac(String? mac) async {
    state = mac;
    final persistence = ref.read(printerPersistenceDataSourceProvider);
    if (mac != null) {
      await persistence.saveLastPrinterMac(mac);
    } else {
      await persistence.removeLastPrinterMac();
    }
  }
}

final connectedPrinterMacProvider =
    NotifierProvider<ConnectedPrinterMacNotifier, String?>(() {
  return ConnectedPrinterMacNotifier();
});
