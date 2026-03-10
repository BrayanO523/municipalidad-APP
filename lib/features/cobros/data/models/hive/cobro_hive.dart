import 'package:hive/hive.dart';
import '../../../domain/entities/cobro.dart';

part 'cobro_hive.g.dart';

@HiveType(typeId: 0)
class CobroHive extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  int syncStatus; // 0 = pendiente_envio, 1 = sincronizado, 2 = conflicto

  @HiveField(2)
  String? cobradorId;

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
  String? estado;

  @HiveField(9)
  DateTime? fecha;

  @HiveField(10)
  String? localId;

  @HiveField(11)
  String? mercadoId;

  @HiveField(12)
  double? monto;

  @HiveField(13)
  String? municipalidadId;

  @HiveField(14)
  String? observaciones;

  @HiveField(15)
  double? saldoPendiente;

  @HiveField(16)
  String? telefonoRepresentante;

  @HiveField(17)
  int? correlativo;

  @HiveField(18)
  int? anioCorrelativo;

  @HiveField(19)
  double? deudaAnterior;

  @HiveField(20)
  double? montoAbonadoDeuda;

  @HiveField(21)
  double? nuevoSaldoFavor;

  @HiveField(22)
  double? pagoACuota;

  @HiveField(23)
  String? numeroBoleta;

  @HiveField(24)
  List<String>? idsDeudasSaldadas;

  CobroHive({
    this.id,
    this.syncStatus = 1,
    this.cobradorId,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.cuotaDiaria,
    this.estado,
    this.fecha,
    this.localId,
    this.mercadoId,
    this.monto,
    this.municipalidadId,
    this.observaciones,
    this.saldoPendiente,
    this.telefonoRepresentante,
    this.correlativo,
    this.numeroBoleta,
    this.anioCorrelativo,
    this.deudaAnterior,
    this.montoAbonadoDeuda,
    this.nuevoSaldoFavor,
    this.pagoACuota,
    this.idsDeudasSaldadas,
  });

  Cobro toDomain() {
    return Cobro(
      id: id,
      cobradorId: cobradorId,
      actualizadoEn: actualizadoEn,
      actualizadoPor: actualizadoPor,
      creadoEn: creadoEn,
      creadoPor: creadoPor,
      cuotaDiaria: cuotaDiaria,
      estado: estado,
      fecha: fecha,
      localId: localId,
      mercadoId: mercadoId,
      monto: monto,
      municipalidadId: municipalidadId,
      observaciones: observaciones,
      saldoPendiente: saldoPendiente,
      telefonoRepresentante: telefonoRepresentante,
      correlativo: correlativo,
      numeroBoleta: numeroBoleta,
      anioCorrelativo: anioCorrelativo,
      deudaAnterior: deudaAnterior,
      montoAbonadoDeuda: montoAbonadoDeuda,
      nuevoSaldoFavor: nuevoSaldoFavor,
      pagoACuota: pagoACuota,
      idsDeudasSaldadas: idsDeudasSaldadas,
    );
  }

  static CobroHive fromDomain(Cobro cobro, {int syncStatus = 1}) {
    return CobroHive(
      id: cobro.id,
      syncStatus: syncStatus,
      cobradorId: cobro.cobradorId,
      actualizadoEn: cobro.actualizadoEn,
      actualizadoPor: cobro.actualizadoPor,
      creadoEn: cobro.creadoEn,
      creadoPor: cobro.creadoPor,
      cuotaDiaria: cobro.cuotaDiaria?.toDouble(),
      estado: cobro.estado,
      fecha: cobro.fecha,
      localId: cobro.localId,
      mercadoId: cobro.mercadoId,
      monto: cobro.monto?.toDouble(),
      municipalidadId: cobro.municipalidadId,
      observaciones: cobro.observaciones,
      saldoPendiente: cobro.saldoPendiente?.toDouble(),
      telefonoRepresentante: cobro.telefonoRepresentante,
      correlativo: cobro.correlativo,
      numeroBoleta: cobro.numeroBoleta,
      anioCorrelativo: cobro.anioCorrelativo,
      deudaAnterior: cobro.deudaAnterior?.toDouble(),
      montoAbonadoDeuda: cobro.montoAbonadoDeuda?.toDouble(),
      nuevoSaldoFavor: cobro.nuevoSaldoFavor?.toDouble(),
      pagoACuota: cobro.pagoACuota?.toDouble(),
      idsDeudasSaldadas: cobro.idsDeudasSaldadas,
    );
  }
}
