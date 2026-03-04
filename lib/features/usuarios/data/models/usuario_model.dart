import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/usuario.dart';

class UsuarioJson extends Usuario {
  const UsuarioJson({
    super.activo,
    super.actualizadoEn,
    super.actualizadoPor,
    super.creadoEn,
    super.creadoPor,
    super.email,
    super.id,
    super.municipalidadId,
    super.nombre,
    super.rol,
  });

  factory UsuarioJson.fromJson(Map<String, dynamic> json, {String? docId}) {
    return UsuarioJson(
      activo: json['activo'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      email: json['email'],
      id: docId ?? json['id'],
      municipalidadId: json['municipalidadId'],
      nombre: json['nombre'],
      rol: json['rol'],
    );
  }

  factory UsuarioJson.fromEntity(Usuario entity) {
    return UsuarioJson(
      activo: entity.activo,
      actualizadoEn: entity.actualizadoEn,
      actualizadoPor: entity.actualizadoPor,
      creadoEn: entity.creadoEn,
      creadoPor: entity.creadoPor,
      email: entity.email,
      id: entity.id,
      municipalidadId: entity.municipalidadId,
      nombre: entity.nombre,
      rol: entity.rol,
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
      'email': email,
      'municipalidadId': municipalidadId,
      'nombre': nombre,
      'rol': rol,
    };
  }
}
