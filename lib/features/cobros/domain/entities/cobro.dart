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
  });
}
