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
  /// guarda en caché, actualiza Hive (NoSQL) con el resultado y marca el localHistoria.
  Future<String> registrarCobroCompleto(Cobro cobro, String localId);

  /// Elimina un cobro y revierte su impacto financiero en el local (deuda/saldo).
  Future<void> eliminarCobro(Cobro cobro);
}
