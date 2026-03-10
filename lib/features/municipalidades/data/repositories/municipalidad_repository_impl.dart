import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/municipalidad.dart';
import '../../domain/repositories/municipalidad_repository.dart';
import '../datasources/municipalidad_datasource.dart';
import '../datasources/municipalidad_local_datasource.dart';
import '../models/hive/municipalidad_hive.dart';

class MunicipalidadRepositoryImpl implements MunicipalidadRepository {
  final MunicipalidadDatasource _remoteDatasource;
  final MunicipalidadLocalDatasource _localDatasource;
  final Connectivity _connectivity;

  MunicipalidadRepositoryImpl(
    this._remoteDatasource,
    this._localDatasource,
    this._connectivity,
  );

  Future<bool> _hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  @override
  Future<List<Municipalidad>> listarTodas() async {
    if (await _hasConnection()) {
      try {
        final remote = await _remoteDatasource.listarTodas();
        // Sincronizar localmente (Cachear)
        final hives = remote
            .map((m) => MunicipalidadHive.fromDomain(m))
            .toList();
        await _localDatasource.guardarTodas(hives);
        return remote;
      } catch (_) {
        // Fallback a local si falla el remoto
      }
    }

    final local = await _localDatasource.obtenerTodas();
    return local.map((m) => m.toDomain()).toList();
  }

  @override
  Future<Municipalidad?> obtenerPorId(String id) async {
    if (await _hasConnection()) {
      try {
        final remote = await _remoteDatasource.obtenerPorId(id);
        if (remote != null) {
          await _localDatasource.guardar(MunicipalidadHive.fromDomain(remote));
          return remote;
        }
      } catch (_) {
        // Fallback
      }
    }

    final local = await _localDatasource.obtenerPorId(id);
    return local?.toDomain();
  }

  @override
  Future<void> sincronizarLocalmente() async {
    if (await _hasConnection()) {
      final remote = await _remoteDatasource.listarTodas();
      final hives = remote.map((m) => MunicipalidadHive.fromDomain(m)).toList();
      await _localDatasource.guardarTodas(hives);
    }
  }
}
