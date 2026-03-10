import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/corte.dart';

abstract class CorteRepository {
  Stream<List<Corte>> streamPorMunicipalidad(String municipalidadId);
  Stream<List<Corte>> streamPorCobrador(String cobradorId);
  Future<Either<Failure, void>> crearCorte(Corte corte);
}
