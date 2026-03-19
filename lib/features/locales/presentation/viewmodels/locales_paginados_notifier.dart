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

enum LocalOrdenamiento { alfabeticoAsc, alfabeticoDesc, cuotaMayor, cuotaMenor }

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
  final LocalOrdenamiento ordenamiento;

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
    this.ordenamiento = LocalOrdenamiento.alfabeticoAsc,
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
    LocalOrdenamiento? ordenamiento,
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
      ordenamiento: ordenamiento ?? this.ordenamiento,
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
      ordenamiento: state.ordenamiento,
    );
    await _fetchPagina();
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
    await _fetchPagina();
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
    await _fetchPagina();
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
    await _fetchPagina();
  }

  Future<void> cambiarOrdenamiento(LocalOrdenamiento ordenamiento) async {
    if (state.ordenamiento == ordenamiento) return;
    state = state.copyWith(
      ordenamiento: ordenamiento,
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
    await _fetchPagina();
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
      ordenamiento: LocalOrdenamiento.alfabeticoAsc,
      clearUltimoDoc: true,
      clearError: true,
      clearBusqueda: true,
      clearMercadoSeleccionado: true,
      clearUsuarioFiltrado: true,
      localesPagadosHoy: const {},
    );
    await _fetchPagina();
  }

  /// Navega a la siguiente página.
  Future<void> irAPaginaSiguiente() async {
    if (state.cargando || state.paginaActual >= state.totalPaginas) return;
    state = state.copyWith(
      cargando: true,
      paginaActual: state.paginaActual + 1,
      clearError: true,
    );
    await _fetchPagina();
  }

  /// Navega a la página anterior.
  Future<void> irAPaginaAnterior() async {
    if (state.cargando || state.paginaActual <= 1) return;
    state = state.copyWith(
      cargando: true,
      paginaActual: state.paginaActual - 1,
      clearError: true,
    );
    await _fetchPagina();
  }

  Future<void> _fetchPagina() async {
    try {
      final municipalidadId = _municipalidadId;
      if (municipalidadId == null) {
        state = state.copyWith(
          locales: const [],
          cargando: false,
          hayMas: false,
          totalPaginas: 1,
          paginaActual: 1,
          localesPagadosHoy: const {},
        );
        return;
      }

      final todos = await _cargarTodosFiltrados(
        municipalidadId: municipalidadId,
        mercadoId: state.mercadoSeleccionadoId,
        searchQuery: null,
        filtroDeuda: _filtroDeudaDatasource(state.filtroDeuda),
        filterLocalIds: _resolverFilterLocalIds(),
      );

      final todosFiltrados = _filtrarLocalesPorBusquedaAvanzada(
        todos,
        state.busqueda,
      );

      _ordenarLocales(todosFiltrados, state.ordenamiento);

      final totalRegistros = todosFiltrados.length;
      final totalPaginas = totalRegistros == 0
          ? 1
          : (totalRegistros / _pageSize).ceil();
      final paginaActual = state.paginaActual.clamp(1, totalPaginas);
      final inicio = (paginaActual - 1) * _pageSize;
      final fin = (inicio + _pageSize > totalRegistros)
          ? totalRegistros
          : inicio + _pageSize;
      final pagina = inicio >= totalRegistros
          ? <Local>[]
          : todosFiltrados.sublist(inicio, fin);

      state = state.copyWith(
        locales: pagina,
        hayMas: paginaActual < totalPaginas,
        cargando: false,
        totalPaginas: totalPaginas,
        paginaActual: paginaActual,
        snapshotsPaginas: const [null],
        clearUltimoDoc: true,
        localesPagadosHoy: const {},
        clearError: true,
      );

      await _verificarPagosHoy(pagina);
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

  String _filtroDeudaDatasource(LocalFiltroDeuda filtro) {
    return switch (filtro) {
      LocalFiltroDeuda.soloDeudores => 'deudores',
      LocalFiltroDeuda.soloSaldosAFavor => 'saldos',
      _ => 'todos',
    };
  }

  List<String>? _resolverFilterLocalIds() {
    if (state.usuarioFiltradoId == null) return null;
    final usuarios = ref.read(usuariosProvider).value ?? [];
    final usuario = usuarios.whereType<Usuario>().firstWhere(
      (u) => u.id == state.usuarioFiltradoId,
      orElse: () => const Usuario(),
    );
    return usuario.rutaAsignada;
  }

  Future<List<Local>> _cargarTodosFiltrados({
    required String municipalidadId,
    String? mercadoId,
    String? searchQuery,
    required String filtroDeuda,
    List<String>? filterLocalIds,
  }) async {
    final List<Local> all = [];
    QueryDocumentSnapshot? lastDoc;
    var hasMore = true;

    while (hasMore) {
      final docs = await _ds.listarPaginaPorMunicipalidad(
        municipalidadId: municipalidadId,
        mercadoId: mercadoId,
        searchQuery: searchQuery,
        lastDoc: lastDoc,
        limit: _exportPageSize,
        filtroDeuda: filtroDeuda,
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

  void _ordenarLocales(List<Local> list, LocalOrdenamiento ordenamiento) {
    switch (ordenamiento) {
      case LocalOrdenamiento.alfabeticoAsc:
        list.sort(
          (a, b) => (a.nombreSocial ?? '').toLowerCase().compareTo(
            (b.nombreSocial ?? '').toLowerCase(),
          ),
        );
        break;
      case LocalOrdenamiento.alfabeticoDesc:
        list.sort(
          (a, b) => (b.nombreSocial ?? '').toLowerCase().compareTo(
            (a.nombreSocial ?? '').toLowerCase(),
          ),
        );
        break;
      case LocalOrdenamiento.cuotaMayor:
        list.sort((a, b) => (b.cuotaDiaria ?? 0).compareTo(a.cuotaDiaria ?? 0));
        break;
      case LocalOrdenamiento.cuotaMenor:
        list.sort((a, b) => (a.cuotaDiaria ?? 0).compareTo(b.cuotaDiaria ?? 0));
        break;
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
      localesPagadosHoy: const {},
    );
    await _fetchPagina();
  }

  /// Exporta todos los locales con los filtros actuales (sin afectar el estado de la UI).
  Future<List<Local>> exportarLocalesFiltrados() async {
    final municipalidadId = _municipalidadId;
    final mercadoId = state.mercadoSeleccionadoId;
    final query = state.busqueda;
    final filtroDs = _filtroDeudaDatasource(state.filtroDeuda);
    final filterLocalIds = _resolverFilterLocalIds();

    if (mercadoId == null && municipalidadId == null) return [];
    final all = await _cargarTodosFiltrados(
      municipalidadId: municipalidadId!,
      mercadoId: mercadoId,
      searchQuery: null,
      filtroDeuda: filtroDs,
      filterLocalIds: filterLocalIds,
    );

    final filtrados = _filtrarLocalesPorBusquedaAvanzada(all, query);
    _ordenarLocales(filtrados, state.ordenamiento);
    return filtrados;
  }

  List<Local> _filtrarLocalesPorBusquedaAvanzada(
    List<Local> locales,
    String? query,
  ) {
    final q = _normalizarTexto(query);
    if (q.isEmpty) return locales;

    final mercados = ref.read(mercadosProvider).value ?? const <Mercado>[];
    final mercadoNombreById = {
      for (final m in mercados)
        if ((m.id ?? '').isNotEmpty)
          _normalizarTexto(m.id!): _normalizarTexto(m.nombre),
    };

    final usuarios = ref.read(usuariosProvider).value ?? const <Usuario>[];
    final Map<String, Set<String>> cobradoresPorLocalId = {};
    for (final u in usuarios) {
      final nombre = _normalizarTexto(u.nombre);
      final codigo = _normalizarTexto(u.codigoCobrador);
      final ruta = u.rutaAsignada ?? const <String>[];
      for (final localId in ruta) {
        final key = _normalizarTexto(localId);
        if (key.isEmpty) continue;
        final bucket = cobradoresPorLocalId.putIfAbsent(key, () => <String>{});
        if (nombre.isNotEmpty) bucket.add(nombre);
        if (codigo.isNotEmpty) bucket.add(codigo);
      }
    }

    return locales.where((l) {
      final localIdNorm = _normalizarTexto(l.id);
      final cobradores = cobradoresPorLocalId[localIdNorm] ?? const <String>{};
      final mercadoNombre =
          mercadoNombreById[_normalizarTexto(l.mercadoId)] ?? '';
      final searchable = <String>[
        _normalizarTexto(l.nombreSocial),
        _normalizarTexto(l.representante),
        _normalizarTexto(l.telefonoRepresentante),
        _normalizarTexto(l.codigo),
        _normalizarTexto(l.clave),
        _normalizarTexto(l.codigoCatastral),
        _normalizarTexto(l.ruta),
        _normalizarTexto(l.id),
        _normalizarTexto(l.qrData),
        mercadoNombre,
        ...cobradores,
      ].where((s) => s.isNotEmpty);

      for (final value in searchable) {
        if (value.contains(q)) return true;
      }
      return false;
    }).toList();
  }

  String _normalizarTexto(String? value) {
    var text = (value ?? '').toLowerCase().trim();
    if (text.isEmpty) return '';
    const map = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    map.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }
}

final localesPaginadosProvider =
    NotifierProvider<LocalesPaginadosNotifier, LocalesPaginadosState>(
      LocalesPaginadosNotifier.new,
    );
