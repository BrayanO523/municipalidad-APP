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
  final String? numeroBoleta; // E.g., "2026-VERD-14"
  final num? deudaAnterior;
  final num? montoAbonadoDeuda;
  final num? nuevoSaldoFavor;
  final num? pagoACuota;
  final List<String>? idsDeudasSaldadas;
  final List<DateTime>? fechasDeudasSaldadas;

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
    this.numeroBoleta,
    this.deudaAnterior,
    this.montoAbonadoDeuda,
    this.nuevoSaldoFavor,
    this.pagoACuota,
    this.idsDeudasSaldadas,
    this.fechasDeudasSaldadas,
  });

  Cobro copyWith({
    String? cobradorId,
    DateTime? actualizadoEn,
    String? actualizadoPor,
    DateTime? creadoEn,
    String? creadoPor,
    num? cuotaDiaria,
    String? estado,
    DateTime? fecha,
    String? id,
    String? localId,
    String? mercadoId,
    num? monto,
    String? municipalidadId,
    String? observaciones,
    num? saldoPendiente,
    String? telefonoRepresentante,
    int? correlativo,
    int? anioCorrelativo,
    String? numeroBoleta,
    num? deudaAnterior,
    num? montoAbonadoDeuda,
    num? nuevoSaldoFavor,
    num? pagoACuota,
    List<String>? idsDeudasSaldadas,
    List<DateTime>? fechasDeudasSaldadas,
  }) {
    return Cobro(
      cobradorId: cobradorId ?? this.cobradorId,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      actualizadoPor: actualizadoPor ?? this.actualizadoPor,
      creadoEn: creadoEn ?? this.creadoEn,
      creadoPor: creadoPor ?? this.creadoPor,
      cuotaDiaria: cuotaDiaria ?? this.cuotaDiaria,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      id: id ?? this.id,
      localId: localId ?? this.localId,
      mercadoId: mercadoId ?? this.mercadoId,
      monto: monto ?? this.monto,
      municipalidadId: municipalidadId ?? this.municipalidadId,
      observaciones: observaciones ?? this.observaciones,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      telefonoRepresentante:
          telefonoRepresentante ?? this.telefonoRepresentante,
      correlativo: correlativo ?? this.correlativo,
      anioCorrelativo: anioCorrelativo ?? this.anioCorrelativo,
      numeroBoleta: numeroBoleta ?? this.numeroBoleta,
      deudaAnterior: deudaAnterior ?? this.deudaAnterior,
      montoAbonadoDeuda: montoAbonadoDeuda ?? this.montoAbonadoDeuda,
      nuevoSaldoFavor: nuevoSaldoFavor ?? this.nuevoSaldoFavor,
      pagoACuota: pagoACuota ?? this.pagoACuota,
      idsDeudasSaldadas: idsDeudasSaldadas ?? this.idsDeudasSaldadas,
      fechasDeudasSaldadas: fechasDeudasSaldadas ?? this.fechasDeudasSaldadas,
    );
  }

  /// Retorna el string oficial de la boleta o hace un fallback al int viejo
  String get numeroBoletaFmt {
    if (numeroBoleta != null && numeroBoleta!.isNotEmpty) return numeroBoleta!;
    if (correlativo != null && correlativo != 0) return correlativo.toString();
    return '0';
  }
}
