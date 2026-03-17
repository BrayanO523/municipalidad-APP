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

  // --- Nuevos campos para Corte de Mercado ---
  /// 'cobrador' | 'mercado'. Null = cobrador (retrocompatible con docs viejos).
  final String? tipo;
  final String? mercadoId;
  final String? mercadoNombre;
  /// IDs de los cortes de cobradores que este corte de mercado consolida.
  final List<String>? cortesCobradorIds;

  // --- Conteos desglosados ---
  final int? cantidadCobrados;
  final int? cantidadPendientes;
  
  // --- Lista ligera de locales pendientes para reporte ---
  final List<Map<String, dynamic>>? pendientesInfo;

  // --- Lista ligera de gestiones/incidencias del día ---
  final List<Map<String, dynamic>>? gestionesInfo;

  // --- Rango de correlativos de boletas ---
  final String? primerBoleta;
  final String? ultimaBoleta;

  // --- Desglose Mora / Corriente ---
  /// Total recaudado correspondiente a deudas de meses anteriores al de referencia.
  final double? totalMora;
  /// Total recaudado correspondiente al mes de referencia (corriente).
  final double? totalCorriente;

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
    this.tipo,
    this.mercadoId,
    this.mercadoNombre,
    this.cortesCobradorIds,
    this.cantidadCobrados,
    this.cantidadPendientes,
    this.pendientesInfo,
    this.gestionesInfo,
    this.primerBoleta,
    this.ultimaBoleta,
    this.totalMora,
    this.totalCorriente,
  });

  bool get esCorteMercado => tipo == 'mercado';

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
        tipo,
        mercadoId,
        mercadoNombre,
        cortesCobradorIds,
        cantidadCobrados,
        cantidadPendientes,
        pendientesInfo,
        gestionesInfo,
        primerBoleta,
        ultimaBoleta,
        totalMora,
        totalCorriente,
      ];
}
