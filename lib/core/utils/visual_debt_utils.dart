import '../../features/cobros/domain/entities/cobro.dart';
import '../../features/locales/domain/entities/local.dart';

class VisualDebtUtils {
  static num calcularDeudaVencidaReal(List<Cobro> actualCobros) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    return actualCobros
        .where(
          (c) =>
              (c.estado == 'pendiente' || c.estado == 'abono_parcial') &&
              c.fecha != null &&
              c.fecha!.isBefore(hoy),
        )
        .fold<num>(
          0,
          (sum, c) => sum + (c.saldoPendiente ?? c.cuotaDiaria ?? 0),
        );
  }

  /// Retorna un objeto [Cobro] virtual para hoy si el local no ha pagado
  /// y no tiene días adelantados que cubran la jornada.
  static Cobro? generarHoyPendienteVirtual({
    required Local local,
    required List<Cobro> actualCobros,
  }) {
    if (local.id == null || (local.cuotaDiaria ?? 0) <= 0) return null;

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    // 1. ¿Ya tiene un registro hoy?
    final hoyTieneRegistro = actualCobros.any((c) {
      if (c.fecha == null ||
          c.fecha!.year != hoy.year ||
          c.fecha!.month != hoy.month ||
          c.fecha!.day != hoy.day) {
        return false;
      }
      final pagoACuota = (c.pagoACuota ?? 0);
      final montoAbonadoDeuda = (c.montoAbonadoDeuda ?? 0);
      final esAbonoSoloDeuda = pagoACuota <= 0 && montoAbonadoDeuda > 0;
      if (esAbonoSoloDeuda) return false;
      return true;
    });

    if (hoyTieneRegistro) return null;

    // 2. ¿Tiene días adelantados que cubran hoy?
    final numAdelantados = (local.saldoAFavor ?? 0) ~/ local.cuotaDiaria!;
    if (numAdelantados > 0) return null;

    // 3. Generar el pendiente virtual
    return Cobro(
      id: 'VIRTUAL-HOY',
      localId: local.id,
      fecha: ahora,
      monto: local.cuotaDiaria,
      estado: 'pendiente',
      cuotaDiaria: local.cuotaDiaria,
      saldoPendiente: local.cuotaDiaria,
      observaciones: 'Pendiente - Jornada de hoy en curso.',
    );
  }

  /// Genera la lista de cobros virtuales adelantados basados en el saldo a favor.
  static List<Cobro> generarAdelantadosVirtuales({
    required Local local,
    required List<Cobro> actualCobros,
  }) {
    if (local.id == null || (local.cuotaDiaria ?? 0) <= 0) return [];

    final numAdelantados = (local.saldoAFavor ?? 0) ~/ local.cuotaDiaria!;
    if (numAdelantados <= 0) return [];

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final hoyTieneRegistro = actualCobros.any((c) {
      if (c.fecha == null ||
          c.fecha!.year != hoy.year ||
          c.fecha!.month != hoy.month ||
          c.fecha!.day != hoy.day) {
        return false;
      }
      final pagoACuota = (c.pagoACuota ?? 0);
      final montoAbonadoDeuda = (c.montoAbonadoDeuda ?? 0);
      final esAbonoSoloDeuda = pagoACuota <= 0 && montoAbonadoDeuda > 0;
      if (esAbonoSoloDeuda) return false;
      return true;
    });

    final fechaInicio = hoyTieneRegistro
        ? hoy.add(const Duration(days: 1))
        : hoy;

    return List.generate(numAdelantados, (i) {
      final baseDate = fechaInicio.add(Duration(days: i));
      final timeBase = local.actualizadoEn ?? ahora;

      return Cobro(
        id: 'VIRTUAL-ADE-$i',
        localId: local.id,
        fecha: DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          timeBase.hour,
          timeBase.minute,
        ),
        monto: local.cuotaDiaria,
        estado: 'adelantado',
        cuotaDiaria: local.cuotaDiaria,
        saldoPendiente: 0,
        observaciones: 'Día cubierto por saldo a favor.',
      );
    });
  }

  /// Calcula la deuda acumulada "visual" incluyendo el pendiente de hoy si aplica.
  static num calcularDeudaVisual(Local local, List<Cobro> actualCobros) {
    final deudaBase = local.deudaAcumulada ?? 0;
    final hoyVirtual = generarHoyPendienteVirtual(
      local: local,
      actualCobros: actualCobros,
    );

    return deudaBase +
        (hoyVirtual != null ? (hoyVirtual.saldoPendiente ?? 0) : 0);
  }

  /// Calcula el balance neto "visual" (Saldo a favor - Deuda visual).
  static num calcularBalanceNetoVisual(Local local, List<Cobro> actualCobros) {
    return (local.saldoAFavor ?? 0) - calcularDeudaVisual(local, actualCobros);
  }
}
