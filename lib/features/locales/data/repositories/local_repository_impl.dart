import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/local.dart';
import '../../domain/repositories/local_repository.dart';
import '../datasources/local_datasource.dart';
import '../datasources/local_local_datasource.dart';
import '../models/hive/local_hive.dart';

class LocalRepositoryImpl implements LocalRepository {
  final LocalDatasource _remoteDatasource;
  final LocalLocalDatasource _localDatasource;
  final Connectivity _connectivity;

  LocalRepositoryImpl(
    this._remoteDatasource,
    this._localDatasource,
    this._connectivity,
  );

  Future<bool> _hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  @override
  Future<void> syncLocales() async {
    if (!await _hasConnection()) return;

    final pendientes = await _localDatasource
        .obtenerPendientesDeSincronizacion();
    for (var localHive in pendientes) {
      try {
        // Sincronizar con Firestore: _remoteDatasource.crear o actualizar
        // Sincronizar con Firestore: _remoteDatasource.crear o actualizar
        localHive.syncStatus = 1;
        await _localDatasource.guardarLocal(localHive);
      } catch (e) {
        // Fallar silenciosamente e intentar en la proxima sync
      }
    }
  }

  @override
  Stream<List<Local>> streamTodos() {
    return _remoteDatasource.streamTodos().map((locales) {
      // Background Hive Caching
      _guardarLocalesEnCache(locales);
      return locales;
    });
  }

  @override
  Stream<List<Local>> streamPorMunicipalidad(String municipalidadId) {
    return _remoteDatasource.streamPorMunicipalidad(municipalidadId).map((
      locales,
    ) {
      _guardarLocalesEnCache(locales);
      return locales;
    });
  }

  @override
  Stream<Local?> streamPorId(String id) {
    return _remoteDatasource.streamPorId(id).map((local) {
      if (local != null) _guardarLocalesEnCache([local]);
      return local;
    });
  }

  @override
  Future<Local?> obtenerPorId(String id) async {
    final local = await _remoteDatasource.obtenerPorId(id);
    if (local != null) {
      _guardarLocalesEnCache([local]);
    }
    return local;
  }

  // Interceptor que inyecta en Hive silenciosamente
  Future<void> _guardarLocalesEnCache(List<Local> locales) async {
    try {
      final box = await Hive.openBox<LocalHive>('localesBox');
      for (final local in locales) {
        final localH = LocalHive.fromDomain(
          local,
          syncStatus: 1,
        ); // 1 = ya sincronizado
        await box.put(localH.id, localH);
      }
    } catch (_) {}
  }

  @override
  Future<void> procesarPagoOfflineSafe(
    String localId,
    num abonoDeuda,
    num incrementoSaldo,
  ) async {
    await _remoteDatasource.procesarPagoOfflineSafe(
      localId,
      abonoDeuda,
      incrementoSaldo,
    );
  }

  @override
  Future<void> revertirPago({
    required String localId,
    required num montoARecomponerDeuda,
    required num montoARestarSaldo,
  }) async {
    // 1. Firestore (Incrementos/Decrementos seguros que se sincronizan al volver online)
    await _remoteDatasource.revertirPago(
      localId: localId,
      montoARecomponerDeuda: montoARecomponerDeuda,
      montoARestarSaldo: montoARestarSaldo,
    );

    // 2. Local Cache (Hive) para que el cambio sea instantáneo en la UI del cobrador
    final localH = await _localDatasource.obtenerPorId(localId);
    if (localH != null) {
      localH.deudaAcumulada =
          (localH.deudaAcumulada ?? 0) + montoARecomponerDeuda;
      localH.saldoAFavor = (localH.saldoAFavor ?? 0) - montoARestarSaldo;
      await _localDatasource.guardarLocal(localH);
    }
  }

  @override
  Future<int> recalcularDeudasBasadoEnHistorial() async {
    return await _remoteDatasource.recalcularDeudasBasadoEnHistorial();
  }
}
