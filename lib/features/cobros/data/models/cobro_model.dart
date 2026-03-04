import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cobro.dart';

class CobroJson extends Cobro {
  const CobroJson({
    super.cobradorId,
    super.actualizadoEn,
    super.actualizadoPor,
    super.creadoEn,
    super.creadoPor,
    super.cuotaDiaria,
    super.estado,
    super.fecha,
    super.id,
    super.localId,
    super.mercadoId,
    super.monto,
    super.municipalidadId,
    super.observaciones,
    super.saldoPendiente,
  });

  factory CobroJson.fromJson(Map<String, dynamic> json, {String? docId}) {
    return CobroJson(
      cobradorId: json['cobradorId'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      cuotaDiaria: json['cuotaDiaria'],
      estado: json['estado'],
      fecha: (json['fecha'] as Timestamp?)?.toDate(),
      id: docId ?? json['id'],
      localId: json['localId'],
      mercadoId: json['mercadoId'],
      monto: json['monto'],
      municipalidadId: json['municipalidadId'],
      observaciones: json['observaciones'],
      saldoPendiente: json['saldoPendiente'],
    );
  }

  factory CobroJson.fromEntity(Cobro entity) {
    return CobroJson(
      cobradorId: entity.cobradorId,
      actualizadoEn: entity.actualizadoEn,
      actualizadoPor: entity.actualizadoPor,
      creadoEn: entity.creadoEn,
      creadoPor: entity.creadoPor,
      cuotaDiaria: entity.cuotaDiaria,
      estado: entity.estado,
      fecha: entity.fecha,
      id: entity.id,
      localId: entity.localId,
      mercadoId: entity.mercadoId,
      monto: entity.monto,
      municipalidadId: entity.municipalidadId,
      observaciones: entity.observaciones,
      saldoPendiente: entity.saldoPendiente,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cobradorId': cobradorId,
      'actualizadoEn': actualizadoEn != null
          ? Timestamp.fromDate(actualizadoEn!)
          : null,
      'actualizadoPor': actualizadoPor,
      'creadoEn': creadoEn != null ? Timestamp.fromDate(creadoEn!) : null,
      'creadoPor': creadoPor,
      'cuotaDiaria': cuotaDiaria,
      'estado': estado,
      'fecha': fecha != null ? Timestamp.fromDate(fecha!) : null,
      'localId': localId,
      'mercadoId': mercadoId,
      'monto': monto,
      'municipalidadId': municipalidadId,
      'observaciones': observaciones,
      'saldoPendiente': saldoPendiente,
    };
  }
}
