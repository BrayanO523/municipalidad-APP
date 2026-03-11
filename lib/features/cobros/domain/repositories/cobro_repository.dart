import '../entities/cobro.dart';

abstract class CobroRepository {
  Future<void> syncCobros();
  Stream<List<Cobro>> streamRecientes({
    String? municipalidadId,
    String? mercadoId,
  });
  Stream<List<Cobro>> streamPorRangoFechas(
    DateTime inicio,
    DateTime fin, {
    String? municipalidadId,
    String? mercadoId,
  });
  Stream<List<Cobro>> streamPorFecha(
    DateTime fecha, {
    String? municipalidadId,
    String? mercadoId,
  });
  Stream<List<Cobro>> streamPorLocal(String localId);
  Future<void> registrarCobroLocalmente(Cobro cobro);

  /// Intenta conseguir correlativo online (0 si offline),
  /// aplica FIFO sobre el historial de cobros pendientes del local
  /// y retorna la boleta generada + la lista de fechas históricas saldadas.
  Future<({String numeroBoleta, List<DateTime> fechasSaldadas})> registrarCobroCompleto(
    Cobro cobro,
    String localId, {
    num montoAbonadoDeuda,
  });

  /// Elimina un cobro y revierte su impacto financiero en el local (deuda/saldo).
  Future<void> eliminarCobro(Cobro cobro);
}
