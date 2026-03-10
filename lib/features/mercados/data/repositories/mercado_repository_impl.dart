import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/entities/mercado.dart';
import '../../domain/repositories/mercado_repository.dart';
import '../datasources/mercado_datasource.dart';
import '../datasources/mercado_local_datasource.dart';
import '../models/hive/mercado_hive.dart';

class MercadoRepositoryImpl implements MercadoRepository {
  final MercadoDatasource _remoteDatasource;
  final MercadoLocalDatasource _localDatasource;
  final Connectivity _connectivity;

  MercadoRepositoryImpl(
    this._remoteDatasource,
    this._localDatasource,
    this._connectivity,
  );

  Future<bool> _hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  @override
  Future<void> syncMercados() async {
    if (!await _hasConnection()) return;

    final pendientes = await _localDatasource
        .obtenerPendientesDeSincronizacion();
    for (var mercadoHive in pendientes) {
      try {
        // Sincronizar
        mercadoHive.syncStatus = 1;
        await _localDatasource.guardarMercado(mercadoHive);
      } catch (e) {
        // Retry later
      }
    }
  }

  @override
  Stream<List<Mercado>> streamTodos() {
    return _remoteDatasource.streamTodos().map((list) {
      // Sincronización automática: Cachear en Hive
      final hives = list.map((m) => MercadoHive.fromDomain(m)).toList();
      _localDatasource.guardarMercados(hives);
      return list;
    });
  }

  @override
  Stream<List<Mercado>> streamPorMunicipalidad(String municipalidadId) {
    return _remoteDatasource.streamPorMunicipalidad(municipalidadId).map((
      list,
    ) {
      // Sincronización automática: Cachear en Hive
      final hives = list.map((m) => MercadoHive.fromDomain(m)).toList();
      _localDatasource.guardarMercados(hives);
      return list;
    });
  }

  @override
  Future<List<Mercado>> obtenerTodosOffline() async {
    final hives = await _localDatasource.obtenerTodos();
    return hives.map((h) => h.toDomain()).toList();
  }

  @override
  Future<Mercado?> obtenerPorId(String id) async {
    // 1. Intentar Remoto (Si hay conexión)
    final results = await _connectivity.checkConnectivity();
    if (!results.contains(ConnectivityResult.none)) {
      try {
        final remote = await _remoteDatasource.obtenerPorId(id);
        if (remote != null) {
          // Cachear
          await _localDatasource.guardarMercado(MercadoHive.fromDomain(remote));
          return remote;
        }
      } catch (_) {}
    }

    // 2. Fallback local (Hive)
    final local = await _localDatasource.obtenerPorId(id);
    return local?.toDomain();
  }
}
