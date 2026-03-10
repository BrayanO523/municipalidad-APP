import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/local_model.dart';
import '../../domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';

/// Estado completo para la pantalla de locales paginada.
class LocalesPaginadosState {
  final List<Local> locales;
  final bool cargando;
  final bool hayMas;
  final String? errorMsg;
  final String? mercadoSeleccionadoId;
  final String? busqueda;
  final int paginaActual;
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final QueryDocumentSnapshot? ultimoDoc;

  const LocalesPaginadosState({
    this.locales = const [],
    this.cargando = false,
    this.hayMas = true,
    this.errorMsg,
    this.mercadoSeleccionadoId,
    this.busqueda,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.ultimoDoc,
  });

  LocalesPaginadosState copyWith({
    List<Local>? locales,
    bool? cargando,
    bool? hayMas,
    String? errorMsg,
    String? mercadoSeleccionadoId,
    String? busqueda,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    QueryDocumentSnapshot? ultimoDoc,
    bool clearError = false,
    bool clearUltimoDoc = false,
    bool clearBusqueda = false,
  }) {
    return LocalesPaginadosState(
      locales: locales ?? this.locales,
      cargando: cargando ?? this.cargando,
      hayMas: hayMas ?? this.hayMas,
      errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      mercadoSeleccionadoId:
          mercadoSeleccionadoId ?? this.mercadoSeleccionadoId,
      busqueda: clearBusqueda ? null : (busqueda ?? this.busqueda),
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      ultimoDoc: clearUltimoDoc ? null : (ultimoDoc ?? this.ultimoDoc),
    );
  }
}

/// Notifier que maneja la paginación de locales con filtros y búsqueda.
class LocalesPaginadosNotifier extends Notifier<LocalesPaginadosState> {
  static const int _pageSize = 20;

  @override
  LocalesPaginadosState build() => const LocalesPaginadosState();

  LocalDatasource get _ds => ref.read(localDatasourceProvider);

  String? get _municipalidadId =>
      ref.read(currentUsuarioProvider).value?.municipalidadId;

  /// Cambia el mercado seleccionado y recarga desde cero.
  Future<void> seleccionarMercado(Mercado? mercado) async {
    state = LocalesPaginadosState(
      mercadoSeleccionadoId: mercado?.id,
      busqueda: null,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Aplica búsqueda (llamar después del debounce de 500ms).
  Future<void> aplicarBusqueda(String query) async {
    final busqueda = query.isEmpty ? null : query;
    state = state.copyWith(
      busqueda: busqueda,
      locales: [],
      hayMas: true,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      clearUltimoDoc: true,
      clearError: true,
      clearBusqueda: query.isEmpty,
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Navega a la siguiente página.
  Future<void> irAPaginaSiguiente() async {
    if (state.cargando || !state.hayMas) return;

    final nuevosSnapshots = List<QueryDocumentSnapshot?>.from(
      state.snapshotsPaginas,
    );
    // El snapshot para la siguiente página es el ultimoDoc de la actual.
    if (nuevosSnapshots.length <= state.paginaActual) {
      nuevosSnapshots.add(state.ultimoDoc);
    }

    state = state.copyWith(
      cargando: true,
      paginaActual: state.paginaActual + 1,
      snapshotsPaginas: nuevosSnapshots,
    );

    await _fetchPagina(lastDoc: state.ultimoDoc);
  }

  /// Navega a la página anterior.
  Future<void> irAPaginaAnterior() async {
    if (state.cargando || state.paginaActual <= 1) return;

    final nuevaPagina = state.paginaActual - 1;
    final startDoc = state.snapshotsPaginas[nuevaPagina - 1];

    state = state.copyWith(cargando: true, paginaActual: nuevaPagina);

    await _fetchPagina(lastDoc: startDoc);
  }

  Future<void> _fetchPagina({required QueryDocumentSnapshot? lastDoc}) async {
    try {
      final municipalidadId = _municipalidadId;
      final mercadoId = state.mercadoSeleccionadoId;
      final query = state.busqueda;
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (mercadoId != null) {
        snapshot = await _ds.listarPaginaPorMercado(
          mercadoId: mercadoId,
          searchQuery: query,
          lastDoc: lastDoc,
          limit: _pageSize,
        );
      } else if (municipalidadId != null) {
        snapshot = await _ds.listarPaginaPorMunicipalidad(
          municipalidadId: municipalidadId,
          searchQuery: query,
          lastDoc: lastDoc,
          limit: _pageSize,
        );
      } else {
        state = state.copyWith(cargando: false, hayMas: false);
        return;
      }

      final docs = snapshot.docs;
      final nuevos = docs.map((doc) {
        return LocalJson.fromJson(doc.data(), docId: doc.id) as Local;
      }).toList();

      final ultimoDoc = docs.isNotEmpty ? docs.last : null;

      state = state.copyWith(
        locales: nuevos, // Reemplazamos en lugar de agregar
        hayMas: docs.length >= _pageSize,
        cargando: false,
        ultimoDoc: ultimoDoc,
        clearError: true,
      );
    } catch (e) {
      final text = e.toString();
      debugPrint('Error en Firestore: $text');
      state = state.copyWith(
        cargando: false,
        hayMas: false,
        errorMsg: 'Error al cargar locales: $text',
      );
    }
  }

  /// Recarga desde cero.
  Future<void> recargar() async {
    state = state.copyWith(
      locales: [],
      hayMas: true,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      clearUltimoDoc: true,
      clearError: true,
      clearBusqueda: true,
    );
    await _fetchPagina(lastDoc: null);
  }
}

final localesPaginadosProvider =
    NotifierProvider<LocalesPaginadosNotifier, LocalesPaginadosState>(
      LocalesPaginadosNotifier.new,
    );
