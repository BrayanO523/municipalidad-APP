import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/corte_datasource.dart';
import '../../domain/entities/corte.dart';
import '../../domain/repositories/corte_repository.dart';
import '../models/corte_model.dart';

class CorteRepositoryImpl implements CorteRepository {
  final CorteDatasource datasource;

  CorteRepositoryImpl(this.datasource);

  @override
  Stream<List<Corte>> streamPorMunicipalidad(String municipalidadId) {
    return datasource.streamPorMunicipalidad(municipalidadId);
  }

  @override
  Stream<List<Corte>> streamPorCobrador(String cobradorId) {
    return datasource.streamPorCobrador(cobradorId);
  }

  @override
  Future<Either<Failure, void>> crearCorte(Corte corte) async {
    try {
      final model = CorteModel.fromEntity(corte);
      await datasource.crearCorte(model);
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
