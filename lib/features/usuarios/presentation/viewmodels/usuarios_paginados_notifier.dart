import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../usuarios/domain/entities/usuario.dart';

class UsuariosPaginadosState {
  static const Object _noChange = Object();

  final List<Usuario> usuarios;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final int totalPaginas;
  final int totalRegistros;
  final String searchQuery;
  final String searchColumn;
  final bool ordenarNombreAsc;
  final String? mercadoIdFilter;

  const UsuariosPaginadosState({
    this.usuarios = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.totalPaginas = 1,
    this.totalRegistros = 0,
    this.searchQuery = '',
    this.searchColumn = 'Todos',
    this.ordenarNombreAsc = true,
    this.mercadoIdFilter,
  });

  UsuariosPaginadosState copyWith({
    List<Usuario>? usuarios,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    int? totalPaginas,
    int? totalRegistros,
    String? searchQuery,
    String? searchColumn,
    bool? ordenarNombreAsc,
    Object? mercadoIdFilter = _noChange,
    bool clearError = false,
  }) {
    return UsuariosPaginadosState(
      usuarios: usuarios ?? this.usuarios,
      cargando: cargando ?? this.cargando,
      errorMsg: clearError ? null : (errorMsg ?? this.errorMsg),
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      totalRegistros: totalRegistros ?? this.totalRegistros,
      searchQuery: searchQuery ?? this.searchQuery,
      searchColumn: searchColumn ?? this.searchColumn,
      ordenarNombreAsc: ordenarNombreAsc ?? this.ordenarNombreAsc,
      mercadoIdFilter: identical(mercadoIdFilter, _noChange)
          ? this.mercadoIdFilter
          : mercadoIdFilter as String?,
    );
  }
}

class UsuariosPaginadosNotifier extends Notifier<UsuariosPaginadosState> {
  static const int _pageSize = 20;

  @override
  UsuariosPaginadosState build() => const UsuariosPaginadosState();

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    final targetPage = reiniciar ? 1 : state.paginaActual;
    state = state.copyWith(cargando: true, clearError: true);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUsuarioProvider).value;
      final municipalidadId = user?.municipalidadId;

      Query<Map<String, dynamic>> query = firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'cobrador');

      if (municipalidadId != null) {
        query = query.where('municipalidadId', isEqualTo: municipalidadId);
      }

      final result = await query.get();
      final todos = result.docs.map(_mapDocToUsuario).toList();

      final filtradosPorMercado =
          state.mercadoIdFilter == null || state.mercadoIdFilter!.isEmpty
          ? todos
          : todos
                .where((u) => (u.mercadoId ?? '') == state.mercadoIdFilter)
                .toList(growable: false);

      final filtrados = _aplicarBusqueda(
        filtradosPorMercado,
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

      final totalRegistros = filtrados.length;
      final totalPaginas = totalRegistros == 0
          ? 1
          : (totalRegistros / _pageSize).ceil();
      final paginaActual = targetPage.clamp(1, totalPaginas);

      final start = (paginaActual - 1) * _pageSize;
      final endExclusive = (start + _pageSize > totalRegistros)
          ? totalRegistros
          : start + _pageSize;

      final usuariosPagina = start >= totalRegistros
          ? <Usuario>[]
          : ordenados.sublist(start, endExclusive);

      state = state.copyWith(
        usuarios: usuariosPagina,
        cargando: false,
        hayMas: paginaActual < totalPaginas,
        paginaActual: paginaActual,
        totalPaginas: totalPaginas,
        totalRegistros: totalRegistros,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar usuarios: $e',
      );
    }
  }

  List<Usuario> _aplicarBusqueda(
    List<Usuario> usuarios, {
    required String query,
    required String column,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return usuarios;

    bool matches(Usuario u) {
      final estado = (u.ultimoCorrelativo ?? 0) > 0 ? 'activo' : 'sin cobros';
      final campos = switch (column) {
        'Nombre' => <String>[u.nombre ?? ''],
        'Correo electronico' => <String>[u.email ?? ''],
        'Codigo' => <String>[u.codigoCobrador ?? ''],
        'Anio' => <String>[
          (u.anioCorrelativo ?? DateTime.now().year).toString(),
        ],
        'Ultimo correlativo' => <String>[(u.ultimoCorrelativo ?? 0).toString()],
        'Estado' => <String>[estado],
        'Mercado' => <String>[u.mercadoId ?? ''],
        _ => <String>[
          u.nombre ?? '',
          u.email ?? '',
          u.codigoCobrador ?? '',
          u.mercadoId ?? '',
          (u.anioCorrelativo ?? DateTime.now().year).toString(),
          (u.ultimoCorrelativo ?? 0).toString(),
          estado,
        ],
      };
      return campos.any((c) => c.toLowerCase().contains(q));
    }

    return usuarios.where(matches).toList(growable: false);
  }

  Usuario _mapDocToUsuario(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Usuario(
      id: doc.id,
      nombre: data['nombre'],
      email: data['email'] ?? data['correo'],
      rol: data['rol'],
      municipalidadId: data['municipalidadId'],
      mercadoId: data['mercadoId'],
      rutaAsignada: data['rutaAsignada'] != null
          ? List<String>.from(data['rutaAsignada'])
          : null,
      activo: data['activo'] ?? true,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
      ultimoCorrelativo: (data['ultimoCorrelativo'] as num?)?.toInt(),
      anioCorrelativo: (data['anioCorrelativo'] as num?)?.toInt(),
      codigoCobrador: data['codigoCobrador'],
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
    String? mercadoIdFilter,
  }) async {
    state = state.copyWith(
      searchQuery: searchQuery,
      searchColumn: searchColumn,
      ordenarNombreAsc: ordenarNombreAsc,
      mercadoIdFilter: mercadoIdFilter,
      paginaActual: 1,
    );
    await cargarPagina(reiniciar: true);
  }

  void cambiarFiltroMercado(String? mercadoId) {
    final normalized = (mercadoId == null || mercadoId.isEmpty)
        ? null
        : mercadoId;
    if (state.mercadoIdFilter == normalized) return;
    state = state.copyWith(mercadoIdFilter: normalized, paginaActual: 1);
    cargarPagina(reiniciar: true);
  }

  Future<void> restablecerFiltros() async {
    state = state.copyWith(
      searchQuery: '',
      searchColumn: 'Todos',
      ordenarNombreAsc: true,
      mercadoIdFilter: null,
      paginaActual: 1,
    );
    await cargarPagina(reiniciar: true);
  }

  Future<void> recargar() => cargarPagina(reiniciar: true);
}

final usuariosPaginadosProvider =
    NotifierProvider<UsuariosPaginadosNotifier, UsuariosPaginadosState>(
      UsuariosPaginadosNotifier.new,
    );
