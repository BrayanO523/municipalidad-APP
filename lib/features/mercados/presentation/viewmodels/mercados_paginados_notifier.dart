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
  final List<QueryDocumentSnapshot?> snapshotsPaginas;
  final String? searchQuery;

  MercadosPaginadosState({
    this.mercados = const [],
    this.cargando = false,
    this.errorMsg,
    this.hayMas = false,
    this.paginaActual = 1,
    this.snapshotsPaginas = const [null],
    this.searchQuery,
  });

  MercadosPaginadosState copyWith({
    List<Mercado>? mercados,
    bool? cargando,
    String? errorMsg,
    bool? hayMas,
    int? paginaActual,
    List<QueryDocumentSnapshot?>? snapshotsPaginas,
    String? searchQuery,
  }) {
    return MercadosPaginadosState(
      mercados: mercados ?? this.mercados,
      cargando: cargando ?? this.cargando,
      errorMsg: errorMsg,
      hayMas: hayMas ?? this.hayMas,
      paginaActual: paginaActual ?? this.paginaActual,
      snapshotsPaginas: snapshotsPaginas ?? this.snapshotsPaginas,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class MercadosPaginadosNotifier extends Notifier<MercadosPaginadosState> {
  static const int _pageSize = 20;

  @override
  MercadosPaginadosState build() {
    return MercadosPaginadosState();
  }

  Future<void> cargarPagina({bool reiniciar = false}) async {
    if (state.cargando) return;

    state = state.copyWith(cargando: true, errorMsg: null);

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

      final snapshotActual =
          reiniciar ? null : state.snapshotsPaginas[state.paginaActual - 1];

      if (snapshotActual != null) {
        query = query.startAfterDocument(snapshotActual);
      }

      final result = await query.limit(_pageSize + 1).get();

      final docs = result.docs;
      final hayMas = docs.length > _pageSize;
      final docsAMostrar = hayMas ? docs.sublist(0, _pageSize) : docs;

      final mercadosList =
          docsAMostrar.map((doc) {
            return _mapDocToMercado(doc);
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
        mercados: mercadosList,
        cargando: false,
        hayMas: hayMas,
        paginaActual: reiniciar ? 1 : state.paginaActual,
        snapshotsPaginas: nuevasPaginas,
      );
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        errorMsg: 'Error al cargar mercados: $e',
      );
    }
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
          ? List<Map<String, double>>.from((data['perimetro'] as List).map((p) => {
              'lat': (p['lat'] as num).toDouble(),
              'lng': (p['lng'] as num).toDouble(),
            }))
          : null,
      latitud: (data['latitud'] as num?)?.toDouble(),
      longitud: (data['longitud'] as num?)?.toDouble(),
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

final mercadosPaginadosProvider = NotifierProvider<
  MercadosPaginadosNotifier,
  MercadosPaginadosState
>(() => MercadosPaginadosNotifier());
