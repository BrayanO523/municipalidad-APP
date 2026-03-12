class DistribucionResultado {
  /// Monto que se asigna para abonar a la deuda acumulada antigua (FIFO)
  final num paraDeudaReal;

  /// Monto que se asigna para cubrir la cuota de HOY
  final num pagoACuotaHoy;

  /// Monto excedente que se guarda como saldo a favor nuevo
  final num paraNuevoSaldoFavor;

  /// Cuánto saldo a favor preexistente se consumió para complementar (solo en QR Scanner auto-compl)
  final num saldoFavorConsumido;

  /// Variación neta del saldo a favor (Excedente generado - Saldo consumido/extraído)
  final num deltaSaldoFavor;

  /// Deuda acumulada resultante después de aplicar el cobro (Proyección final)
  final num deudaFinalResultante;

  /// Saldo a favor resultante después de aplicar el cobro (Proyección final)
  final num saldoFavorFinalResultante;

  /// Faltante resultante de la cuota de hoy (0 si se cubrió completa)
  final num estadoCuotaHoy;

  // -- FECHAS PREDICTIVAS (NUEVAS) --
  /// Cantidad entera de días atrasados que logra cubrir este pago
  final int diasAtrasadosSaldados;
  /// Fecha de la cuota más antigua que se empezó a saldar (Inicio del rango de deuda)
  final DateTime? inicioDeudaPagada;
  /// Fecha de la última cuota atrasada que logra saldar (Fin del rango de deuda)
  final DateTime? finDeudaPagada;

  /// Cantidad entera de días que logra "adelantar" el superávit generado (Nuevo Saldo Favor)
  final int diasAdelantados;
  /// Fecha en la que empieza a aplicar el superávit/saldo a favor generado
  final DateTime? inicioDiasAdelantados;
  /// Fecha en la que termina la proyección del superávit generado
  final DateTime? finDiasAdelantados;

  DistribucionResultado({
    required this.paraDeudaReal,
    required this.pagoACuotaHoy,
    required this.paraNuevoSaldoFavor,
    required this.saldoFavorConsumido,
    required this.deltaSaldoFavor,
    required this.deudaFinalResultante,
    required this.saldoFavorFinalResultante,
    required this.estadoCuotaHoy,
    required this.diasAtrasadosSaldados,
    this.inicioDeudaPagada,
    this.finDeudaPagada,
    required this.diasAdelantados,
    this.inicioDiasAdelantados,
    this.finDiasAdelantados,
  });
}

class CalculadoraDistribucionPago {
  /// Calcula la distribución de un cobro utilizando la lógica FIFO (First In, First Out).
  ///
  /// El orden de prioridad es:
  /// 1) Deuda antigua (`deudaAcumuladaInicial`)
  /// 2) Cuota del día (`cuotaDiaria` faltante)
  /// 3) El remanente se va a Saldo a Favor.
  ///
  /// [montoEfectivo]: Lo que el cobrador recibe en billetes
  /// [saldoAExtraer]: Si el usuario decide usar X cantidad de su saldo a favor explícitamente (Home Screen)
  /// [saldoFavorAutomatico]: Si no hay efectivo suficiente, tomar del saldo a favor existente para la cuota (QR Screen)
  /// [saldoFavorInicial]: Saldo a favor que tenía el local antes de este cobro
  /// [fechaReferencia]: La fecha desde la cual partir para calcular las fechas predictivas
  static DistribucionResultado calcular({
    required num montoEfectivo,
    required num deudaAcumuladaInicial,
    required num cuotaDiaria,
    required num pagadoHoyPreviamente,
    required num saldoFavorInicial,
    required DateTime fechaReferencia,
    num saldoAExtraer = 0,             // Control manual explícito
    bool autoComplementarCuotaConSaldo = false, // Comportamiento del QR Scanner
  }) {
    // La bolsa total de dinero disponible para este cobro es la suma de efectivo + saldo extraído.
    // (En la pantalla home `saldoAExtraer` se decide con un input, en QR es 0 y se usa el auto)
    final num bolsaTotal = montoEfectivo + saldoAExtraer;

    // Faltante de la cuota del día de hoy
    final faltanteHoy = (cuotaDiaria - pagadoHoyPreviamente).clamp(0, cuotaDiaria);

    // --- LÓGICA DE DISTRIBUCIÓN EN CASCADA (FIFO) ---

    // 1. Pagar deuda acumulada PRIMERO (Prioridad 1 — FIFO)
    final paraDeudaReal = bolsaTotal > deudaAcumuladaInicial 
        ? deudaAcumuladaInicial 
        : bolsaTotal;
        
    final num montoRestanteTrasDeuda = (bolsaTotal - paraDeudaReal).clamp(0, double.infinity);

    // 2. Pagar cuota de hoy con el restante (Prioridad 2)
    final pagoACuotaHoy = montoRestanteTrasDeuda > faltanteHoy
        ? faltanteHoy
        : montoRestanteTrasDeuda;
        
    final num montoRestanteTrasHoy = (montoRestanteTrasDeuda - pagoACuotaHoy).clamp(0, double.infinity);

    // 3. Excedente a Nuevo Saldo a Favor (Prioridad 3)
    final paraNuevoSaldoFavor = montoRestanteTrasHoy;


    // --- Lógica de complemento automático (Aplica en QR Scanner) ---
    num saldoConsumidoAuto = 0;
    if (autoComplementarCuotaConSaldo) {
      final num faltanteTrasEfectivo = (faltanteHoy - pagoACuotaHoy).clamp(0, double.infinity);
      saldoConsumidoAuto = faltanteTrasEfectivo > saldoFavorInicial
          ? saldoFavorInicial
          : faltanteTrasEfectivo;
    }

    // --- Totales y Deltas ---
    
    // El "consumo" total de saldo a favor previo es el explícito (Home) + el automático (QR)
    final num consumoTotalSaldo = saldoAExtraer + saldoConsumidoAuto;

    // Delta neto del saldo: nuevo excedente generado - saldo viejo consumido
    final num deltaSaldoFavor = paraNuevoSaldoFavor - consumoTotalSaldo;

    // Estado resultante de la jornada de hoy (lo que quedó sin pagar de la cuota de HOY)
    final estadoCuotaHoy = (faltanteHoy - pagoACuotaHoy - saldoConsumidoAuto).clamp(0, cuotaDiaria);

    // Proyecciones finales para el Local (NO suma el faltante de hoy para no confundir la matemática visual)
    final num deudaFinalResultante = deudaAcumuladaInicial - paraDeudaReal;
    final num saldoFavorFinalResultante = saldoFavorInicial + deltaSaldoFavor;

    // --- PROYECCIÓN DE FECHAS (UI) ---
    // Cálculo seguro asumiendo cuotaDiaria > 0. (Si es 0 no se pueden proyectar días lógicos)
    int diasMoraSaldados = 0;
    DateTime? inicioDeuda;
    DateTime? finDeuda;
    
    int diasAdelantados = 0;
    DateTime? inicioAdelanto;
    DateTime? finAdelanto;

    if (cuotaDiaria > 0) {
      // PROYECCIÓN DE DEUDA HACIA ATRÁS:
      if (paraDeudaReal > 0) {
        // ¿Cuántos días totales estaba en mora antes del pago?
        final double diasTotalesMoraDouble = (deudaAcumuladaInicial / cuotaDiaria);
        final int diasTotalesMora = diasTotalesMoraDouble.ceil();
        
        // Pudo haber pagado fracciones, calculamos los días completos redondeados hacia abajo que cubre
        diasMoraSaldados = (paraDeudaReal / cuotaDiaria).floor();
        
        if (diasTotalesMora > 0 && diasMoraSaldados > 0) {
          // El primer día de mora estimado fue hace "diasTotalesMora" días.
          inicioDeuda = fechaReferencia.subtract(Duration(days: diasTotalesMora));
          
          // El rango que pagó cubre desde ese `inicioDeuda` hasta tantos días como pudo saldar
          // (Restamos 1 porque el rango es inclusivo. Ej: Si pago 1 día, inicio = fin)
          finDeuda = inicioDeuda.add(Duration(days: diasMoraSaldados - 1));
        }
      }

      // PROYECCIÓN DE SUPERÁVIT HACIA ADELANTE (Sólo aplica sobre el Nuevo Excedente Generado hoy):
      if (paraNuevoSaldoFavor > 0) {
        diasAdelantados = (paraNuevoSaldoFavor / cuotaDiaria).floor();
        if (diasAdelantados > 0) {
          // El saldo a favor empieza a aplicar desde "mañana" (o desde la última cuota pagada real si hubiera calendario, pero predecimos post-fecha de pago)
          inicioAdelanto = fechaReferencia.add(const Duration(days: 1));
          finAdelanto = inicioAdelanto.add(Duration(days: diasAdelantados - 1));
        }
      }
    }

    return DistribucionResultado(
      paraDeudaReal: paraDeudaReal,
      pagoACuotaHoy: pagoACuotaHoy + saldoConsumidoAuto, // El pago real a cuota es efectivo + saldo usado para ella
      paraNuevoSaldoFavor: paraNuevoSaldoFavor,
      saldoFavorConsumido: consumoTotalSaldo,
      deltaSaldoFavor: deltaSaldoFavor,
      deudaFinalResultante: deudaFinalResultante,
      saldoFavorFinalResultante: saldoFavorFinalResultante,
      estadoCuotaHoy: estadoCuotaHoy,
      diasAtrasadosSaldados: diasMoraSaldados,
      inicioDeudaPagada: inicioDeuda,
      finDeudaPagada: finDeuda,
      diasAdelantados: diasAdelantados,
      inicioDiasAdelantados: inicioAdelanto,
      finDiasAdelantados: finAdelanto,
    );
  }
}
