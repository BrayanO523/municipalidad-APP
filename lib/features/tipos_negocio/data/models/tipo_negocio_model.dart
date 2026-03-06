import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tipo_negocio.dart';

class TipoNegocioJson extends TipoNegocio {
  const TipoNegocioJson({
    super.activo,
    super.actualizadoEn,
    super.actualizadoPor,
    super.creadoEn,
    super.creadoPor,
    super.descripcion,
    super.id,
    super.nombre,
    super.municipalidadId,
  });

  factory TipoNegocioJson.fromJson(Map<String, dynamic> json, {String? docId}) {
    return TipoNegocioJson(
      activo: json['activo'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      descripcion: json['descripcion'],
      id: docId ?? json['id'],
      nombre: json['nombre'],
      municipalidadId: json['municipalidadId'],
    );
  }

  factory TipoNegocioJson.fromEntity(TipoNegocio entity) {
    return TipoNegocioJson(
      activo: entity.activo,
      actualizadoEn: entity.actualizadoEn,
      actualizadoPor: entity.actualizadoPor,
      creadoEn: entity.creadoEn,
      creadoPor: entity.creadoPor,
      descripcion: entity.descripcion,
      id: entity.id,
      nombre: entity.nombre,
      municipalidadId: entity.municipalidadId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activo': activo,
      'actualizadoEn': actualizadoEn != null
          ? Timestamp.fromDate(actualizadoEn!)
          : null,
      'actualizadoPor': actualizadoPor,
      'creadoEn': creadoEn != null ? Timestamp.fromDate(creadoEn!) : null,
      'creadoPor': creadoPor,
      'descripcion': descripcion,
      'nombre': nombre,
      'municipalidadId': municipalidadId,
    };
  }
}
