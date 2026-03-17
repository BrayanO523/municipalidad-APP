import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/municipalidad.dart';

class MunicipalidadJson extends Municipalidad {
  const MunicipalidadJson({
    super.activa,
    super.actualizadoEn,
    super.actualizadoPor,
    super.creadoEn,
    super.creadoPor,
    super.departamento,
    super.id,
    super.logo,
    super.municipio,
    super.nombre,
    super.porcentaje,
    super.slogan,
    super.fechaReferenciaMora,
  });

  factory MunicipalidadJson.fromJson(
    Map<String, dynamic> json, {
    String? docId,
  }) {
    // Manejo robusto para campos numéricos que podrían venir como String
    num? parseNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      if (value is String) return num.tryParse(value);
      return null;
    }

    return MunicipalidadJson(
      activa: json['activa'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      departamento: json['departamento'],
      id: docId ?? json['id'],
      logo: json['logo'],
      municipio: json['municipio'],
      nombre: json['nombre'],
      porcentaje: parseNum(json['porcentaje']),
      slogan: json['slogan'],
      fechaReferenciaMora: (json['fechaReferenciaMora'] as Timestamp?)?.toDate(),
    );
  }

  factory MunicipalidadJson.fromEntity(Municipalidad entity) {
    return MunicipalidadJson(
      activa: entity.activa,
      actualizadoEn: entity.actualizadoEn,
      actualizadoPor: entity.actualizadoPor,
      creadoEn: entity.creadoEn,
      creadoPor: entity.creadoPor,
      departamento: entity.departamento,
      id: entity.id,
      logo: entity.logo,
      municipio: entity.municipio,
      nombre: entity.nombre,
      porcentaje: entity.porcentaje,
      slogan: entity.slogan,
      fechaReferenciaMora: entity.fechaReferenciaMora,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activa': activa,
      'actualizadoEn': actualizadoEn != null
          ? Timestamp.fromDate(actualizadoEn!)
          : null,
      'actualizadoPor': actualizadoPor,
      'creadoEn': creadoEn != null ? Timestamp.fromDate(creadoEn!) : null,
      'creadoPor': creadoPor,
      'departamento': departamento,
      'logo': logo,
      'municipio': municipio,
      'nombre': nombre,
      'porcentaje': porcentaje,
      'slogan': slogan,
      if (fechaReferenciaMora != null)
        'fechaReferenciaMora': Timestamp.fromDate(fechaReferenciaMora!),
    };
  }
}
