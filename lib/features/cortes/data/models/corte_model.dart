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
    super.cantidadCobrados,
    super.cantidadPendientes,
    super.pendientesInfo,
    super.gestionesInfo,
    super.primerBoleta,
    super.ultimaBoleta,
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
      cantidadCobrados: map['cantidadCobrados'] as int?,
      cantidadPendientes: map['cantidadPendientes'] as int?,
      pendientesInfo: map['pendientesInfo'] != null
          ? List<Map<String, dynamic>>.from(
              (map['pendientesInfo'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : null,
      gestionesInfo: map['gestionesInfo'] != null
          ? List<Map<String, dynamic>>.from(
              (map['gestionesInfo'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : null,
      primerBoleta: map['primerBoleta'] as String?,
      ultimaBoleta: map['ultimaBoleta'] as String?,
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
      if (cantidadCobrados != null) 'cantidadCobrados': cantidadCobrados,
      if (cantidadPendientes != null) 'cantidadPendientes': cantidadPendientes,
      if (pendientesInfo != null) 'pendientesInfo': pendientesInfo,
      if (gestionesInfo != null) 'gestionesInfo': gestionesInfo,
      if (primerBoleta != null) 'primerBoleta': primerBoleta,
      if (ultimaBoleta != null) 'ultimaBoleta': ultimaBoleta,
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
      cantidadCobrados: corte.cantidadCobrados,
      cantidadPendientes: corte.cantidadPendientes,
      pendientesInfo: corte.pendientesInfo,
      gestionesInfo: corte.gestionesInfo,
      primerBoleta: corte.primerBoleta,
      ultimaBoleta: corte.ultimaBoleta,
    );
  }
}
