import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/repositories/cobro_repository.dart';
import '../../../locales/domain/repositories/local_repository.dart';

final cobroViewModelProvider = AsyncNotifierProvider<CobroViewModel, void>(() {
  return CobroViewModel();
});

class CobroViewModel extends AsyncNotifier<void> {
  late final CobroRepository _cobroRepository;
  late final LocalRepository _localRepository;

  @override
  FutureOr<void> build() {
    _cobroRepository = ref.read(cobroRepositoryProvider);
    _localRepository = ref.read(localRepositoryProvider);
  }

  /// Realiza todo el flujo de registro de un cobro garantizando MVVM
  /// y usando el almacenamiento Offline NoSQL (Hive)
  Future<String?> registrarPago({
    required Cobro cobro,
    required String mercadoId,
    required String localId,
    required num montoAbonadoDeuda,
    required num incrementoSaldoFavor,
  }) async {
    try {
      state = const AsyncValue.loading();

      // 1. Ejecutar registro de cobro y actualización de balances en paralelo
      final results = await Future.wait([
        _cobroRepository.registrarCobroCompleto(cobro, localId),
        _localRepository.procesarPagoOfflineSafe(
          localId,
          montoAbonadoDeuda,
          incrementoSaldoFavor,
        ),
      ]);

      final String? correlativo = results[0] as String?;
      state = const AsyncValue.data(null);
      return correlativo;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> eliminarCobro(Cobro cobro) async {
    try {
      state = const AsyncValue.loading();
      await _cobroRepository.eliminarCobro(cobro);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
