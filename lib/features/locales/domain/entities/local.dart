class Local {
  final bool? activo;
  final DateTime? actualizadoEn;
  final String? actualizadoPor;
  final DateTime? creadoEn;
  final String? creadoPor;
  final num? cuotaDiaria;
  final num? espacioM2;
  final String? id;
  final String? mercadoId;
  final String? municipalidadId;
  final String? nombreSocial;
  final String? qrData;
  final String? representante;
  final String? telefonoRepresentante;
  final String? tipoNegocioId;

  final double? latitud;
  final double? longitud;
  final num? saldoAFavor; // Crédito acumulado por pagos adelantados
  final num? deudaAcumulada; // Suma de cuotas no pagadas histórica

  const Local({
    this.activo,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.cuotaDiaria,
    this.espacioM2,
    this.id,
    this.mercadoId,
    this.municipalidadId,
    this.nombreSocial,
    this.qrData,
    this.representante,
    this.telefonoRepresentante,
    this.tipoNegocioId,
    this.latitud,
    this.longitud,
    this.perimetro,
    this.saldoAFavor,
    this.deudaAcumulada,
  });

  final List<Map<String, double>>? perimetro;

  num get balanceNeto => (saldoAFavor ?? 0) - (deudaAcumulada ?? 0);
}
