import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/local_model.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../domain/entities/local.dart';
import '../../../usuarios/domain/entities/usuario.dart';

enum LocalFiltroDeuda { todos, soloDeudores, soloSaldosAFavor }

/// Estado completo para la pantalla de locales paginada.
class LocalesPaginadosState {
  final List<Local> locales;
  final bool cargando;
  final bool hayMas;
  final int totalPaginas;
  final String? errorMsg;
  final String? mercadoSeleccionadoId;
  final String? busqueda;
  final int paginaActual;
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final Map<String, bool> localesPagadosHoy;
  final QueryDocumentSnapshot? ultimoDoc;
  final LocalFiltroDeuda filtroDeuda;
  final String? usuarioFiltradoId;

  const LocalesPaginadosState({
    this.locales = const [],
    this.cargando = false,
    this.hayMas = true,
    this.totalPaginas = 1,
    this.errorMsg,
    this.mercadoSeleccionadoId,
    this.busqueda,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.localesPagadosHoy = const {},
    this.ultimoDoc,
    this.filtroDeuda = LocalFiltroDeuda.todos,
    this.usuarioFiltradoId,
  });

  LocalesPaginadosState copyWith({
    List<Local>? locales,
    bool? cargando,
    bool? hayMas,
    int? totalPaginas,
    String? errorMsg,
    String? mercadoSeleccionadoId,
    String? busqueda,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    Map<String, bool>? localesPagadosHoy,
    QueryDocumentSnapshot? ultimoDoc,
    LocalFiltroDeuda? filtroDeuda,
    String? usuarioFiltradoId,
    bool clearError = false,
    bool clearUltimoDoc = false,
    bool clearBusqueda = false,
    bool clearMercadoSeleccionado = false,
    bool clearUsuarioFiltrado = false,
  }) {
    return LocalesPaginadosState(
      locales: locales ?? this.locales,
      cargando: cargando ?? this.cargando,
      hayMas: hayMas ?? this.hayMas,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      mercadoSeleccionadoId: clearMercadoSeleccionado
          ? null
          : (mercadoSeleccionadoId ?? this.mercadoSeleccionadoId),
      busqueda: clearBusqueda ? null : (busqueda ?? this.busqueda),
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      localesPagadosHoy: localesPagadosHoy ?? this.localesPagadosHoy,
      ultimoDoc: clearUltimoDoc ? null : (ultimoDoc ?? this.ultimoDoc),
      filtroDeuda: filtroDeuda ?? this.filtroDeuda,
      usuarioFiltradoId: clearUsuarioFiltrado
          ? null
          : (usuarioFiltradoId ?? this.usuarioFiltradoId),
    );
  }
}

/// Notifier que maneja la paginación de locales con filtros y búsqueda.
class LocalesPaginadosNotifier extends Notifier<LocalesPaginadosState> {
  static const int _pageSize = 20;
  static const int _exportPageSize = 300;

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
      totalPaginas: 1,
      paginaActual: 1,
      snapshotsPaginas: [null],
      localesPagadosHoy: const {},
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
      totalPaginas: 1,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      clearUltimoDoc: true,
      clearError: true,
      clearBusqueda: query.isEmpty,
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Cambia el filtro de deuda y recarga desde cero.
  Future<void> cambiarFiltroDeuda(LocalFiltroDeuda filtro) async {
    state = state.copyWith(
      filtroDeuda: filtro,
      locales: [],
      hayMas: true,
      totalPaginas: 1,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      clearUltimoDoc: true,
      clearError: true,
      localesPagadosHoy: const {},
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Cambia el usuario (cobrador) para filtrar por su ruta asignada.
  Future<void> seleccionarUsuario(String? usuarioId) async {
    state = state.copyWith(
      usuarioFiltradoId: usuarioId,
      clearUsuarioFiltrado: usuarioId == null,
      locales: [],
      hayMas: true,
      totalPaginas: 1,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      clearUltimoDoc: true,
      clearError: true,
      localesPagadosHoy: const {},
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Limpia filtros y recarga desde cero.
  Future<void> restablecerFiltros() async {
    state = state.copyWith(
      locales: [],
      hayMas: true,
      totalPaginas: 1,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      filtroDeuda: LocalFiltroDeuda.todos,
      clearUltimoDoc: true,
      clearError: true,
      clearBusqueda: true,
      clearMercadoSeleccionado: true,
      clearUsuarioFiltrado: true,
      localesPagadosHoy: const {},
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

      // Mapear el nombre del enum al string esperado por el datasource
      String filtroDs = 'todos';
      if (state.filtroDeuda == LocalFiltroDeuda.soloDeudores) {
        filtroDs = 'deudores';
      }
      if (state.filtroDeuda == LocalFiltroDeuda.soloSaldosAFavor) {
        filtroDs = 'saldos';
      }

      List<String>? filterLocalIds;
      if (state.usuarioFiltradoId != null) {
        final usuarios = ref.read(usuariosProvider).value ?? [];
        final usuario = usuarios.whereType<Usuario>().firstWhere(
          (u) => u.id == state.usuarioFiltradoId,
          orElse: () => const Usuario(),
        );
        filterLocalIds = usuario.rutaAsignada;
      }

      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      int? totalRegistros;

      if (municipalidadId != null) {
        if (lastDoc == null) {
          totalRegistros = await _ds.contarLocalesPorMunicipalidad(
            municipalidadId: municipalidadId,
            mercadoId: mercadoId,
            searchQuery: query,
            filtroDeuda: filtroDs,
            filterLocalIds: filterLocalIds,
          );
        }

        docs = await _ds.listarPaginaPorMunicipalidad(
          municipalidadId: municipalidadId,
          mercadoId: mercadoId,
          searchQuery: query,
          lastDoc: lastDoc,
          limit: _pageSize,
          filtroDeuda: filtroDs,
          filterLocalIds: filterLocalIds,
        );
      } else {
        state = state.copyWith(cargando: false, hayMas: false);
        return;
      }

      final nuevos = docs.map((doc) {
        return LocalJson.fromJson(doc.data(), docId: doc.id) as Local;
      }).toList();

      final ultimoDoc = docs.isNotEmpty ? docs.last : null;

      state = state.copyWith(
        locales: nuevos, // Reemplazamos en lugar de agregar
        hayMas: docs.length >= _pageSize,
        cargando: false,
        ultimoDoc: ultimoDoc,
        totalPaginas: totalRegistros == null
            ? state.totalPaginas
            : (totalRegistros == 0 ? 1 : (totalRegistros / _pageSize).ceil()),
        clearError: true,
      );

      // Verificar cuáles de estos locales ya pagaron hoy
      await _verificarPagosHoy(nuevos);
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

  /// Verifica consultando el último cobro de cada local.
  Future<void> _verificarPagosHoy(List<Local> locales) async {
    if (locales.isEmpty) return;

    final ahora = DateTime.now();
    final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
    final firestore = FirebaseFirestore.instance;
    final ids = locales
        .map((l) => l.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return;

    try {
      final Map<String, bool> pagaronHoy = {};
      final hoyTs = Timestamp.fromDate(hoyInicio);

      for (final batch in _chunkIds(ids, 30)) {
        final snapshot = await firestore
            .collection('cobros')
            .where('localId', whereIn: batch)
            .where('fecha', isGreaterThanOrEqualTo: hoyTs)
            .orderBy('fecha', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final localId = data['localId'] as String?;
          if (localId == null) continue;
          if (pagaronHoy[localId] == true) continue;
          if (data['estado'] == 'cobrado' || (data['monto'] ?? 0) > 0) {
            pagaronHoy[localId] = true;
          }
        }
      }

      state = state.copyWith(localesPagadosHoy: pagaronHoy);
    } catch (e) {
      debugPrint(
        'Batch de pagos-hoy no disponible, usando fallback por local: $e',
      );
      await _verificarPagosHoyFallback(locales: locales, hoyInicio: hoyInicio);
    }
  }

  Future<void> _verificarPagosHoyFallback({
    required List<Local> locales,
    required DateTime hoyInicio,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final Map<String, bool> pagaronHoy = {};

      await Future.wait(
        locales.map((l) async {
          final localId = l.id;
          if (localId == null || localId.isEmpty) return;

          final snapshot = await firestore
              .collection('cobros')
              .where('localId', isEqualTo: localId)
              .orderBy('fecha', descending: true)
              .limit(3)
              .get();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final fechaObj = data['fecha'];
            if (fechaObj is! Timestamp) continue;
            final fecha = fechaObj.toDate();
            if (fecha.isBefore(hoyInicio)) break;
            if (data['estado'] == 'cobrado' || (data['monto'] ?? 0) > 0) {
              pagaronHoy[localId] = true;
              break;
            }
          }
        }),
      );

      state = state.copyWith(localesPagadosHoy: pagaronHoy);
    } catch (e) {
      debugPrint('Error verificando pagos hoy (fallback): $e');
    }
  }

  Iterable<List<String>> _chunkIds(List<String> ids, int size) sync* {
    for (var i = 0; i < ids.length; i += size) {
      final end = i + size > ids.length ? ids.length : i + size;
      yield ids.sublist(i, end);
    }
  }

  /// Recarga desde cero.
  Future<void> recargar() async {
    state = state.copyWith(
      locales: [],
      hayMas: true,
      totalPaginas: 1,
      cargando: true,
      paginaActual: 1,
      snapshotsPaginas: [null],
      clearUltimoDoc: true,
      clearError: true,
      clearBusqueda: true,
      localesPagadosHoy: const {},
    );
    await _fetchPagina(lastDoc: null);
  }

  /// Exporta todos los locales con los filtros actuales (sin afectar el estado de la UI).
  Future<List<Local>> exportarLocalesFiltrados() async {
    final municipalidadId = _municipalidadId;
    final mercadoId = state.mercadoSeleccionadoId;
    final query = state.busqueda;

    // Mapear el nombre del enum al string esperado por el datasource
    String filtroDs = 'todos';
    if (state.filtroDeuda == LocalFiltroDeuda.soloDeudores) {
      filtroDs = 'deudores';
    }
    if (state.filtroDeuda == LocalFiltroDeuda.soloSaldosAFavor) {
      filtroDs = 'saldos';
    }

    List<String>? filterLocalIds;
    if (state.usuarioFiltradoId != null) {
      final usuarios = ref.read(usuariosProvider).value ?? [];
      final usuario = usuarios.whereType<Usuario>().firstWhere(
        (u) => u.id == state.usuarioFiltradoId,
        orElse: () => const Usuario(),
      );
      filterLocalIds = usuario.rutaAsignada;
    }

    if (mercadoId == null && municipalidadId == null) return [];

    final List<Local> all = [];
    QueryDocumentSnapshot? lastDoc;
    bool hasMore = true;

    while (hasMore) {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

      docs = await _ds.listarPaginaPorMunicipalidad(
        municipalidadId: municipalidadId!,
        mercadoId: mercadoId,
        searchQuery: query,
        lastDoc: lastDoc,
        limit: _exportPageSize,
        filtroDeuda: filtroDs,
        filterLocalIds: filterLocalIds,
      );

      final nuevos = docs.map((doc) {
        return LocalJson.fromJson(doc.data(), docId: doc.id) as Local;
      }).toList();

      all.addAll(nuevos);

      if (docs.length < _exportPageSize) {
        hasMore = false;
      } else {
        lastDoc = docs.last;
      }
    }

    return all;
  }
}

final localesPaginadosProvider =
    NotifierProvider<LocalesPaginadosNotifier, LocalesPaginadosState>(
      LocalesPaginadosNotifier.new,
    );
