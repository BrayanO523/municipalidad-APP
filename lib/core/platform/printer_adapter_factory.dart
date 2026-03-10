import '../../features/shared/data/adapters/stub_printer_adapter.dart'
    if (dart.library.io) '../../features/shared/data/adapters/bluetooth_printer_adapter.dart';


import 'printer_service.dart';

/// Función de exportación condicional que devuelve la implementación correcta.
PrinterService getPrinterAdapter() {
  // Las implementaciones reales están en los archivos importados condicionalmente
  // y deben definir una clase que herede de PrinterService.
  return getPlatformPrinterAdapter();
}
