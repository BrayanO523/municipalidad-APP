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
  // 1..31 (solo referencia visual para frecuencia mensual)
  final int? diaCobroMensual;

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
    this.diaCobroMensual,
    this.clave,
    this.codigo,
    this.codigoLower,
    this.codigoCatastral,
    this.codigoCatastralLower,
  });

  final List<Map<String, double>>? perimetro;

  num get balanceNeto => (saldoAFavor ?? 0) - (deudaAcumulada ?? 0);

  Local copyWith({
    bool? activo,
    DateTime? actualizadoEn,
    String? actualizadoPor,
    DateTime? creadoEn,
    String? creadoPor,
    num? cuotaDiaria,
    num? espacioM2,
    String? id,
    String? mercadoId,
    String? municipalidadId,
    String? nombreSocial,
    String? qrData,
    String? representante,
    String? telefonoRepresentante,
    String? tipoNegocioId,
    String? ruta,
    double? latitud,
    double? longitud,
    List<Map<String, double>>? perimetro,
    num? saldoAFavor,
    num? deudaAcumulada,
    String? frecuenciaCobro,
    int? diaCobroMensual,
    String? clave,
    String? codigo,
    String? codigoLower,
    String? codigoCatastral,
    String? codigoCatastralLower,
  }) {
    return Local(
      activo: activo ?? this.activo,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      actualizadoPor: actualizadoPor ?? this.actualizadoPor,
      creadoEn: creadoEn ?? this.creadoEn,
      creadoPor: creadoPor ?? this.creadoPor,
      cuotaDiaria: cuotaDiaria ?? this.cuotaDiaria,
      espacioM2: espacioM2 ?? this.espacioM2,
      id: id ?? this.id,
      mercadoId: mercadoId ?? this.mercadoId,
      municipalidadId: municipalidadId ?? this.municipalidadId,
      nombreSocial: nombreSocial ?? this.nombreSocial,
      qrData: qrData ?? this.qrData,
      representante: representante ?? this.representante,
      telefonoRepresentante:
          telefonoRepresentante ?? this.telefonoRepresentante,
      tipoNegocioId: tipoNegocioId ?? this.tipoNegocioId,
      ruta: ruta ?? this.ruta,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      perimetro: perimetro ?? this.perimetro,
      saldoAFavor: saldoAFavor ?? this.saldoAFavor,
      deudaAcumulada: deudaAcumulada ?? this.deudaAcumulada,
      frecuenciaCobro: frecuenciaCobro ?? this.frecuenciaCobro,
      diaCobroMensual: diaCobroMensual ?? this.diaCobroMensual,
      clave: clave ?? this.clave,
      codigo: codigo ?? this.codigo,
      codigoLower: codigoLower ?? this.codigoLower,
      codigoCatastral: codigoCatastral ?? this.codigoCatastral,
      codigoCatastralLower: codigoCatastralLower ?? this.codigoCatastralLower,
    );
  }
}
