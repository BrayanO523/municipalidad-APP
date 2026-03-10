import 'package:equatable/equatable.dart';

class Corte extends Equatable {
  final String id;
  final String cobradorId;
  final String cobradorNombre;
  final String municipalidadId;
  final DateTime fechaCorte;
  final double totalCobrado;
  final int cantidadRegistros;
  final List<String> cobrosIds;
  final DateTime fechaInicioRango;
  final DateTime fechaFinRango;
  final bool liquidado; // true si ya el dinero fue entregado al admin

  const Corte({
    required this.id,
    required this.cobradorId,
    required this.cobradorNombre,
    required this.municipalidadId,
    required this.fechaCorte,
    required this.totalCobrado,
    required this.cantidadRegistros,
    required this.cobrosIds,
    required this.fechaInicioRango,
    required this.fechaFinRango,
    this.liquidado = false,
  });

  @override
  List<Object?> get props => [
        id,
        cobradorId,
        cobradorNombre,
        municipalidadId,
        fechaCorte,
        totalCobrado,
        cantidadRegistros,
        cobrosIds,
        fechaInicioRango,
        fechaFinRango,
        liquidado,
      ];
}
