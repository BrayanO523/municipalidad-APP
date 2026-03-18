import '../../features/locales/domain/entities/local.dart';

class MonthlyVisualInfo {
  final int diaCobroConfigurado;
  final DateTime cicloInicio;
  final DateTime cicloFin;
  final int diasDelCiclo;
  final int diasTranscurridos;
  final double cuotaDiariaBase;
  final double cuotaCicloMensual;
  final double acumuladoHastaHoy;

  const MonthlyVisualInfo({
    required this.diaCobroConfigurado,
    required this.cicloInicio,
    required this.cicloFin,
    required this.diasDelCiclo,
    required this.diasTranscurridos,
    required this.cuotaDiariaBase,
    required this.cuotaCicloMensual,
    required this.acumuladoHastaHoy,
  });
}

class MonthlyVisualUtils {
  static MonthlyVisualInfo? calcular(Local local, {DateTime? referencia}) {
    final frecuencia = (local.frecuenciaCobro ?? '').toLowerCase();
    final diaCobro = local.diaCobroMensual;
    final cuota = (local.cuotaDiaria ?? 0).toDouble();

    if (frecuencia != 'mensual') return null;
    if (diaCobro == null || diaCobro < 1 || diaCobro > 31) return null;
    if (cuota <= 0) return null;

    final now = referencia ?? DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);

    // 1) Ciclo real según diaCobroMensual: [diaCobro ... diaCobro-1]
    final vencimientoMesActual = _fechaConDiaAjustado(
      year: hoy.year,
      month: hoy.month,
      day: diaCobro,
    );

    late final DateTime inicioCiclo;
    late final DateTime finCiclo;

    if (hoy.isBefore(vencimientoMesActual)) {
      final mesAnterior = DateTime(hoy.year, hoy.month - 1, 1);
      inicioCiclo = _fechaConDiaAjustado(
        year: mesAnterior.year,
        month: mesAnterior.month,
        day: diaCobro,
      );
      finCiclo = vencimientoMesActual.subtract(const Duration(days: 1));
    } else {
      final mesSiguiente = DateTime(hoy.year, hoy.month + 1, 1);
      inicioCiclo = vencimientoMesActual;
      finCiclo = _fechaConDiaAjustado(
        year: mesSiguiente.year,
        month: mesSiguiente.month,
        day: diaCobro,
      ).subtract(const Duration(days: 1));
    }

    final diasDelCiclo = finCiclo.difference(inicioCiclo).inDays + 1;

    // 2) Acumulado visual del mes actual: [día 1 ... hoy]
    final inicioMes = DateTime(hoy.year, hoy.month, 1);
    final diasMesActual = DateTime(hoy.year, hoy.month + 1, 0).day;
    final diasTranscurridosMes = (hoy.difference(inicioMes).inDays + 1).clamp(
      0,
      diasMesActual,
    );

    return MonthlyVisualInfo(
      diaCobroConfigurado: diaCobro,
      cicloInicio: inicioCiclo,
      cicloFin: finCiclo,
      diasDelCiclo: diasDelCiclo,
      diasTranscurridos: diasTranscurridosMes,
      cuotaDiariaBase: cuota,
      cuotaCicloMensual: cuota * diasDelCiclo,
      acumuladoHastaHoy: cuota * diasTranscurridosMes,
    );
  }

  static DateTime _fechaConDiaAjustado({
    required int year,
    required int month,
    required int day,
  }) {
    final ultimoDiaMes = DateTime(year, month + 1, 0).day;
    final diaAjustado = day <= ultimoDiaMes ? day : ultimoDiaMes;
    return DateTime(year, month, diaAjustado);
  }
}
