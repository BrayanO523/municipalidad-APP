import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PrinterPersistenceDataSource {
  /// Guarda la dirección MAC de la última impresora conectada.
  Future<void> saveLastPrinterMac(String mac);

  /// Obtiene la dirección MAC de la última impresora conectada.
  Future<String?> getLastPrinterMac();

  /// Elimina la dirección MAC guardada (al desvincular).
  Future<void> removeLastPrinterMac();
}

/// Proveedor para la persistencia de la configuración de la impresora.
/// Debe ser sobreescrito o inicializado con la implementación real.
final printerPersistenceDataSourceProvider = Provider<PrinterPersistenceDataSource>(
  (ref) => throw UnimplementedError(),
);
