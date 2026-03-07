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
  final QueryDocumentSnapshot? ultimoDoc;

  const LocalesPaginadosState({
    this.locales = const [],
    this.cargando = false,
    this.hayMas = true,
    this.errorMsg,
    this.mercadoSeleccionadoId,
    this.busqueda,
    this.ultimoDoc,
  });

  LocalesPaginadosState copyWith({
    List<Local>? locales,
    bool? cargando,
    bool? hayMas,
    String? errorMsg,
    String? mercadoSeleccionadoId,
    String? busqueda,
    QueryDocumentSnapshot? ultimoDoc,
    bool clearError = false,
    bool clearUltimoDoc = false,
  }) {
    return LocalesPaginadosState(
      locales: locales ?? this.locales,
      cargando: cargando ?? this.cargando,
      hayMas: hayMas ?? this.hayMas,
      errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      mercadoSeleccionadoId:
          mercadoSeleccionadoId ?? this.mercadoSeleccionadoId,
      busqueda: busqueda ?? this.busqueda,
      ultimoDoc: clearUltimoDoc ? null : (ultimoDoc ?? this.ultimoDoc),
    );
  }
}

/// Notifier que maneja la paginación de locales con filtros y búsqueda.
class LocalesPaginadosNotifier extends Notifier<LocalesPaginadosState> {
  static const int _pageSize = 25;

  // Mapa para recuperar los DocumentSnapshot por ID (necesario para cursor).
  final Map<String, QueryDocumentSnapshot> _docSnapshots = {};

  @override
  LocalesPaginadosState build() => const LocalesPaginadosState();

  LocalDatasource get _ds => ref.read(localDatasourceProvider);

  String? get _municipalidadId =>
      ref.read(currentUsuarioProvider).value?.municipalidadId;

  /// Cambia el mercado seleccionado y recarga desde cero.
  Future<void> seleccionarMercado(Mercado? mercado) async {
    _docSnapshots.clear();
    state = LocalesPaginadosState(
      mercadoSeleccionadoId: mercado?.id,
      busqueda: null,
      cargando: true,
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Aplica búsqueda (llamar después del debounce de 500ms).
  Future<void> aplicarBusqueda(String query) async {
    _docSnapshots.clear();
    final busqueda = query.isEmpty ? null : query;
    state = state.copyWith(
      busqueda: busqueda,
      locales: [],
      hayMas: true,
      cargando: true,
      clearUltimoDoc: true,
      clearError: true,
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Carga la siguiente página (llamar cuando el usuario llegue al final).
  Future<void> cargarSiguientePagina() async {
    if (state.cargando || !state.hayMas) return;
    state = state.copyWith(cargando: true);
    await _fetchPagina(lastDoc: state.ultimoDoc);
  }

  Future<void> _fetchPagina({required QueryDocumentSnapshot? lastDoc}) async {
    try {
      final municipalidadId = _municipalidadId;
      final mercadoId = state.mercadoSeleccionadoId;
      final query = state.busqueda;
      List<LocalJson> rawItems;

      if (mercadoId != null) {
        rawItems = await _ds.listarPaginaPorMercado(
          mercadoId: mercadoId,
          searchQuery: query,
          lastDoc: lastDoc,
          limit: _pageSize,
        );
      } else if (municipalidadId != null) {
        rawItems = await _ds.listarPaginaPorMunicipalidad(
          municipalidadId: municipalidadId,
          searchQuery: query,
          lastDoc: lastDoc,
          limit: _pageSize,
        );
      } else {
        state = state.copyWith(cargando: false, hayMas: false);
        return;
      }

      // LocalJson extiende Local, se puede usar directamente como Local.
      final nuevos = rawItems.cast<Local>();

      state = state.copyWith(
        locales: [...state.locales, ...nuevos],
        hayMas: rawItems.length >= _pageSize,
        cargando: false,
        clearError: true,
      );
    } catch (e) {
      final text = e.toString();
      final match = RegExp(
        r'https://console\.firebase\.google\.com[^\s]+',
      ).firstMatch(text);
      if (match != null) {
        debugPrint(
          '\n\n🚨 FALTAN ÍNDICES EN FIRESTORE 🚨\n👇 HAZ CLIC EN ESTE ENLACE PARA CREARLOS 👇\n\n${match.group(0)}\n\n============================================\n\n',
        );
      } else {
        debugPrint(
          '\n=== ERROR EN FIRESTORE ===\n$text\n==========================\n',
        );
      }
      state = state.copyWith(
        cargando: false,
        hayMas: false,
        errorMsg: 'Error al cargar locales: $text',
      );
    }
  }

  /// Recarga desde cero (pull-to-refresh).
  Future<void> recargar() async {
    _docSnapshots.clear();
    state = state.copyWith(
      locales: [],
      hayMas: true,
      cargando: true,
      clearUltimoDoc: true,
      clearError: true,
    );
    await _fetchPagina(lastDoc: null);
  }
}

final localesPaginadosProvider =
    NotifierProvider<LocalesPaginadosNotifier, LocalesPaginadosState>(
      LocalesPaginadosNotifier.new,
    );
