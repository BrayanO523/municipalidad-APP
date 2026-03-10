import '../entities/municipalidad.dart';

abstract class MunicipalidadRepository {
  Future<List<Municipalidad>> listarTodas();
  Future<Municipalidad?> obtenerPorId(String id);
  Future<void> sincronizarLocalmente();
}
