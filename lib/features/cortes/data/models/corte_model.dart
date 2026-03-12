import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/corte.dart';

class CorteModel extends Corte {
  const CorteModel({
    required super.id,
    required super.cobradorId,
    required super.cobradorNombre,
    required super.municipalidadId,
    required super.fechaCorte,
    required super.totalCobrado,
    required super.cantidadRegistros,
    required super.cobrosIds,
    required super.fechaInicioRango,
    required super.fechaFinRango,
    super.liquidado,
    super.tipo,
    super.mercadoId,
    super.mercadoNombre,
    super.cortesCobradorIds,
  });

  factory CorteModel.fromMap(Map<String, dynamic> map, String id) {
    return CorteModel(
      id: id,
      cobradorId: map['cobradorId'] ?? '',
      cobradorNombre: map['cobradorNombre'] ?? 'Desconocido',
      municipalidadId: map['municipalidadId'] ?? '',
      fechaCorte: (map['fechaCorte'] as Timestamp).toDate(),
      totalCobrado: (map['totalCobrado'] ?? 0).toDouble(),
      cantidadRegistros: map['cantidadRegistros'] ?? 0,
      cobrosIds: List<String>.from(map['cobrosIds'] ?? []),
      fechaInicioRango: (map['fechaInicioRango'] as Timestamp).toDate(),
      fechaFinRango: (map['fechaFinRango'] as Timestamp).toDate(),
      liquidado: map['liquidado'] ?? false,
      // Nuevos campos — con fallback null para retrocompatibilidad
      tipo: map['tipo'] as String?,
      mercadoId: map['mercadoId'] as String?,
      mercadoNombre: map['mercadoNombre'] as String?,
      cortesCobradorIds: map['cortesCobradorIds'] != null
          ? List<String>.from(map['cortesCobradorIds'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cobradorId': cobradorId,
      'cobradorNombre': cobradorNombre,
      'municipalidadId': municipalidadId,
      'fechaCorte': Timestamp.fromDate(fechaCorte),
      'totalCobrado': totalCobrado,
      'cantidadRegistros': cantidadRegistros,
      'cobrosIds': cobrosIds,
      'fechaInicioRango': Timestamp.fromDate(fechaInicioRango),
      'fechaFinRango': Timestamp.fromDate(fechaFinRango),
      'liquidado': liquidado,
      if (tipo != null) 'tipo': tipo,
      if (mercadoId != null) 'mercadoId': mercadoId,
      if (mercadoNombre != null) 'mercadoNombre': mercadoNombre,
      if (cortesCobradorIds != null) 'cortesCobradorIds': cortesCobradorIds,
    };
  }

  factory CorteModel.fromEntity(Corte corte) {
    return CorteModel(
      id: corte.id,
      cobradorId: corte.cobradorId,
      cobradorNombre: corte.cobradorNombre,
      municipalidadId: corte.municipalidadId,
      fechaCorte: corte.fechaCorte,
      totalCobrado: corte.totalCobrado,
      cantidadRegistros: corte.cantidadRegistros,
      cobrosIds: corte.cobrosIds,
      fechaInicioRango: corte.fechaInicioRango,
      fechaFinRango: corte.fechaFinRango,
      liquidado: corte.liquidado,
      tipo: corte.tipo,
      mercadoId: corte.mercadoId,
      mercadoNombre: corte.mercadoNombre,
      cortesCobradorIds: corte.cortesCobradorIds,
    );
  }
}
