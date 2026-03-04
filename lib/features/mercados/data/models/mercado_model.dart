import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/mercado.dart';

class MercadoJson extends Mercado {
  const MercadoJson({
    super.activo,
    super.actualizadoEn,
    super.actualizadoPor,
    super.creadoEn,
    super.creadoPor,
    super.id,
    super.municipalidadId,
    super.nombre,
    super.ubicacion,
  });

  factory MercadoJson.fromJson(Map<String, dynamic> json, {String? docId}) {
    return MercadoJson(
      activo: json['activo'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      id: docId ?? json['id'],
      municipalidadId: json['municipalidadId'],
      nombre: json['nombre'],
      ubicacion: json['ubicacion'],
    );
  }

  factory MercadoJson.fromEntity(Mercado entity) {
    return MercadoJson(
      activo: entity.activo,
      actualizadoEn: entity.actualizadoEn,
      actualizadoPor: entity.actualizadoPor,
      creadoEn: entity.creadoEn,
      creadoPor: entity.creadoPor,
      id: entity.id,
      municipalidadId: entity.municipalidadId,
      nombre: entity.nombre,
      ubicacion: entity.ubicacion,
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
      'municipalidadId': municipalidadId,
      'nombre': nombre,
      'ubicacion': ubicacion,
    };
  }
}
