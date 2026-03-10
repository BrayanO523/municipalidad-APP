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
    super.latitud,
    super.longitud,
    super.perimetro,
    super.codigo,
  });

  factory MercadoJson.fromJson(Map<String, dynamic> jsonRaw, {String? docId}) {
    final json = Map<String, dynamic>.from(jsonRaw);

    final geo = json['ubicacion_geo'] as GeoPoint?;
    final perimRaw = json['perimetro'] as List<dynamic>?;

    List<Map<String, double>>? perimetro;
    if (perimRaw != null) {
      perimetro = perimRaw.map((p) {
        final gp = p as GeoPoint;
        return {'lat': gp.latitude, 'lng': gp.longitude};
      }).toList();
    }

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
      latitud: geo?.latitude ?? json['latitud'],
      longitud: geo?.longitude ?? json['longitud'],
      perimetro: perimetro,
      codigo: json['codigo'],
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
      latitud: entity.latitud,
      longitud: entity.longitud,
      perimetro: entity.perimetro,
      codigo: entity.codigo,
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
      'ubicacion_geo': (latitud != null && longitud != null)
          ? GeoPoint(latitud!, longitud!)
          : null,
      'perimetro': perimetro
          ?.map((p) => GeoPoint(p['lat']!, p['lng']!))
          .toList(),
      'codigo': codigo,
    };
  }
}
