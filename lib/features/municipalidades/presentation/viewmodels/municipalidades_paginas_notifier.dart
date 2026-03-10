import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../municipalidades/domain/entities/municipalidad.dart';

class MunicipalidadesPaginadasState {
  final List<Municipalidad> municipalidades;
  final bool cargando;
  final String? errorMsg;
  final bool hayMas;
  final int paginaActual;
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final String? searchQuery;

  MunicipalidadesPaginadasState({
    this.municipalidades = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.searchQuery,
  });

  MunicipalidadesPaginadasState copyWith({
    List<Municipalidad>? municipalidades,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    String? searchQuery,
  }) {
    return MunicipalidadesPaginadasState(
      municipalidades: municipalidades ?? this.municipalidades,
      cargando: cargando ?? this.cargando,
      errorMsg: errorMsg,
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class MunicipalidadesPaginadasNotifier extends Notifier<MunicipalidadesPaginadasState> {
  static const int _pageSize = 20;

  @override
  MunicipalidadesPaginadasState build() {
    return MunicipalidadesPaginadasState();
  }

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    state = state.copyWith(cargando: true, errorMsg: null);

    try {
      final firestore = ref.read(firestoreProvider);
      Query<Map<String, dynamic>> query = firestore
          .collection('municipalidades')
          .orderBy('nombre');

      final snapshotActual =
          reiniciar ? null : state.snapshotsPaginas[state.paginaActual - 1];

      if (snapshotActual != null) {
        query = query.startAfterDocument(snapshotActual);
      }

      final result = await query.limit(_pageSize + 1).get();

      final docs = result.docs;
      final hayMas = docs.length > _pageSize;
      final docsAMostrar = hayMas ? docs.sublist(0, _pageSize) : docs;

      final municipalidadesList =
          docsAMostrar.map((doc) {
            return _mapDocToMunicipalidad(doc);
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
        municipalidades: municipalidadesList,
        cargando: false,
        hayMas: hayMas,
        paginaActual: reiniciar ? 1 : state.paginaActual,
        snapshotsPaginas: nuevasPaginas,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar municipalidades: $e',
      );
    }
  }

  Municipalidad _mapDocToMunicipalidad(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Municipalidad(
      id: doc.id,
      nombre: data['nombre'],
      municipio: data['municipio'],
      departamento: data['departamento'],
      porcentaje: data['porcentaje'],
      activa: data['activa'] ?? true,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: data['creadoPor'],
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

final municipalidadesPaginadasProvider = NotifierProvider<
  MunicipalidadesPaginadasNotifier,
  MunicipalidadesPaginadasState
>(() => MunicipalidadesPaginadasNotifier());
