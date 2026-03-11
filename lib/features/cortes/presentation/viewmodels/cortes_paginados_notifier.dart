import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../domain/entities/corte.dart';
import '../../data/models/corte_model.dart';

class CortesPaginadosState {
  final List<Corte> cortes;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final bool isAdmin;
  final bool inicializado;

  CortesPaginadosState({
    this.cortes = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.isAdmin = false,
    this.inicializado = false,
  });

  CortesPaginadosState copyWith({
    List<Corte>? cortes,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    bool? isAdmin,
    bool? inicializado,
  }) {
    return CortesPaginadosState(
      cortes: cortes ?? this.cortes,
      cargando: cargando ?? this.cargando,
      errorMsg: errorMsg,
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      isAdmin: isAdmin ?? this.isAdmin,
      inicializado: inicializado ?? this.inicializado,
    );
  }
}

class CortesPaginadosNotifier extends Notifier<CortesPaginadosState> {
  static const int _pageSize = 20;
  final bool _isAdmin;

  CortesPaginadosNotifier(this._isAdmin);

  @override
  CortesPaginadosState build() {
    return CortesPaginadosState(isAdmin: _isAdmin);
  }

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    state = state.copyWith(cargando: true, errorMsg: null);

    try {
      final user = ref.read(currentUsuarioProvider).value;
      if (user == null) {
        state = state.copyWith(cargando: false, errorMsg: 'Usuario no autenticado');
        return;
      }

      final ds = ref.read(corteDatasourceProvider);
      
      final snapshotAnterior = reiniciar ? null : state.snapshotsPaginas[state.paginaActual - 1];

      late QuerySnapshot<Map<String, dynamic>> result;
      
      if (state.isAdmin) {
        if (user.municipalidadId == null) throw Exception('Admin sin municipalidadId');
        result = await ds.listarPaginaPorMunicipalidad(
          municipalidadId: user.municipalidadId!,
          limite: _pageSize,
          startAfter: snapshotAnterior,
        );
      } else {
        if (user.id == null) throw Exception('Cobrador sin ID');
        result = await ds.listarPaginaPorCobrador(
          cobradorId: user.id!,
          limite: _pageSize,
          startAfter: snapshotAnterior,
        );
      }

      final docs = result.docs;
      final hayMas = docs.length >= _pageSize;

      final cortesList = docs.map((doc) {
        return CorteModel.fromMap(doc.data(), doc.id);
      }).toList();

      final nuevasPaginas = List<QueryDocumentSnapshot?>.from(state.snapshotsPaginas);
      if (reiniciar) {
        nuevasPaginas.clear();
        nuevasPaginas.add(null);
      }

      if (hayMas && nuevasPaginas.length <= state.paginaActual) {
        nuevasPaginas.add(docs.last);
      }

      state = state.copyWith(
        cortes: cortesList,
        cargando: false,
        hayMas: hayMas,
        paginaActual: reiniciar ? 1 : state.paginaActual,
        snapshotsPaginas: nuevasPaginas,
        inicializado: true,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar historial: $e',
      );
    }
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

  Future<void> recargar() => cargarPagina(reiniciar: true);
}

final cortesAdminPaginadosProvider = NotifierProvider<
  CortesPaginadosNotifier,
  CortesPaginadosState
>(() => CortesPaginadosNotifier(true));

final cortesCobradorPaginadosProvider = NotifierProvider<
  CortesPaginadosNotifier,
  CortesPaginadosState
>(() => CortesPaginadosNotifier(false));
