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
    super.telefonoRepresentante,
    super.correlativo,
    super.anioCorrelativo,
    super.numeroBoleta,
    super.deudaAnterior,
    super.montoAbonadoDeuda,
    super.nuevoSaldoFavor,
    super.pagoACuota,
    super.idsDeudasSaldadas,
    super.fechasDeudasSaldadas,
  });

  factory CobroJson.fromJson(Map<String, dynamic> json, {String? docId}) {
    return CobroJson(
      cobradorId: json['cobradorId'],
      actualizadoEn: (json['actualizadoEn'] as Timestamp?)?.toDate(),
      actualizadoPor: json['actualizadoPor'],
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
      creadoPor: json['creadoPor'],
      cuotaDiaria: (json['cuotaDiaria'] as num?)?.toDouble(),
      estado: json['estado'],
      fecha: (json['fecha'] as Timestamp?)?.toDate(),
      id: docId ?? json['id'],
      localId: json['localId'],
      mercadoId: json['mercadoId'],
      monto: (json['monto'] as num?)?.toDouble(),
      municipalidadId: json['municipalidadId'],
      observaciones: json['observaciones'],
      saldoPendiente: (json['saldoPendiente'] as num?)?.toDouble(),
      telefonoRepresentante: json['telefonoRepresentante'],
      correlativo: (json['correlativo'] as num?)?.toInt(),
      anioCorrelativo: (json['anioCorrelativo'] as num?)?.toInt(),
      numeroBoleta: json['numeroBoleta'],
      deudaAnterior: (json['deudaAnterior'] as num?)?.toDouble(),
      montoAbonadoDeuda: (json['montoAbonadoDeuda'] as num?)?.toDouble(),
      nuevoSaldoFavor: (json['nuevoSaldoFavor'] as num?)?.toDouble(),
      pagoACuota: (json['pagoACuota'] as num?)?.toDouble(),
      idsDeudasSaldadas: (json['idsDeudasSaldadas'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      fechasDeudasSaldadas: (json['fechasDeudasSaldadas'] as List<dynamic>?)
          ?.map((e) => (e as Timestamp).toDate())
          .toList(),
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
      telefonoRepresentante: entity.telefonoRepresentante,
      correlativo: entity.correlativo,
      anioCorrelativo: entity.anioCorrelativo,
      numeroBoleta: entity.numeroBoleta,
      deudaAnterior: entity.deudaAnterior,
      montoAbonadoDeuda: entity.montoAbonadoDeuda,
      nuevoSaldoFavor: entity.nuevoSaldoFavor,
      pagoACuota: entity.pagoACuota,
      idsDeudasSaldadas: entity.idsDeudasSaldadas,
      fechasDeudasSaldadas: entity.fechasDeudasSaldadas,
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
      'telefonoRepresentante': telefonoRepresentante,
      'correlativo': correlativo,
      'anioCorrelativo': anioCorrelativo,
      'deudaAnterior': deudaAnterior,
      'montoAbonadoDeuda': montoAbonadoDeuda,
      'nuevoSaldoFavor': nuevoSaldoFavor,
      'pagoACuota': pagoACuota,
      if (idsDeudasSaldadas != null && idsDeudasSaldadas!.isNotEmpty)
        'idsDeudasSaldadas': idsDeudasSaldadas,
      if (fechasDeudasSaldadas != null && fechasDeudasSaldadas!.isNotEmpty)
        'fechasDeudasSaldadas': fechasDeudasSaldadas!.map((d) => Timestamp.fromDate(d)).toList(),
    };
  }
}
