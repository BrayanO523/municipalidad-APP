import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'printer_service.dart';
import 'printer_adapter_factory.dart';

/// Proveedor global para el servicio de impresora.
/// Utiliza importación condicional para evitar errores de compilación en Web.
final printerServiceProvider = Provider<PrinterService>((ref) {
  return getPrinterAdapter();
});

/// Stream que indica si hay una impresora conectada actualmente.
final printerConnectionProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.connectionStream;
});
