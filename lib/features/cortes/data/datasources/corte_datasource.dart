import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/corte_model.dart';
import '../../../../core/errors/failures.dart';

class CorteDatasource {
  final FirebaseFirestore _firestore;

  CorteDatasource(this._firestore);

  Stream<List<CorteModel>> streamPorMunicipalidad(String municipalidadId) {
    return _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .orderBy('fechaCorte', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CorteModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<CorteModel>> streamPorCobrador(String cobradorId) {
    return _firestore
        .collection('cortes')
        .where('cobradorId', isEqualTo: cobradorId)
        .orderBy('fechaCorte', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CorteModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> crearCorte(CorteModel corte) async {
    try {
      final docRef = _firestore.collection('cortes').doc(); // Auto-ID
      final json = corte.toMap();
      await docRef.set(json);
    } catch (e) {
      throw ServerFailure('Error al crear corte: $e');
    }
  }

  /// Lista una página de cortes para una municipalidad (Admin).
  Future<QuerySnapshot<Map<String, dynamic>>> listarPaginaPorMunicipalidad({
    required String municipalidadId,
    int limite = 20,
    DocumentSnapshot? startAfter,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) {
    var query = _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId);

    if (fechaInicio != null) {
      query = query.where('fechaCorte', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio));
    }
    if (fechaFin != null) {
      query = query.where('fechaCorte', isLessThanOrEqualTo: Timestamp.fromDate(fechaFin));
    }

    query = query.orderBy('fechaCorte', descending: true).limit(limite);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Lista una página de cortes para un cobrador específico.
  Future<QuerySnapshot<Map<String, dynamic>>> listarPaginaPorCobrador({
    required String cobradorId,
    int limite = 20,
    DocumentSnapshot? startAfter,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) {
    var query = _firestore
        .collection('cortes')
        .where('cobradorId', isEqualTo: cobradorId);

    if (fechaInicio != null) {
      query = query.where('fechaCorte', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio));
    }
    if (fechaFin != null) {
      query = query.where('fechaCorte', isLessThanOrEqualTo: Timestamp.fromDate(fechaFin));
    }

    query = query.orderBy('fechaCorte', descending: true).limit(limite);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  // ─────────────────────────────────────────────
  // Métodos para el Corte de Mercado (Admin)
  // ─────────────────────────────────────────────

  /// Obtiene los cortes de cobradores del día para un mercado específico.
  /// Retorna solo cortes tipo 'cobrador' (o sin tipo, retrocompatibles).
  Future<List<CorteModel>> listarCortesDiaPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  }) async {
    final inicioDelDia = DateTime(fecha.year, fecha.month, fecha.day);
    final finDelDia = inicioDelDia
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final snapshot = await _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('mercadoId', isEqualTo: mercadoId)
        .where('fechaCorte', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDelDia))
        .where('fechaCorte', isLessThanOrEqualTo: Timestamp.fromDate(finDelDia))
        .get();

    return snapshot.docs
        .map((doc) => CorteModel.fromMap(doc.data(), doc.id))
        // Solo cortes de cobradores, no otros cortes de mercado
        .where((c) => c.tipo != 'mercado')
        .toList();
  }

  /// Stream en tiempo real de cortes de cobradores del día para un mercado.
  Stream<List<CorteModel>> streamCortesDiaPorMercado({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  }) {
    final inicioDelDia = DateTime(fecha.year, fecha.month, fecha.day);
    final finDelDia = inicioDelDia
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    return _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('mercadoId', isEqualTo: mercadoId)
        .where('fechaCorte', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDelDia))
        .where('fechaCorte', isLessThanOrEqualTo: Timestamp.fromDate(finDelDia))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CorteModel.fromMap(doc.data(), doc.id))
            .where((c) => c.tipo != 'mercado')
            .toList());
  }

  /// Stream en tiempo real de cortes del día de un cobrador específico.
  Stream<List<CorteModel>> streamCortesDiaPorCobrador({
    required String cobradorId,
    required DateTime fecha,
  }) {
    final inicioDelDia = DateTime(fecha.year, fecha.month, fecha.day);
    final finDelDia = inicioDelDia
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    return _firestore
        .collection('cortes')
        .where('cobradorId', isEqualTo: cobradorId)
        .where('fechaCorte', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDelDia))
        .where('fechaCorte', isLessThanOrEqualTo: Timestamp.fromDate(finDelDia))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CorteModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Verifica si ya existe un corte de mercado para un mercado en la fecha dada.
  Future<bool> existeCorteMercadoHoy({
    required String mercadoId,
    required String municipalidadId,
    required DateTime fecha,
  }) async {
    final inicioDelDia = DateTime(fecha.year, fecha.month, fecha.day);
    final finDelDia = inicioDelDia
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final snapshot = await _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('mercadoId', isEqualTo: mercadoId)
        .where('tipo', isEqualTo: 'mercado')
        .where('fechaCorte', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDelDia))
        .where('fechaCorte', isLessThanOrEqualTo: Timestamp.fromDate(finDelDia))
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Lista cortes de mercado paginados (solo tipo == 'mercado').
  Future<QuerySnapshot<Map<String, dynamic>>> listarCortesMarketPaginados({
    required String municipalidadId,
    String? mercadoId,
    int limite = 20,
    DocumentSnapshot? startAfter,
  }) {
    var query = _firestore
        .collection('cortes')
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('tipo', isEqualTo: 'mercado')
        .orderBy('fechaCorte', descending: true)
        .limit(limite);

    if (mercadoId != null) {
      query = _firestore
          .collection('cortes')
          .where('municipalidadId', isEqualTo: municipalidadId)
          .where('tipo', isEqualTo: 'mercado')
          .where('mercadoId', isEqualTo: mercadoId)
          .orderBy('fechaCorte', descending: true)
          .limit(limite);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }
}
