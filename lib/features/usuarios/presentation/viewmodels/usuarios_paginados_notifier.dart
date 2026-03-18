import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../usuarios/domain/entities/usuario.dart';

class UsuariosPaginadosState {
  final List<Usuario> usuarios;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final int totalPaginas;
  final int totalRegistros;
  final String searchQuery;
  final String searchColumn;

  const UsuariosPaginadosState({
    this.usuarios = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.totalPaginas = 1,
    this.totalRegistros = 0,
    this.searchQuery = '',
    this.searchColumn = 'Nombre',
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
      final todos = result.docs.map(_mapDocToUsuario).toList()
        ..sort((a, b) => (a.nombre ?? '').compareTo(b.nombre ?? ''));

      final filtrados = _aplicarBusqueda(
        todos,
        query: state.searchQuery,
        column: state.searchColumn,
      );

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
          : filtrados.sublist(start, endExclusive);

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
      switch (column) {
        case 'Correo electronico':
          return (u.email ?? '').toLowerCase().contains(q);
        case 'Codigo':
          return (u.codigoCobrador ?? '').toLowerCase().contains(q);
        case 'Anio':
          return (u.anioCorrelativo ?? DateTime.now().year).toString().contains(
            q,
          );
        case 'Ultimo correlativo':
          return (u.ultimoCorrelativo ?? 0).toString().contains(q);
        case 'Estado':
          final estado = (u.ultimoCorrelativo ?? 0) > 0
              ? 'activo'
              : 'sin cobros';
          return estado.contains(q);
        case 'Mercado':
          return (u.mercadoId ?? '').toLowerCase().contains(q);
        case 'Nombre':
        default:
          return (u.nombre ?? '').toLowerCase().contains(q);
      }
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

  Future<void> restablecerFiltros() async {
    state = state.copyWith(
      searchQuery: '',
      searchColumn: 'Nombre',
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
