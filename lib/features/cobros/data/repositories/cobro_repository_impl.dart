import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/entities/cobro.dart';
import '../../domain/repositories/cobro_repository.dart';
import '../datasources/cobro_datasource.dart';
import '../datasources/cobro_local_datasource.dart';
import '../../../locales/domain/repositories/local_repository.dart';
import '../models/cobro_model.dart';
import '../models/hive/cobro_hive.dart';

class CobroRepositoryImpl implements CobroRepository {
  final CobroDatasource _remoteDatasource;
  final CobroLocalDatasource _localDatasource;
  final Connectivity _connectivity;
  final LocalRepository _localRepository;

  CobroRepositoryImpl(
    this._remoteDatasource,
    this._localDatasource,
    this._connectivity,
    this._localRepository,
  );

  Future<bool> _hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((res) => res != ConnectivityResult.none);
  }

  @override
  Future<void> registrarCobroLocalmente(Cobro cobro) async {
    // 1. Guardar localmente
    final cobroHive = CobroHive.fromDomain(
      cobro,
      syncStatus: 0,
    ); // 0 = pendiente
    await _localDatasource.guardarCobro(cobroHive);

    // 2. Intentar sincronizar si hay red
    if (await _hasConnection()) {
      await syncCobros();
    }
  }

  @override
  Future<void> syncCobros() async {
    if (!await _hasConnection()) return;

    final pendientes = await _localDatasource
        .obtenerPendientesDeSincronizacion();
    for (var cobroHive in pendientes) {
      try {
        // Final Cobro is already synced, nothing more to do here unless sending to API
        // Convertir dependencias a JSON si es necesario
        // Aquí debe ir la lógica para mapear Cobro a Map y enviarlo usando _remoteDatasource
        // Ejemplo simplificado: _remoteDatasource.crearCobroConCorrelativo(...) o crear()
        // Después de éxito:
        cobroHive.syncStatus = 1;
        await _localDatasource.guardarCobro(cobroHive);
      } catch (e) {
        // En caso de fallo puede reintentarse más tarde
      }
    }
  }

  /// Registra el cobro completo y retorna la boleta + las fechas históricas saldadas (FIFO).
  @override
  Future<({String numeroBoleta, List<DateTime> fechasSaldadas})> registrarCobroCompleto(
    Cobro cobro,
    String localId, {
    num montoAbonadoDeuda = 0,
  }) async {
    final cobroJson = CobroJson.fromEntity(cobro).toJson();

    // 1. Intentar registrar en Firestore (Offline/Online)
    // Esto lo encola en caché y nos da 0 si estamos offline
    final numeroBoleta = await _remoteDatasource.crearCobroConCorrelativo(
      cobroId: cobro.id!,
      cobroData: cobroJson,
      localId: localId,
    );

    // 2. Adjuntamos el correlativo al cobro final
    final boletaParts = numeroBoleta.split('-');
    final cobroFinal = cobro.copyWith(
      correlativo: int.tryParse(boletaParts.last) ?? 0,
      numeroBoleta: numeroBoleta,
      anioCorrelativo: int.tryParse(boletaParts.first) ?? DateTime.now().year,
    );

    // 3. Lo guardamos en Hive para el Local NoSQL
    // Status 1 porque ya está en la caché interna formal de Firestore para subir cuando haya internet.
    final cobroHive = CobroHive.fromDomain(cobroFinal, syncStatus: 1);
    await _localDatasource.guardarCobro(cobroHive);

    // 4. FIFO: Procesar el historial de deuda local pendiente usando el monto abonado a deuda
    List<String> idsDeudasSaldadas = [];
    List<DateTime> fechasSaldadas = [];
    if (cobroFinal.localId != null && montoAbonadoDeuda > 0) {
      final resultado = await _remoteDatasource.saldarDeudaHistoria(
        cobroFinal.localId!,
        montoAbonadoDeuda,
      );
      idsDeudasSaldadas = resultado.ids;
      fechasSaldadas = resultado.fechas;
    }

    // 5. Si hubo deudas saldadas, actualizar el documento del cobro con esos IDs y fechas
    if (idsDeudasSaldadas.isNotEmpty && cobro.id != null) {
      await _remoteDatasource.actualizar(cobro.id!, {
        'idsDeudasSaldadas': idsDeudasSaldadas,
        'fechasDeudasSaldadas': fechasSaldadas
            .map((d) => Timestamp.fromDate(d))
            .toList(),
      });
    }

    return (numeroBoleta: numeroBoleta, fechasSaldadas: fechasSaldadas);
  }

  @override
  Stream<List<Cobro>> streamRecientes({
    String? municipalidadId,
    String? mercadoId,
  }) {
    return _remoteDatasource.streamRecientes(
      municipalidadId: municipalidadId,
      mercadoId: mercadoId,
    );
  }

  @override
  Stream<List<Cobro>> streamPorRangoFechas(
    DateTime inicio,
    DateTime fin, {
    String? municipalidadId,
    String? mercadoId,
  }) {
    return Stream.fromFuture(_remoteDatasource.listarPorRangoFechas(
      inicio,
      fin,
      municipalidadId: municipalidadId,
      mercadoId: mercadoId,
    ));
  }

  @override
  Stream<List<Cobro>> streamPorFecha(
    DateTime fecha, {
    String? municipalidadId,
    String? mercadoId,
  }) {
    return _remoteDatasource.streamPorFecha(
      fecha,
      municipalidadId: municipalidadId,
      mercadoId: mercadoId,
    );
  }

  @override
  Stream<List<Cobro>> streamPorLocal(String localId) {
    return _remoteDatasource.streamPorLocal(localId);
  }

  @override
  Future<void> eliminarCobro(Cobro cobro) async {
    final localId = cobro.localId;
    if (localId == null) return;

    // 1. Eliminar el registro del cobro (Remote + Local Cache)
    if (cobro.id != null) {
      await _remoteDatasource.eliminar(cobro.id!, municipalidadId: cobro.municipalidadId);
      await _localDatasource.eliminarCobro(cobro.id!);
    }

    // 3. Revertir impacto financiero segun el tipo de cobro
    if (cobro.estado == 'pendiente') {
      // Un pendiente sumó a la deuda. Al borrarlo, restamos de la deuda.
      await _localRepository.revertirPago(
        localId: localId,
        montoARecomponerDeuda: -(cobro.saldoPendiente ?? 0),
        montoARestarSaldo: 0,
      );
    } else if (cobro.estado == 'cobrado_saldo') {
      // Un auto-pago restó del saldo y cubrió deuda (o evitó que se creara).
      await _localRepository.revertirPago(
        localId: localId,
        montoARecomponerDeuda: cobro.monto ?? 0,
        montoARestarSaldo: -(cobro.monto ?? 0),
      );
    } else {
      // Cobro normal (efectivo): sumó al saldo y restó de deuda.
      final monto = cobro.monto ?? 0;
      final abonoDeuda = cobro.montoAbonadoDeuda ?? 0;
      final pagoCuota = cobro.pagoACuota ?? 0;
      final incrementoFavor = monto - abonoDeuda - pagoCuota;

      // 3a. Revertir deudas históricas saldadas (en cascada) usando los IDs guardados
      if (cobro.idsDeudasSaldadas != null &&
          cobro.idsDeudasSaldadas!.isNotEmpty) {
        await _remoteDatasource.revertirDeudasSaldadas(
          cobro.idsDeudasSaldadas!,
        );
      } else {
        // Fallback: Si no hay IDs (cobro antiguo), intentar revertir por monto
        try {
          final localDoc = await _localRepository.streamPorId(localId).first;
          if (localDoc != null && (localDoc.saldoAFavor ?? 0) < 0) {
            final autoPagos = await _remoteDatasource.listarPorLocal(localId);
            final soloAuto = autoPagos
                .where((c) => c.estado == 'cobrado_saldo')
                .toList();
            num negativo = -(localDoc.saldoAFavor ?? 0);
            for (final ap in soloAuto) {
              if (negativo <= 0) break;
              await eliminarCobro(ap);
              negativo -= ap.monto ?? 0;
            }
          }
        } catch (_) {}
      }

      await _localRepository.revertirPago(
        localId: localId,
        montoARecomponerDeuda: abonoDeuda + pagoCuota,
        montoARestarSaldo: incrementoFavor,
      );
    }

    // 4. Retroceder correlativo del Cobrador (Usuario) si era el último
    if (cobro.creadoPor != null &&
        cobro.correlativo != null &&
        cobro.anioCorrelativo != null) {
      await _remoteDatasource.retrocederCorrelativo(
        usuarioId: cobro.creadoPor!,
        anio: cobro.anioCorrelativo!,
        correlativoABorrar: cobro.correlativo!,
      );
    }
  }
}
