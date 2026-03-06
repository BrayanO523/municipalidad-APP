class Usuario {
  final bool? activo;
  final DateTime? actualizadoEn;
  final String? actualizadoPor;
  final DateTime? creadoEn;
  final String? creadoPor;
  final String? email;
  final String? id;
  final String? municipalidadId;
  final String? mercadoId;
  final List<String>? rutaAsignada;
  final String? nombre;
  final String? rol;

  const Usuario({
    this.activo,
    this.actualizadoEn,
    this.actualizadoPor,
    this.creadoEn,
    this.creadoPor,
    this.email,
    this.id,
    this.municipalidadId,
    this.mercadoId,
    this.rutaAsignada,
    this.nombre,
    this.rol,
  });

  bool get esAdmin => rol == 'admin';
  bool get esCobrador => rol == 'cobrador';
}
