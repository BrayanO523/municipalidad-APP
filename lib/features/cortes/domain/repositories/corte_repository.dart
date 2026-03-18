import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/corte.dart';

abstract class CorteRepository {
  Stream<List<Corte>> streamPorMunicipalidad(String municipalidadId);
  Stream<List<Corte>> streamPorCobrador(String cobradorId);
  Future<Either<Failure, void>> crearCorte(Corte corte);
  Future<Either<Failure, void>> eliminarCorte(String id);
  Future<Either<Failure, List<Corte>>> obtenerCortesDiaPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  });
  Future<Either<Failure, bool>> existeCorteMercadoHoy({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  });
  Stream<List<Corte>> streamCortesDiaPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  });
  Stream<List<Corte>> streamCortesRangoPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime desde,
    required DateTime hasta,
  });
  Stream<List<Corte>> streamCortesDiaPorCobrador({
    required String cobradorId,
    required DateTime fecha,
  });
}


