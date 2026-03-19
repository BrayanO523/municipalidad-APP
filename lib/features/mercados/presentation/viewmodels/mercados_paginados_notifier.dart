import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../mercados/domain/entities/mercado.dart';

class MercadosPaginadosState {
  final List<Mercado> mercados;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final int totalPaginas;
  final int totalRegistros;
  final String searchQuery;
  final String searchColumn;
  final bool ordenarNombreAsc;
  final String estadoFilter;

  const MercadosPaginadosState({
    this.mercados = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.totalPaginas = 1,
    this.totalRegistros = 0,
    this.searchQuery = '',
    this.searchColumn = 'Todos',
    this.ordenarNombreAsc = true,
    this.estadoFilter = 'Todos',
  });

  MercadosPaginadosState copyWith({
    List<Mercado>? mercados,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    int? totalPaginas,
    int? totalRegistros,
    String? searchQuery,
    String? searchColumn,
    bool? ordenarNombreAsc,
    String? estadoFilter,
    bool clearError = false,
  }) {
    return MercadosPaginadosState(
      mercados: mercados ?? this.mercados,
      cargando: cargando ?? this.cargando,
      errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      totalRegistros: totalRegistros ?? this.totalRegistros,
      searchQuery: searchQuery ?? this.searchQuery,
      searchColumn: searchColumn ?? this.searchColumn,
      ordenarNombreAsc: ordenarNombreAsc ?? this.ordenarNombreAsc,
      estadoFilter: estadoFilter ?? this.estadoFilter,
    );
  }
}

class MercadosPaginadosNotifier extends Notifier<MercadosPaginadosState> {
  static const int _pageSize = 20;

  @override
  MercadosPaginadosState build() => const MercadosPaginadosState();

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    final targetPage = reiniciar ? 1 : state.paginaActual;
    state = state.copyWith(cargando: true, clearError: true);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUsuarioProvider).value;
      final municipalidadId = user?.municipalidadId;

      Query<Map<String, dynamic>> query = firestore
          .collection('mercados')
          .orderBy('nombre');

      if (municipalidadId != null) {
        query = query.where('municipalidadId', isEqualTo: municipalidadId);
      }

      final result = await query.get();
      final todos = result.docs.map(_mapDocToMercado).toList(growable: false);
      final filtradosPorEstado = _aplicarFiltroEstado(
        todos,
        state.estadoFilter,
      );

      final filtrados = _aplicarBusqueda(
        filtradosPorEstado,
        query: state.searchQuery,
        column: state.searchColumn,
      );

      final ordenados = [...filtrados]
        ..sort((a, b) {
          final cmp = (a.nombre ?? '').toLowerCase().compareTo(
            (b.nombre ?? '').toLowerCase(),
          );
          return state.ordenarNombreAsc ? cmp : -cmp;
        });

      final totalRegistros = ordenados.length;
      final totalPaginas = totalRegistros == 0
          ? 1
          : (totalRegistros / _pageSize).ceil();
      final paginaActual = targetPage.clamp(1, totalPaginas);

      final start = (paginaActual - 1) * _pageSize;
      final endExclusive = (start + _pageSize > totalRegistros)
          ? totalRegistros
          : start + _pageSize;
      final mercadosPagina = start >= totalRegistros
          ? <Mercado>[]
          : ordenados.sublist(start, endExclusive);

      state = state.copyWith(
        mercados: mercadosPagina,
        cargando: false,
        hayMas: paginaActual < totalPaginas,
        paginaActual: paginaActual,
        totalPaginas: totalPaginas,
        totalRegistros: totalRegistros,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar mercados: $e',
      );
    }
  }

  List<Mercado> _aplicarFiltroEstado(List<Mercado> mercados, String estado) {
    return switch (estado) {
      'Activo' =>
        mercados.where((m) => m.activo == true).toList(growable: false),
      'Inactivo' =>
        mercados.where((m) => m.activo == false).toList(growable: false),
      _ => mercados,
    };
  }

  List<Mercado> _aplicarBusqueda(
    List<Mercado> mercados, {
    required String query,
    required String column,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return mercados;

    bool matches(Mercado m) {
      final estado = (m.activo ?? false) ? 'activo' : 'inactivo';
      final campos = switch (column) {
        'Nombre' => <String>[m.nombre ?? ''],
        'Ubicacion' => <String>[m.ubicacion ?? ''],
        'Estado' => <String>[estado],
        _ => <String>[m.nombre ?? '', m.ubicacion ?? '', estado],
      };
      return campos.any((c) => c.toLowerCase().contains(q));
    }

    return mercados.where(matches).toList(growable: false);
  }

  Mercado _mapDocToMercado(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Mercado(
      id: doc.id,
      nombre: data['nombre'],
      ubicacion: data['ubicacion'],
      municipalidadId: data['municipalidadId'],
      activo: data['activo'] ?? true,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: data['creadoPor'],
      perimetro: data['perimetro'] != null
          ? List<Map<String, double>>.from(
              (data['perimetro'] as List).map(
                (p) => {
                  'lat': (p['lat'] as num).toDouble(),
                  'lng': (p['lng'] as num).toDouble(),
                },
              ),
            )
          : null,
      latitud: (data['latitud'] as num?)?.toDouble(),
      longitud: (data['longitud'] as num?)?.toDouble(),
    );
  }

  void irAPaginaSiguiente() {
    if (!state.cargando && state.paginaActual < state.totalPaginas) {
      state = state.copyWith(paginaActual: state.paginaActual + 1);
      cargarPagina();
    }
  }

  void irAPaginaAnterior() {
    if (!state.cargando && state.paginaActual > 1) {
      state = state.copyWith(paginaActual: state.paginaActual - 1);
      cargarPagina();
    }
  }

  void buscar(String query) {
    state = state.copyWith(searchQuery: query);
    cargarPagina(reiniciar: true);
  }

  void cambiarColumnaBusqueda(String column) {
    if (state.searchColumn == column) return;
    state = state.copyWith(searchColumn: column);
    cargarPagina(reiniciar: true);
  }

  void cambiarOrdenNombre(bool ascendente) {
    if (state.ordenarNombreAsc == ascendente) return;
    state = state.copyWith(ordenarNombreAsc: ascendente, paginaActual: 1);
    cargarPagina(reiniciar: true);
  }

  Future<void> aplicarFiltros({
    String? searchQuery,
    String? searchColumn,
    bool? ordenarNombreAsc,
    String? estadoFilter,
  }) async {
    state = state.copyWith(
      searchQuery: searchQuery,
      searchColumn: searchColumn,
      ordenarNombreAsc: ordenarNombreAsc,
      estadoFilter: estadoFilter,
      paginaActual: 1,
    );
    await cargarPagina(reiniciar: true);
  }

  Future<void> restablecerFiltros() async {
    state = state.copyWith(
      searchQuery: '',
      searchColumn: 'Todos',
      ordenarNombreAsc: true,
      estadoFilter: 'Todos',
      paginaActual: 1,
    );
    await cargarPagina(reiniciar: true);
  }

  Future<void> recargar() => cargarPagina(reiniciar: true);
}

final mercadosPaginadosProvider =
    NotifierProvider<MercadosPaginadosNotifier, MercadosPaginadosState>(
      MercadosPaginadosNotifier.new,
    );
