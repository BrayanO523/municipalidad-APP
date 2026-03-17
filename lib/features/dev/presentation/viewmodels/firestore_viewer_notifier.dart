import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

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
  final String filterField;
  final String filterValue;
  final List<String> availableFields;

  FirestoreViewerState({
    this.coleccionActual,
    this.documentos = const [],
    this.cargando = false,
    this.hayMas = true,
    this.error,
    this.ultimoDoc,
    this.searchTerm = '',
    this.filterField = '',
    this.filterValue = '',
    this.availableFields = const [],
  });

  FirestoreViewerState copyWith({
    String? coleccionActual,
    List<DocumentSnapshot<Map<String, dynamic>>>? documentos,
    bool? cargando,
    bool? hayMas,
    String? error,
    DocumentSnapshot? ultimoDoc,
    String? searchTerm,
    String? filterField,
    String? filterValue,
    List<String>? availableFields,
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
      filterField: filterField ?? this.filterField,
      filterValue: filterValue ?? this.filterValue,
      availableFields: availableFields ?? this.availableFields,
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
      filterField: '',
      filterValue: '',
      availableFields: const [],
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
    if (state.cargando || !state.hayMas || state.coleccionActual == null) {
      return;
    }

    state = state.copyWith(cargando: true, clearError: true);
    await _cargarPagina();
  }

  void aplicarFiltroCampoValor(String field, String value) {
    // Solo disponible en debug
    if (!kDebugMode) return;
    state = state.copyWith(
      filterField: field.trim(),
      filterValue: value.trim(),
      documentos: [],
      ultimoDoc: null,
      hayMas: true,
      cargando: true,
      clearError: true,
    );
    if (state.coleccionActual != null) {
      _cargarPagina();
    }
  }

  Future<void> eliminarDoc(String docId) async {
    if (!kDebugMode) return;
    if (state.coleccionActual == null) return;
    final db = FirebaseFirestore.instance;
    await db.collection(state.coleccionActual!).doc(docId).delete();
    // Refrescar vista
    state = state.copyWith(
      documentos: [],
      ultimoDoc: null,
      hayMas: true,
      cargando: true,
    );
    await _cargarPagina();
  }

  Future<void> actualizarDoc(String docId, Map<String, dynamic> data,
      {bool merge = true}) async {
    if (!kDebugMode) return;
    if (state.coleccionActual == null) return;
    final db = FirebaseFirestore.instance;
    await db
        .collection(state.coleccionActual!)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
    state = state.copyWith(
      documentos: [],
      ultimoDoc: null,
      hayMas: true,
      cargando: true,
    );
    await _cargarPagina();
  }

  Future<void> _cargarPagina() async {
    try {
      final db = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> baseQuery = db.collection(state.coleccionActual!);

      DocumentSnapshot? last = state.ultimoDoc;
      final List<DocumentSnapshot<Map<String, dynamic>>> matches = [];
      bool hasMore = true;
      int guard = 0;
      final Set<String> fields = state.availableFields.toSet();

      while (hasMore && matches.length < _limit && guard < 10) {
        guard++;
        var query = baseQuery.limit(_limit);
        if (last != null) query = query.startAfterDocument(last);

        final snap = await query.get();
        if (snap.docs.isEmpty) {
          hasMore = false;
          break;
        }

        final nuevosDocs = snap.docs;
        last = nuevosDocs.last;
        for (final d in nuevosDocs) {
          fields.addAll(d.data().keys);
        }
        final searchTerm = state.searchTerm.toLowerCase();
        final filterField = state.filterField;
        final filterValue = state.filterValue.toLowerCase();

        for (final doc in nuevosDocs) {
          final Map<String, dynamic> data = doc.data();
          final searchable = _convertToSearchableString(data).toLowerCase();

          final bySearch = searchTerm.isEmpty
              ? true
              : (doc.id.toLowerCase().contains(searchTerm) ||
                  searchable.contains(searchTerm));

          final byField = (filterField.isEmpty || filterValue.isEmpty)
              ? true
              : (() {
                  final val = data[filterField];
                  if (val == null) return false;
                  final s = val.toString().toLowerCase();
                  return s.contains(filterValue);
                })();

          if (bySearch && byField) {
            matches.add(doc);
          }
        }

        hasMore = nuevosDocs.length == _limit;

        // Si estamos buscando y aún no encontramos nada, seguir a la siguiente página
        if (state.searchTerm.isNotEmpty && matches.isEmpty && hasMore) {
          continue;
        } else {
          break;
        }
      }

      state = state.copyWith(
        documentos: [...state.documentos, ...matches],
        ultimoDoc: last,
        cargando: false,
        hayMas: hasMore,
        availableFields: fields.toList()..sort(),
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
