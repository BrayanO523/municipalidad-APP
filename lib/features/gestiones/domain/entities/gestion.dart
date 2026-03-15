/// Tipos de incidencia predefinidos para registro rápido.
enum TipoIncidencia {
  cerrado,
  ausente,
  sinEfectivo,
  negado,
  volverTarde,
  otro;

  String get label {
    switch (this) {
      case TipoIncidencia.cerrado:
        return 'Local Cerrado';
      case TipoIncidencia.ausente:
        return 'Encargado Ausente';
      case TipoIncidencia.sinEfectivo:
        return 'Sin Efectivo hoy';
      case TipoIncidencia.negado:
        return 'Se niega a pagar';
      case TipoIncidencia.volverTarde:
        return 'Volver más tarde';
      case TipoIncidencia.otro:
        return 'Otro motivo';
    }
  }

  String get firestoreValue {
    switch (this) {
      case TipoIncidencia.cerrado:
        return 'CERRADO';
      case TipoIncidencia.ausente:
        return 'AUSENTE';
      case TipoIncidencia.sinEfectivo:
        return 'SIN_EFECTIVO';
      case TipoIncidencia.negado:
        return 'NEGADO';
      case TipoIncidencia.volverTarde:
        return 'VOLVER_TARDE';
      case TipoIncidencia.otro:
        return 'OTRO';
    }
  }

  static TipoIncidencia fromFirestore(String value) {
    switch (value) {
      case 'CERRADO':
        return TipoIncidencia.cerrado;
      case 'AUSENTE':
        return TipoIncidencia.ausente;
      case 'SIN_EFECTIVO':
        return TipoIncidencia.sinEfectivo;
      case 'NEGADO':
        return TipoIncidencia.negado;
      case 'VOLVER_TARDE':
        return TipoIncidencia.volverTarde;
      case 'OTRO':
      default:
        return TipoIncidencia.otro;
    }
  }
}

/// Entidad de dominio que representa una gestión/incidencia
/// registrada por el cobrador cuando no puede concretar el recaudo.
class Gestion {
  final String? id;
  final DateTime? timestamp;
  final String? localId;
  final String? cobradorId;
  final String? tipoIncidencia;
  final String? comentario;
  final double? latitud;
  final double? longitud;
  final String? municipalidadId;
  final String? mercadoId;

  const Gestion({
    this.id,
    this.timestamp,
    this.localId,
    this.cobradorId,
    this.tipoIncidencia,
    this.comentario,
    this.latitud,
    this.longitud,
    this.municipalidadId,
    this.mercadoId,
  });
}
