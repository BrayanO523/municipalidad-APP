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

  @override
  Future<Either<Failure, List<Corte>>> obtenerCortesDiaPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  }) async {
    try {
      final models = await datasource.listarCortesDiaPorMercado(
        mercadoId: mercadoId,
        municipalidadId: municipalidadId,
        fecha: fecha,
      );
      return Right(models);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> existeCorteMercadoHoy({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  }) async {
    try {
      final existe = await datasource.existeCorteMercadoHoy(
        mercadoId: mercadoId,
        municipalidadId: municipalidadId,
        fecha: fecha,
      );
      return Right(existe);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<Corte>> streamCortesDiaPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  }) {
    return datasource.streamCortesDiaPorMercado(
      mercadoId: mercadoId,
      municipalidadId: municipalidadId,
      fecha: fecha,
    );
  }
  @override
  Stream<List<Corte>> streamCortesDiaPorCobrador({
    required String cobradorId,
    required DateTime fecha,
  }) {
    return datasource.streamCortesDiaPorCobrador(
      cobradorId: cobradorId,
      fecha: fecha,
    );
  }
}

