class Mercado {
  final bool? activo;
  final DateTime? actualizadoEn;
  final String? actualizadoPor;
  final DateTime? creadoEn;
  final String? creadoPor;
  final String? id;
  final String? municipalidadId;
  final String? nombre;
  final String? ubicacion;
  final double? latitud;
  final double? longitud;
  final List<Map<String, double>>? perimetro;
  final String? codigo;

  const Mercado({
    this.activo,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.id,
    this.municipalidadId,
    this.nombre,
    this.ubicacion,
    this.latitud,
    this.longitud,
    this.perimetro,
    this.codigo,
  });
}
