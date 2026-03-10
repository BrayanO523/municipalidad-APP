import '../entities/mercado.dart';

abstract class MercadoRepository {
  Future<void> syncMercados();
  Stream<List<Mercado>> streamTodos();
  Stream<List<Mercado>> streamPorMunicipalidad(String municipalidadId);
  Future<List<Mercado>> obtenerTodosOffline();
  Future<Mercado?> obtenerPorId(String id);
}
