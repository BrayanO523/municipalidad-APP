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

  /// Agrupador opcional para facilitar asignación de locales a cobradores (ej: "Ruta 1").
  final String? ruta;

  final double? latitud;
  final double? longitud;
  final num? saldoAFavor; // Crédito acumulado por pagos adelantados
  final num? deudaAcumulada; // Suma de cuotas no pagadas histórica

  final String? frecuenciaCobro; // 'diaria', 'semanal', 'quincenal', 'mensual'

  final String? clave;
  final String? codigo;
  final String? codigoLower;
  final String? codigoCatastral;
  final String? codigoCatastralLower;

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
    this.ruta,
    this.latitud,
    this.longitud,
    this.perimetro,
    this.saldoAFavor,
    this.deudaAcumulada,
    this.frecuenciaCobro,
    this.clave,
    this.codigo,
    this.codigoLower,
    this.codigoCatastral,
    this.codigoCatastralLower,
  });

  final List<Map<String, double>>? perimetro;

  num get balanceNeto => (saldoAFavor ?? 0) - (deudaAcumulada ?? 0);
}
