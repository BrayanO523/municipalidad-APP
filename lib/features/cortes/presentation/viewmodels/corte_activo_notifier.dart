import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../domain/entities/corte.dart';

// State class for the active cut
class CorteActivoState {
  final bool isLoading;
  final String? error;
  final double total;
  final int cantidad;
  final DateTime fecha;
  final List<String> cobrosIds;
  final bool yaRealizadoHoy;

  const CorteActivoState({
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.cantidad = 0,
    required this.fecha,
    this.cobrosIds = const [],
    this.yaRealizadoHoy = false,
  });

  CorteActivoState copyWith({
    bool? isLoading,
    String? error,
    double? total,
    int? cantidad,
    DateTime? fecha,
    List<String>? cobrosIds,
    bool? yaRealizadoHoy,
  }) {
    return CorteActivoState(
      isLoading: isLoading ?? this.isLoading,
      // Use explicit null so error can be cleared; if error is null & nothing
      // passed in, keep existing error
      error: error,
      total: total ?? this.total,
      cantidad: cantidad ?? this.cantidad,
      fecha: fecha ?? this.fecha,
      cobrosIds: cobrosIds ?? this.cobrosIds,
      yaRealizadoHoy: yaRealizadoHoy ?? this.yaRealizadoHoy,
    );
  }
}

// Notifier — uses plain Notifier<T> matching the rest of the project
class CorteActivoNotifier extends Notifier<CorteActivoState> {
  @override
  CorteActivoState build() {
    final cobrosAsync = ref.watch(cobrosHoyCobradorProvider);
    // ignore: deprecated_member_use_from_same_package
    final historialAsync = ref.watch(cortesHistorialCobradorProvider);

    final cobros = cobrosAsync.value ?? [];
    final historial = historialAsync.value ?? [];

    double total = 0;
    final List<String> ids = [];

    for (final cobro in cobros) {
      total += (cobro.monto ?? 0).toDouble();
      if (cobro.id != null) ids.add(cobro.id!);
    }

    final now = DateTime.now();
    final hoyInicio = DateTime(now.year, now.month, now.day);

    final realizado = historial.any((corte) {
      final fechaCorte = DateTime(
        corte.fechaCorte.year,
        corte.fechaCorte.month,
        corte.fechaCorte.day,
      );
      return fechaCorte.isAtSameMomentAs(hoyInicio);
    });

    return CorteActivoState(
      isLoading: false,
      error: null,
      total: total,
      cantidad: cobros.length,
      fecha: now,
      cobrosIds: ids,
      yaRealizadoHoy: realizado,
    );
  }

  /// Persiste el corte en Firestore usando el repositorio.
  Future<bool> realizarCorte() async {
    if (state.cantidad == 0 || state.yaRealizadoHoy) return false;

    state = state.copyWith(isLoading: true);

    try {
      final user = ref.read(currentUsuarioProvider).value;
      if (user == null || user.id == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return false;
      }

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day);
      final fin = inicio
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));

      final nuevoCorte = Corte(
        id: '',
        cobradorId: user.id!,
        cobradorNombre: user.nombre ?? 'Desconocido',
        municipalidadId: user.municipalidadId ?? '',
        fechaCorte: now,
        totalCobrado: state.total,
        cantidadRegistros: state.cantidad,
        cobrosIds: state.cobrosIds,
        fechaInicioRango: inicio,
        fechaFinRango: fin,
        liquidado: false,
      );

      final repo = ref.read(corteRepositoryProvider);
      final result = await repo.crearCorte(nuevoCorte);

      return result.fold(
        (failure) {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, yaRealizadoHoy: true);
          return true;
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final corteActivoProvider =
    NotifierProvider<CorteActivoNotifier, CorteActivoState>(
  CorteActivoNotifier.new,
);
