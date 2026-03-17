class Municipalidad {
  final bool? activa;
  final DateTime? actualizadoEn;
  final String? actualizadoPor;
  final DateTime? creadoEn;
  final String? creadoPor;
  final String? departamento;
  final String? id;
  final String? logo;
  final String? municipio;
  final String? nombre;
  final num? porcentaje;
  final String? slogan;

  /// Fecha de referencia para calcular Mora.
  /// Deudas anteriores al mes/año de esta fecha se consideran Mora.
  /// Si es null se usa el mes actual por defecto.
  final DateTime? fechaReferenciaMora;

  const Municipalidad({
    this.activa,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.departamento,
    this.id,
    this.logo,
    this.municipio,
    this.nombre,
    this.porcentaje,
    this.slogan,
    this.fechaReferenciaMora,
  });
}
