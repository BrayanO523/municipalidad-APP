import '../entities/local.dart';

abstract class LocalRepository {
  Future<void> syncLocales();
  Stream<List<Local>> streamTodos();
  Stream<List<Local>> streamPorMunicipalidad(String municipalidadId);
  Stream<Local?> streamPorId(String id);
  Future<Local?> obtenerPorId(String id);
  Future<void> procesarPagoOfflineSafe(
    String localId,
    num abonoDeuda,
    num incrementoSaldo,
  );
  Future<void> revertirPago({
    required String localId,
    required num montoARecomponerDeuda,
    required num montoARestarSaldo,
  });
  Future<List<Local>> obtenerPorMercado(String mercadoId);
  Future<int> recalcularDeudasBasadoEnHistorial();
  Future<void> actualizarLocal(Local local, {num deltaCuota = 0, num deltaDeuda = 0});
  Future<void> ajustarDeudaManual({
    required String localId,
    required num nuevaDeuda,
    required num deudaAnterior,
    required String municipalidadId,
    bool esPago = true,
  });
  Future<void> crearLocal(Local local);
}
