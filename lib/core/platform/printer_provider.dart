import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'printer_service.dart';
import 'printer_adapter_factory.dart';

import '../../features/shared/presentation/viewmodels/printer_notifier.dart';

/// Proveedor global para el servicio de impresora.
/// Utiliza importación condicional para evitar errores de compilación en Web.
final printerServiceProvider = Provider<PrinterService>((ref) {
  return getPrinterAdapter();
});

/// Proveedor que indica si se asume una impresora conectada (tiene MAC guardada).
final printerConnectionProvider = Provider<bool>((ref) {
  final mac = ref.watch(connectedPrinterMacProvider);
  return mac != null;
});
