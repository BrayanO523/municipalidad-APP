class Cobro {
  final String? cobradorId;
  final DateTime? actualizadoEn;
  final String? actualizadoPor;
  final DateTime? creadoEn;
  final String? creadoPor;
  final num? cuotaDiaria;
  final String? estado;
  final DateTime? fecha;
  final String? id;
  final String? localId;
  final String? mercadoId;
  final num? monto;
  final String? municipalidadId;
  final String? observaciones;
  final num? saldoPendiente;
  final String? telefonoRepresentante;
  final int? correlativo;
  final int? anioCorrelativo;
  final num? deudaAnterior;
  final num? montoAbonadoDeuda;
  final num? nuevoSaldoFavor;
  final num? pagoACuota;

  const Cobro({
    this.cobradorId,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.cuotaDiaria,
    this.estado,
    this.fecha,
    this.id,
    this.localId,
    this.mercadoId,
    this.monto,
    this.municipalidadId,
    this.observaciones,
    this.saldoPendiente,
    this.telefonoRepresentante,
    this.correlativo,
    this.anioCorrelativo,
    this.deudaAnterior,
    this.montoAbonadoDeuda,
    this.nuevoSaldoFavor,
    this.pagoACuota,
  });
}
