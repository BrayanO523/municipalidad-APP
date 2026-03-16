import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider expuesto a la UI
final firestoreViewerProvider =
    NotifierProvider<FirestoreViewerNotifier, FirestoreViewerState>(
      FirestoreViewerNotifier.new,
    );

class FirestoreViewerState {
  final String? coleccionActual;
  final List<DocumentSnapshot<Map<String, dynamic>>> documentos;
  final bool cargando;
  final bool hayMas;
  final String? error;
  final DocumentSnapshot? ultimoDoc;
  final String searchTerm;

  FirestoreViewerState({
    this.coleccionActual,
    this.documentos = const [],
    this.cargando = false,
    this.hayMas = true,
    this.error,
    this.ultimoDoc,
    this.searchTerm = '',
  });

  FirestoreViewerState copyWith({
    String? coleccionActual,
    List<DocumentSnapshot<Map<String, dynamic>>>? documentos,
    bool? cargando,
    bool? hayMas,
    String? error,
    DocumentSnapshot? ultimoDoc,
    String? searchTerm,
    bool clearError = false,
  }) {
    return FirestoreViewerState(
      coleccionActual: coleccionActual ?? this.coleccionActual,
      documentos: documentos ?? this.documentos,
      cargando: cargando ?? this.cargando,
      hayMas: hayMas ?? this.hayMas,
      error: clearError ? null : (error ?? this.error),
      ultimoDoc: ultimoDoc ?? this.ultimoDoc,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }
}

class FirestoreViewerNotifier extends Notifier<FirestoreViewerState> {
  @override
  FirestoreViewerState build() {
    return FirestoreViewerState();
  }

  static const int _limit = 20;

  void cambiarColeccion(String nombreColeccion) {
    state = FirestoreViewerState(
      coleccionActual: nombreColeccion,
      cargando: true,
    );
    _cargarPagina();
  }

  void actualizarBusqueda(String term) {
    // Si el término cambió, resetear la lista y recargar
    if (term != state.searchTerm) {
      state = state.copyWith(
        searchTerm: term,
        documentos: [],
        ultimoDoc: null,
        hayMas: true,
        clearError: true,
      );
      if (state.coleccionActual != null) {
        _cargarPagina();
      }
    }
  }

  Future<void> cargarMas() async {
    if (state.cargando || !state.hayMas || state.coleccionActual == null)
      return;

    state = state.copyWith(cargando: true, clearError: true);
    await _cargarPagina();
  }

  Future<void> _cargarPagina() async {
    try {
      final db = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> query = db
          .collection(state.coleccionActual!)
          .limit(_limit);

      if (state.ultimoDoc != null) {
        query = query.startAfterDocument(state.ultimoDoc!);
      }

      // IMPORTANTE: Un GET() de una sola vez, NO un stream para no consumir cuota por interacciones
      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        state = state.copyWith(cargando: false, hayMas: false);
        return;
      }

      final nuevosDocs = querySnapshot.docs;

      // Aplicar filtro de búsqueda si hay un término de búsqueda
      final documentosFiltrados = state.searchTerm.isEmpty
          ? nuevosDocs
          : nuevosDocs.where((doc) {
              final searchTerm = state.searchTerm.toLowerCase();

              // Buscar en el ID del documento
              if (doc.id.toLowerCase().contains(searchTerm)) {
                return true;
              }

              // Buscar en el contenido del documento
              final data = doc.data();
              if (data != null) {
                final jsonString = _convertToSearchableString(
                  data,
                ).toLowerCase();
                return jsonString.contains(searchTerm);
              }

              return false;
            }).toList();

      state = state.copyWith(
        documentos: [...state.documentos, ...documentosFiltrados],
        ultimoDoc: nuevosDocs.last,
        cargando: false,
        hayMas:
            nuevosDocs.length ==
            _limit, // Mantener la paginación basada en docs totales
      );
    } catch (e) {
      state = state.copyWith(cargando: false, error: e.toString());
    }
  }

  String _convertToSearchableString(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    void addValue(dynamic value) {
      if (value == null) return;

      if (value is String) {
        buffer.write(value);
        buffer.write(' ');
      } else if (value is num) {
        buffer.write(value.toString());
        buffer.write(' ');
      } else if (value is bool) {
        buffer.write(value.toString());
        buffer.write(' ');
      } else if (value is Map<String, dynamic>) {
        for (final entry in value.entries) {
          buffer.write(entry.key);
          buffer.write(' ');
          addValue(entry.value);
        }
      } else if (value is List) {
        for (final item in value) {
          addValue(item);
        }
      } else {
        // Para otros tipos (Timestamp, etc.), convertir a string
        buffer.write(value.toString());
        buffer.write(' ');
      }
    }

    for (final entry in data.entries) {
      buffer.write(entry.key);
      buffer.write(' ');
      addValue(entry.value);
    }

    return buffer.toString();
  }
}
