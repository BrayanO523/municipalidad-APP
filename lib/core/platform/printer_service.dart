abstract class PrinterService {
  /// Stream que emite el estado de conexión de la impresora.
  Stream<bool> get connectionStream;

  /// Obtiene la lista de dispositivos Bluetooth emparejados.
  /// Retorna una lista de mapas con las claves 'name' y 'mac'.
  Future<List<Map<String, dynamic>>> getPairedDevices();

  /// Conecta a una impresora usando su dirección MAC.
  Future<bool> connect(String macAddress);

  /// Desconecta la impresora actual.
  Future<bool> disconnect();

  /// Imprime un comprobante de cobro.
  /// [empresa] Nombre de la municipalidad/empresa.
  /// [local] Nombre del local.
  /// [monto] Monto pagado.
  /// [fecha] Fecha del cobro.
  /// [saldoPendiente] Saldo pendiente restante (si aplica).
  /// [saldoAFavor] Saldo a favor (crédito) adquirido (si aplica).
  /// [cobrador] Nombre del cobrador.
  Future<bool> printReceipt({
    required String empresa,
    String? mercado,
    required String local,
    required double monto,
    required DateTime fecha,
    double? saldoPendiente,
    double? saldoAFavor,
    double? deudaAnterior,
    double? montoAbonadoDeuda,
    String? cobrador,
    required String numeroBoleta,
    required int anioCorrelativo,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? slogan,
  });
}
