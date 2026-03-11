import 'dart:convert';
import 'package:hive/hive.dart';
import '../../../domain/entities/local.dart';

part 'local_hive.g.dart';

@HiveType(typeId: 1)
class LocalHive extends HiveObject {
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
  double? cuotaDiaria;

  @HiveField(8)
  double? espacioM2;

  @HiveField(9)
  String? mercadoId;

  @HiveField(10)
  String? municipalidadId;

  @HiveField(11)
  String? nombreSocial;

  @HiveField(12)
  String? qrData;

  @HiveField(13)
  String? representante;

  @HiveField(14)
  String? telefonoRepresentante;

  @HiveField(15)
  String? tipoNegocioId;

  @HiveField(16)
  double? latitud;

  @HiveField(17)
  double? longitud;

  @HiveField(18)
  double? saldoAFavor;

  @HiveField(19)
  double? deudaAcumulada;

  @HiveField(20)
  String? perimetroJson;

  @HiveField(21)
  String? clave;

  @HiveField(22)
  String? codigoCatastral;

  @HiveField(23)
  String? codigoCatastralLower;

  @HiveField(24)
  String? frecuenciaCobro;

  LocalHive({
    this.id,
    this.syncStatus = 1,
    this.activo,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.cuotaDiaria,
    this.espacioM2,
    this.mercadoId,
    this.municipalidadId,
    this.nombreSocial,
    this.qrData,
    this.representante,
    this.telefonoRepresentante,
    this.tipoNegocioId,
    this.latitud,
    this.longitud,
    this.saldoAFavor,
    this.deudaAcumulada,
    this.frecuenciaCobro,
    this.perimetroJson,
    this.clave,
    this.codigoCatastral,
    this.codigoCatastralLower,
  });

  Local toDomain() {
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

    return Local(
      id: id,
      activo: activo,
      actualizadoEn: actualizadoEn,
      actualizadoPor: actualizadoPor,
      creadoEn: creadoEn,
      creadoPor: creadoPor,
      cuotaDiaria: cuotaDiaria,
      espacioM2: espacioM2,
      mercadoId: mercadoId,
      municipalidadId: municipalidadId,
      nombreSocial: nombreSocial,
      qrData: qrData,
      representante: representante,
      telefonoRepresentante: telefonoRepresentante,
      tipoNegocioId: tipoNegocioId,
      latitud: latitud,
      longitud: longitud,
      saldoAFavor: saldoAFavor,
      deudaAcumulada: deudaAcumulada,
      frecuenciaCobro: frecuenciaCobro,
      perimetro: perimetroDecoded,
      clave: clave,
      codigoCatastral: codigoCatastral,
      codigoCatastralLower: codigoCatastralLower,
    );
  }

  static LocalHive fromDomain(Local local, {int syncStatus = 1}) {
    String? perimetroEncoded;
    if (local.perimetro != null) {
      perimetroEncoded = jsonEncode(local.perimetro);
    }

    return LocalHive(
      id: local.id,
      syncStatus: syncStatus,
      activo: local.activo,
      actualizadoEn: local.actualizadoEn,
      actualizadoPor: local.actualizadoPor,
      creadoEn: local.creadoEn,
      creadoPor: local.creadoPor,
      cuotaDiaria: local.cuotaDiaria?.toDouble(),
      espacioM2: local.espacioM2?.toDouble(),
      mercadoId: local.mercadoId,
      municipalidadId: local.municipalidadId,
      nombreSocial: local.nombreSocial,
      qrData: local.qrData,
      representante: local.representante,
      telefonoRepresentante: local.telefonoRepresentante,
      tipoNegocioId: local.tipoNegocioId,
      latitud: local.latitud,
      longitud: local.longitud,
      saldoAFavor: local.saldoAFavor?.toDouble(),
      deudaAcumulada: local.deudaAcumulada?.toDouble(),
      frecuenciaCobro: local.frecuenciaCobro,
      perimetroJson: perimetroEncoded,
      clave: local.clave,
      codigoCatastral: local.codigoCatastral,
      codigoCatastralLower: local.codigoCatastralLower,
    );
  }
}
