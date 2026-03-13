import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../domain/entities/corte.dart';
import '../../data/models/corte_model.dart';

// Enum para filtro rápido de fechas
enum FiltroFecha { todos, hoy, semana, mes, personalizado }

class CortesPaginadosState {
  final List<Corte> cortes;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final bool isAdmin;
  final bool inicializado;
  final FiltroFecha filtroActivo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  CortesPaginadosState({
    this.cortes = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.isAdmin = false,
    this.inicializado = false,
    this.filtroActivo = FiltroFecha.todos,
    this.fechaInicio,
    this.fechaFin,
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
    FiltroFecha? filtroActivo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool clearFechas = false,
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
      filtroActivo: filtroActivo ?? this.filtroActivo,
      fechaInicio: clearFechas ? null : (fechaInicio ?? this.fechaInicio),
      fechaFin: clearFechas ? null : (fechaFin ?? this.fechaFin),
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

  /// Aplica filtro "Hoy"
  void filtrarHoy() {
    final now = DateTime.now();
    final inicio = DateTime(now.year, now.month, now.day);
    final fin = inicio.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    _aplicarFiltro(FiltroFecha.hoy, inicio, fin);
  }

  /// Aplica filtro "Esta semana" (lunes a hoy)
  void filtrarSemana() {
    final now = DateTime.now();
    final lunes = now.subtract(Duration(days: now.weekday - 1));
    final inicio = DateTime(lunes.year, lunes.month, lunes.day);
    final fin = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _aplicarFiltro(FiltroFecha.semana, inicio, fin);
  }

  /// Aplica filtro "Este mes"
  void filtrarMes() {
    final now = DateTime.now();
    final inicio = DateTime(now.year, now.month, 1);
    final fin = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _aplicarFiltro(FiltroFecha.mes, inicio, fin);
  }

  /// Aplica filtro personalizado por rango
  void filtrarRango(DateTime desde, DateTime hasta) {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);
    _aplicarFiltro(FiltroFecha.personalizado, inicio, fin);
  }

  /// Quita filtros y muestra todos
  void filtrarTodos() {
    state = CortesPaginadosState(isAdmin: _isAdmin, filtroActivo: FiltroFecha.todos);
    cargarPagina(reiniciar: true);
  }

  void _aplicarFiltro(FiltroFecha filtro, DateTime inicio, DateTime fin) {
    state = CortesPaginadosState(
      isAdmin: _isAdmin,
      filtroActivo: filtro,
      fechaInicio: inicio,
      fechaFin: fin,
    );
    cargarPagina(reiniciar: true);
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
          fechaInicio: state.fechaInicio,
          fechaFin: state.fechaFin,
        );
      } else {
        if (user.id == null) throw Exception('Cobrador sin ID');
        result = await ds.listarPaginaPorCobrador(
          cobradorId: user.id!,
          limite: _pageSize,
          startAfter: snapshotAnterior,
          fechaInicio: state.fechaInicio,
          fechaFin: state.fechaFin,
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
