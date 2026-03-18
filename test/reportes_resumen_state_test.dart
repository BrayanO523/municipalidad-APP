import 'package:flutter_test/flutter_test.dart';

import 'package:municipalidad/app/di/providers.dart';
import 'package:municipalidad/features/cobros/domain/entities/cobro.dart';
import 'package:municipalidad/features/locales/domain/entities/local.dart';
import 'package:municipalidad/features/reportes/presentation/viewmodels/reportes_notifier.dart';

void main() {
  group('ReportesResumenState KPIs', () {
    test('calcula cobrado, pendiente y mora del periodo excluyendo anulados', () {
      final state = ReportesResumenState(
        period: DashboardPeriod.hoy,
        cobros: [
          const Cobro(
            estado: 'cobrado',
            monto: 100,
            saldoPendiente: 0,
            montoMora: 15,
          ),
          const Cobro(
            estado: 'abono_parcial',
            monto: 20,
            saldoPendiente: 80,
            montoMora: 5,
          ),
          const Cobro(
            estado: 'pendiente',
            monto: 0,
            saldoPendiente: 50,
          ),
          const Cobro(
            estado: 'cobrado_saldo',
            monto: 30,
            pagoACuota: 30,
            saldoPendiente: 0,
            montoMora: 2,
          ),
          const Cobro(
            estado: 'anulado',
            monto: 999,
            saldoPendiente: 999,
            montoMora: 999,
          ),
        ],
        locales: const [],
      );

      // Cobrado excluye cobrado_saldo y anulados
      expect(state.totalCobrado, 120);
      // Pendiente suma pendientes/abono_parcial del periodo
      expect(state.totalPendiente, 130);
      // Mora recuperada excluye anulados
      expect(state.totalMora, 22);
    });

    test('calcula saldo a favor generado y consumido como delta del periodo', () {
      final state = ReportesResumenState(
        period: DashboardPeriod.semana,
        cobros: [
          // Delta +20 (genera credito)
          const Cobro(
            estado: 'cobrado',
            monto: 120,
            montoAbonadoDeuda: 40,
            pagoACuota: 60,
          ),
          // Delta -15 (consume credito)
          const Cobro(
            estado: 'cobrado',
            monto: 35,
            montoAbonadoDeuda: 10,
            pagoACuota: 40,
          ),
          // Delta -25 (pago con saldo a favor)
          const Cobro(
            estado: 'cobrado_saldo',
            monto: 0,
            pagoACuota: 25,
          ),
          // Anulado no debe impactar
          const Cobro(
            estado: 'anulado',
            monto: 500,
            montoAbonadoDeuda: 0,
            pagoACuota: 0,
          ),
        ],
        locales: const [
          Local(saldoAFavor: 12),
          Local(saldoAFavor: 8),
          Local(saldoAFavor: -5),
        ],
      );

      // Saldo a favor actual = foto de locales
      expect(state.totalSaldosAFavor, 20);
      // Generado en el periodo via deltas
      expect(state.saldoFavorGeneradoPeriodo, 20);
      expect(state.totalSaldoFavorConsumido, 40);
    });
  });
}
