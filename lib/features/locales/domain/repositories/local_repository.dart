import '../entities/local.dart';

abstract class LocalRepository {
  Future<void> syncLocales();
  Stream<List<Local>> streamTodos();
  Stream<List<Local>> streamPorMunicipalidad(String municipalidadId);
  Stream<Local?> streamPorId(String id);
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
  Future<int> recalcularDeudasBasadoEnHistorial();
}
