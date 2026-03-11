import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider expuesto a la UI
final firestoreViewerProvider = NotifierProvider<FirestoreViewerNotifier, FirestoreViewerState>(FirestoreViewerNotifier.new);

class FirestoreViewerState {
  final String? coleccionActual;
  final List<DocumentSnapshot<Map<String, dynamic>>> documentos;
  final bool cargando;
  final bool hayMas;
  final String? error;
  final DocumentSnapshot? ultimoDoc;

  FirestoreViewerState({
    this.coleccionActual,
    this.documentos = const [],
    this.cargando = false,
    this.hayMas = true,
    this.error,
    this.ultimoDoc,
  });

  FirestoreViewerState copyWith({
    String? coleccionActual,
    List<DocumentSnapshot<Map<String, dynamic>>>? documentos,
    bool? cargando,
    bool? hayMas,
    String? error,
    DocumentSnapshot? ultimoDoc,
    bool clearError = false,
  }) {
    return FirestoreViewerState(
      coleccionActual: coleccionActual ?? this.coleccionActual,
      documentos: documentos ?? this.documentos,
      cargando: cargando ?? this.cargando,
      hayMas: hayMas ?? this.hayMas,
      error: clearError ? null : (error ?? this.error),
      ultimoDoc: ultimoDoc ?? this.ultimoDoc,
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
    state = FirestoreViewerState(coleccionActual: nombreColeccion, cargando: true);
    _cargarPagina();
  }


  Future<void> cargarMas() async {
    if (state.cargando || !state.hayMas || state.coleccionActual == null) return;
    
    state = state.copyWith(cargando: true, clearError: true);
    await _cargarPagina();
  }

  Future<void> _cargarPagina() async {
    try {
      final db = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> query = db.collection(state.coleccionActual!).limit(_limit);

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
      
      state = state.copyWith(
        documentos: [...state.documentos, ...nuevosDocs],
        ultimoDoc: nuevosDocs.last,
        cargando: false,
        hayMas: nuevosDocs.length == _limit,
      );
      
    } catch (e) {
      state = state.copyWith(
        cargando: false,
        error: e.toString(),
      );
    }
  }
}
