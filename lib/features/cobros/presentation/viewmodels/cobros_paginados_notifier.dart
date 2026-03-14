import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../cobros/domain/entities/cobro.dart';

class CobrosPaginadosState {
  final List<Cobro> cobros;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final DateTimeRange? rangoFechas;
  final String? mercadoId;
  final String? cobradorId;

  CobrosPaginadosState({
    this.cobros = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.rangoFechas,
    this.mercadoId,
    this.cobradorId,
  });

  CobrosPaginadosState copyWith({
    List<Cobro>? cobros,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    DateTimeRange? rangoFechas,
    String? mercadoId,
    String? cobradorId,
  }) {
    return CobrosPaginadosState(
      cobros: cobros ?? this.cobros,
      cargando: cargando ?? this.cargando,
      errorMsg: errorMsg,
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      rangoFechas: rangoFechas ?? this.rangoFechas,
      mercadoId: mercadoId ?? this.mercadoId,
      cobradorId: cobradorId ?? this.cobradorId,
    );
  }
}

class CobrosPaginadosNotifier extends Notifier<CobrosPaginadosState> {
  static const int _pageSize = 20;

  @override
  CobrosPaginadosState build() {
    return CobrosPaginadosState();
  }

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    state = state.copyWith(cargando: true, errorMsg: null);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUsuarioProvider).value;
      final municipalidadId = user?.municipalidadId;

      Query<Map<String, dynamic>> query = firestore
          .collection('cobros')
          .orderBy('fecha', descending: true);

      if (municipalidadId != null) {
        query = query.where('municipalidadId', isEqualTo: municipalidadId);
      }

      if (state.mercadoId != null) {
        query = query.where('mercadoId', isEqualTo: state.mercadoId);
      }

      if (state.cobradorId != null) {
        query = query.where('cobradorId', isEqualTo: state.cobradorId);
      }

      if (state.rangoFechas != null) {
        final inicio = DateTime(
          state.rangoFechas!.start.year,
          state.rangoFechas!.start.month,
          state.rangoFechas!.start.day,
        );
        final fin = DateTime(
          state.rangoFechas!.end.year,
          state.rangoFechas!.end.month,
          state.rangoFechas!.end.day,
        ).add(const Duration(days: 1));

        query = query
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha', isLessThan: Timestamp.fromDate(fin));
      }

      final snapshotActual =
          reiniciar ? null : state.snapshotsPaginas[state.paginaActual - 1];

      if (snapshotActual != null) {
        query = query.startAfterDocument(snapshotActual);
      }

      final result = await query.limit(_pageSize + 1).get();

      final docs = result.docs;
      final hayMas = docs.length > _pageSize;
      final docsAMostrar = hayMas ? docs.sublist(0, _pageSize) : docs;

      final cobrosList =
          docsAMostrar.map((doc) {
            return _mapDocToCobro(doc);
          }).toList();

      final nuevasPaginas = List<QueryDocumentSnapshot?>.from(
        state.snapshotsPaginas,
      );
      if (reiniciar) {
        nuevasPaginas.clear();
        nuevasPaginas.add(null);
      }

      if (hayMas && nuevasPaginas.length <= state.paginaActual) {
        nuevasPaginas.add(docsAMostrar.last);
      }

      state = state.copyWith(
        cobros: cobrosList,
        cargando: false,
        hayMas: hayMas,
        paginaActual: reiniciar ? 1 : state.paginaActual,
        snapshotsPaginas: nuevasPaginas,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar cobros: $e',
      );
    }
  }

  Cobro _mapDocToCobro(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Cobro(
      id: doc.id,
      cobradorId: data['cobradorId'],
      actualizadoEn: (data['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: data['actualizadoPor'],
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: data['creadoPor'],
      cuotaDiaria: data['cuotaDiaria'],
      estado: data['estado'],
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      localId: data['localId'],
      mercadoId: data['mercadoId'],
      monto: data['monto'],
      municipalidadId: data['municipalidadId'],
      observaciones: data['observaciones'],
      saldoPendiente: data['saldoPendiente'],
      telefonoRepresentante: data['telefonoRepresentante'],
      correlativo: data['correlativo'],
      anioCorrelativo: data['anioCorrelativo'],
      numeroBoleta: data['numeroBoleta'],
      deudaAnterior: data['deudaAnterior'],
      montoAbonadoDeuda: data['montoAbonadoDeuda'],
      nuevoSaldoFavor: data['nuevoSaldoFavor'],
      pagoACuota: data['pagoACuota'],
      idsDeudasSaldadas:
          data['idsDeudasSaldadas'] != null
              ? List<String>.from(data['idsDeudasSaldadas'])
              : null,
    );
  }

  void irAPaginaSiguiente() {
    if (state.hayMas && !state.cargando) {
      state = state.copyWith(paginaActual: state.paginaActual + 1);
      cargarPagina();
    }
  }

  void irAPaginaAnterior() {
    if (state.paginaActual > 1 && !state.cargando) {
      state = state.copyWith(paginaActual: state.paginaActual - 1);
      cargarPagina();
    }
  }

  void aplicarFiltros({DateTimeRange? rango, String? mercadoId, String? cobradorId}) {
    state = CobrosPaginadosState(
      rangoFechas: rango,
      mercadoId: mercadoId,
      cobradorId: cobradorId,
    );
    cargarPagina(reiniciar: true);
  }

  Future<void> recargar() => cargarPagina(reiniciar: true);
}

final cobrosPaginadosProvider = NotifierProvider<
  CobrosPaginadosNotifier,
  CobrosPaginadosState
>(() => CobrosPaginadosNotifier());
