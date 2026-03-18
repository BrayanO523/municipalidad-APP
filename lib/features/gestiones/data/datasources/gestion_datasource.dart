import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/gestion.dart';

/// Datasource de Firestore para la colección `gestiones`.
/// Maneja la persistencia de incidencias/gestiones del cobrador.
class GestionDatasource {
  final FirebaseFirestore _firestore;

  GestionDatasource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('gestiones');

  /// Registra una nueva gestión/incidencia.
  Future<void> registrarGestion({
    required String localId,
    required String cobradorId,
    required String tipoIncidencia,
    String? comentario,
    double? latitud,
    double? longitud,
    String? municipalidadId,
    String? mercadoId,
  }) async {
    final now = DateTime.now();
    final docId = 'GEST-$localId-${now.millisecondsSinceEpoch}';

    await _ref.doc(docId).set({
      'timestamp': Timestamp.fromDate(now),
      'localId': localId,
      'cobradorId': cobradorId,
      'tipoIncidencia': tipoIncidencia,
      'comentario': comentario ?? '',
      'latitud': latitud,
      'longitud': longitud,
      'municipalidadId': municipalidadId,
      'mercadoId': mercadoId,
    });
  }

  /// Lista de gestiones de un día específico (consulta puntual para cortes).
  Future<List<Gestion>> listarGestionesDia({
    required DateTime fecha,
    String? cobradorId,
    String? mercadoId,
  }) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));

    final snap = await _ref
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((doc) {
          final d = doc.data();
          return Gestion(
            id: doc.id,
            timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
            localId: d['localId'] as String?,
            cobradorId: d['cobradorId'] as String?,
            tipoIncidencia: d['tipoIncidencia'] as String?,
            comentario: d['comentario'] as String?,
            latitud: (d['latitud'] as num?)?.toDouble(),
            longitud: (d['longitud'] as num?)?.toDouble(),
            municipalidadId: d['municipalidadId'] as String?,
            mercadoId: d['mercadoId'] as String?,
          );
        })
        .where((g) {
          if (cobradorId != null && g.cobradorId != cobradorId) return false;
          if (mercadoId != null && g.mercadoId != mercadoId) return false;
          return true;
        })
        .toList();
  }

  /// Obtiene todas las gestiones de una municipalidad (para vista administrativa).
  Future<List<Gestion>> listarTodas(String municipalidadId) async {
    final snap = await _ref
        .where('municipalidadId', isEqualTo: municipalidadId)
        .orderBy('timestamp', descending: true)
        .get();

    return snap.docs
        .map((doc) {
          final d = doc.data();
          return Gestion(
            id: doc.id,
            timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
            localId: d['localId'] as String?,
            cobradorId: d['cobradorId'] as String?,
            tipoIncidencia: d['tipoIncidencia'] as String?,
            comentario: d['comentario'] as String?,
            latitud: (d['latitud'] as num?)?.toDouble(),
            longitud: (d['longitud'] as num?)?.toDouble(),
            municipalidadId: d['municipalidadId'] as String?,
            mercadoId: d['mercadoId'] as String?,
          );
        })
        .toList();
  }

  /// Stream de gestiones del día actual, filtrado por cobrador.
  Stream<List<Gestion>> streamGestionesHoy({
    required DateTime fecha,
    String? cobradorId,
    String? mercadoId,
  }) {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));

    Query<Map<String, dynamic>> query = _ref
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fin));

    // Firestore solo permite un campo de desigualdad por query.
    // Filtrar cobradorId y mercadoId en memoria si es necesario.
    return query.snapshots().map((snap) {
      return snap.docs
          .map((doc) {
            final d = doc.data();
            return Gestion(
              id: doc.id,
              timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
              localId: d['localId'] as String?,
              cobradorId: d['cobradorId'] as String?,
              tipoIncidencia: d['tipoIncidencia'] as String?,
              comentario: d['comentario'] as String?,
              latitud: (d['latitud'] as num?)?.toDouble(),
              longitud: (d['longitud'] as num?)?.toDouble(),
              municipalidadId: d['municipalidadId'] as String?,
              mercadoId: d['mercadoId'] as String?,
            );
          })
          .where((g) {
            if (cobradorId != null && g.cobradorId != cobradorId) return false;
            if (mercadoId != null && g.mercadoId != mercadoId) return false;
            return true;
          })
          .toList();
    });
  }

  /// Actualiza una gestión/incidencia existente.
  Future<void> actualizarGestion({
    required String id,
    required String localId,
    required String cobradorId,
    required String tipoIncidencia,
    String? comentario,
    String? municipalidadId,
    String? mercadoId,
  }) async {
    await _ref.doc(id).update({
      'localId': localId,
      'cobradorId': cobradorId,
      'tipoIncidencia': tipoIncidencia,
      'comentario': comentario ?? '',
      'municipalidadId': municipalidadId,
      'mercadoId': mercadoId,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una gestión/incidencia por id.
  Future<void> eliminarGestion(String id) async {
    await _ref.doc(id).delete();
  }
}
