import 'dart:convert';
import 'package:hive/hive.dart';
import '../../../domain/entities/mercado.dart';

part 'mercado_hive.g.dart';

@HiveType(typeId: 2)
class MercadoHive extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  int syncStatus; // 0 = pendiente, 1 = sincronizado

  @HiveField(2)
  bool? activo;

  @HiveField(3)
  DateTime? actualizadoEn;

  @HiveField(4)
  String? actualizadoPor;

  @HiveField(5)
  DateTime? creadoEn;

  @HiveField(6)
  String? creadoPor;

  @HiveField(7)
  String? municipalidadId;

  @HiveField(8)
  String? nombre;

  @HiveField(9)
  String? ubicacion;

  @HiveField(12)
  double? latitud;

  @HiveField(13)
  double? longitud;

  @HiveField(14)
  String? perimetroJson;

  @HiveField(15)
  String? codigo;

  MercadoHive({
    this.id,
    this.syncStatus = 1,
    this.activo,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.municipalidadId,
    this.nombre,
    this.ubicacion,
    this.latitud,
    this.longitud,
    this.perimetroJson,
    this.codigo,
  });

  Mercado toDomain() {
    List<Map<String, double>>? perimetroDecoded;
    if (perimetroJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(perimetroJson!);
        perimetroDecoded = jsonList.map((e) {
          final map = e as Map<String, dynamic>;
          return map.map(
            (key, value) => MapEntry(
              key,
              value is double ? value : (value as num).toDouble(),
            ),
          );
        }).toList();
      } catch (e) {
        perimetroDecoded = null;
      }
    }

    return Mercado(
      id: id,
      activo: activo,
      actualizadoEn: actualizadoEn,
      actualizadoPor: actualizadoPor,
      creadoEn: creadoEn,
      creadoPor: creadoPor,
      municipalidadId: municipalidadId,
      nombre: nombre,
      ubicacion: ubicacion,
      latitud: latitud,
      longitud: longitud,
      perimetro: perimetroDecoded,
      codigo: codigo,
    );
  }

  static MercadoHive fromDomain(Mercado mercado, {int syncStatus = 1}) {
    String? perimetroEncoded;
    if (mercado.perimetro != null) {
      perimetroEncoded = jsonEncode(mercado.perimetro);
    }

    return MercadoHive(
      id: mercado.id,
      syncStatus: syncStatus,
      activo: mercado.activo,
      actualizadoEn: mercado.actualizadoEn,
      actualizadoPor: mercado.actualizadoPor,
      creadoEn: mercado.creadoEn,
      creadoPor: mercado.creadoPor,
      municipalidadId: mercado.municipalidadId,
      nombre: mercado.nombre,
      ubicacion: mercado.ubicacion,
      latitud: mercado.latitud,
      longitud: mercado.longitud,
      perimetroJson: perimetroEncoded,
      codigo: mercado.codigo,
    );
  }
}
