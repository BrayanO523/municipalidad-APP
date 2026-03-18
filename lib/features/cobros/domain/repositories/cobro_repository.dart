import '../entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

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
    num? incrementoSaldoFavor,
    DateTime? fechaReferenciaMora,
  });

  /// Elimina un cobro y revierte su impacto financiero en el local (deuda/saldo).
  Future<void> eliminarCobro(Cobro cobro);

  /// Registra deudas pendientes para un local en un rango de fechas.
  Future<int> registrarDeudaPorRango({
    required Local local,
    required DateTime start,
    required DateTime end,
    required String? cobradorId,
  });
}
