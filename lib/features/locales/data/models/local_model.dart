import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/local.dart';

class LocalJson extends Local {
  const LocalJson({
    super.activo,
    super.actualizadoEn,
    super.actualizadoPor,
    super.creadoEn,
    super.creadoPor,
    super.cuotaDiaria,
    super.espacioM2,
    super.id,
    super.mercadoId,
    super.municipalidadId,
    super.nombreSocial,
    super.qrData,
    super.representante,
    super.telefonoRepresentante,
    super.tipoNegocioId,
    super.latitud,
    super.longitud,
    super.perimetro,
    super.saldoAFavor,
    super.deudaAcumulada,
  });

  factory LocalJson.fromJson(Map<String, dynamic> jsonRaw, {String? docId}) {
    final json = Map<String, dynamic>.from(jsonRaw);
    final perimRaw = json['perimetro'] as List<dynamic>?;
    List<Map<String, double>>? perimetro;
    if (perimRaw != null) {
      perimetro = perimRaw.map((p) {
        final gp = p as GeoPoint;
        return {'lat': gp.latitude, 'lng': gp.longitude};
      }).toList();
    }

    return LocalJson(
      activo: json['activo'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      cuotaDiaria: json['cuotaDiaria'],
      espacioM2: json['espacioM2'],
      id: docId ?? json['id'],
      mercadoId: json['mercadoId'],
      municipalidadId: json['municipalidadId'],
      nombreSocial: json['nombreSocial'],
      qrData: json['qrData'],
      representante: json['representante'],
      telefonoRepresentante: json['telefonoRepresentante'],
      tipoNegocioId: json['tipoNegocioId'],
      latitud: (json['ubicacion'] as GeoPoint?)?.latitude,
      longitud: (json['ubicacion'] as GeoPoint?)?.longitude,
      perimetro: perimetro,
      saldoAFavor: json['saldoAFavor'],
      deudaAcumulada: json['deudaAcumulada'],
    );
  }

  factory LocalJson.fromEntity(Local entity) {
    return LocalJson(
      activo: entity.activo,
      actualizadoEn: entity.actualizadoEn,
      actualizadoPor: entity.actualizadoPor,
      creadoEn: entity.creadoEn,
      creadoPor: entity.creadoPor,
      cuotaDiaria: entity.cuotaDiaria,
      espacioM2: entity.espacioM2,
      id: entity.id,
      mercadoId: entity.mercadoId,
      municipalidadId: entity.municipalidadId,
      nombreSocial: entity.nombreSocial,
      qrData: entity.qrData,
      representante: entity.representante,
      telefonoRepresentante: entity.telefonoRepresentante,
      tipoNegocioId: entity.tipoNegocioId,
      latitud: entity.latitud,
      longitud: entity.longitud,
      perimetro: entity.perimetro,
      saldoAFavor: entity.saldoAFavor,
      deudaAcumulada: entity.deudaAcumulada,
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
      'cuotaDiaria': cuotaDiaria,
      'espacioM2': espacioM2,
      'mercadoId': mercadoId,
      'municipalidadId': municipalidadId,
      'nombreSocial': nombreSocial,
      'qrData': qrData,
      'representante': representante,
      'telefonoRepresentante': telefonoRepresentante,
      'tipoNegocioId': tipoNegocioId,
      if (latitud != null && longitud != null)
        'ubicacion': GeoPoint(latitud!, longitud!),
      'perimetro': perimetro
          ?.map((p) => GeoPoint(p['lat']!, p['lng']!))
          .toList(),
      if (saldoAFavor != null) 'saldoAFavor': saldoAFavor,
      if (deudaAcumulada != null) 'deudaAcumulada': deudaAcumulada,
    };
  }
}
