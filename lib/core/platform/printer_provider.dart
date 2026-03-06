import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'printer_service.dart';
import 'stub_printer_adapter.dart'
    if (dart.library.io) 'bluetooth_printer_adapter.dart';

/// Proveedor global para el servicio de impresora.
/// Utiliza importación condicional para evitar errores de compilación en Web.
final printerServiceProvider = Provider<PrinterService>((ref) {
  return getPrinterAdapter();
});

class ConnectedPrinterMacNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMac(String? mac) {
    state = mac;
  }
}

/// Guarda la dirección MAC de la impresora Bluetooth vinculada.
final connectedPrinterMacProvider =
    NotifierProvider<ConnectedPrinterMacNotifier, String?>(() {
      return ConnectedPrinterMacNotifier();
    });
