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
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final String? searchQuery;

  UsuariosPaginadosState({
    this.usuarios = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.searchQuery,
  });

  UsuariosPaginadosState copyWith({
    List<Usuario>? usuarios,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    String? searchQuery,
  }) {
    return UsuariosPaginadosState(
      usuarios: usuarios ?? this.usuarios,
      cargando: cargando ?? this.cargando,
      errorMsg: errorMsg,
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class UsuariosPaginadosNotifier extends Notifier<UsuariosPaginadosState> {
  static const int _pageSize = 20;

  @override
  UsuariosPaginadosState build() {
    return UsuariosPaginadosState();
  }

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    state = state.copyWith(cargando: true, errorMsg: null);

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

      query = query.orderBy('nombre');

      final snapshotActual =
          reiniciar ? null : state.snapshotsPaginas[state.paginaActual - 1];

      if (snapshotActual != null) {
        query = query.startAfterDocument(snapshotActual);
      }

      final result = await query.limit(_pageSize + 1).get();

      final docs = result.docs;
      final hayMas = docs.length > _pageSize;
      final docsAMostrar = hayMas ? docs.sublist(0, _pageSize) : docs;

      final usuariosList =
          docsAMostrar.map((doc) {
            return _mapDocToUsuario(doc);
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
        usuarios: usuariosList,
        cargando: false,
        hayMas: hayMas,
        paginaActual: reiniciar ? 1 : state.paginaActual,
        snapshotsPaginas: nuevasPaginas,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar usuarios: $e',
      );
    }
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

  void buscar(String query) {
    state = state.copyWith(searchQuery: query);
    cargarPagina(reiniciar: true);
  }

  Future<void> recargar() => cargarPagina(reiniciar: true);
}

final usuariosPaginadosProvider = NotifierProvider<
  UsuariosPaginadosNotifier,
  UsuariosPaginadosState
>(() => UsuariosPaginadosNotifier());
