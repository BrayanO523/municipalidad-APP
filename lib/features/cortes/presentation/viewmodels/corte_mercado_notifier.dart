import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../domain/entities/corte.dart';

// ───────────────────────────────────────────────────────────────
// Estado del Corte de Mercado
// ───────────────────────────────────────────────────────────────
class CorteMercadoState {
  final bool isLoading;
  final String? error;
  final Mercado? mercadoSeleccionado;
  final DateTime fechaSeleccionada;
  final List<Corte> cortesDelDia;
  final bool yaRealizadoHoy;
  final bool exitoAlRealizar;

  const CorteMercadoState({
    this.isLoading = false,
    this.error,
    this.mercadoSeleccionado,
    required this.fechaSeleccionada,
    this.cortesDelDia = const [],
    this.yaRealizadoHoy = false,
    this.exitoAlRealizar = false,
  });

  double get totalConsolidado =>
      cortesDelDia.fold(0.0, (sum, c) => sum + c.totalCobrado);

  int get cantidadCobros =>
      cortesDelDia.fold(0, (sum, c) => sum + c.cantidadRegistros);

  int get cantidadCobrados =>
      cortesDelDia.fold(0, (sum, c) => sum + (c.cantidadCobrados ?? 0));

  int get cantidadPendientes =>
      cortesDelDia.fold(0, (sum, c) => sum + (c.cantidadPendientes ?? 0));

  List<String> get cobrosIdsConsolidados =>
      cortesDelDia.expand((c) => c.cobrosIds).toList();

  CorteMercadoState copyWith({
    bool? isLoading,
    String? error,
    Mercado? mercadoSeleccionado,
    DateTime? fechaSeleccionada,
    List<Corte>? cortesDelDia,
    bool? yaRealizadoHoy,
    bool? exitoAlRealizar,
    bool clearError = false,
  }) {
    return CorteMercadoState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      mercadoSeleccionado: mercadoSeleccionado ?? this.mercadoSeleccionado,
      fechaSeleccionada: fechaSeleccionada ?? this.fechaSeleccionada,
      cortesDelDia: cortesDelDia ?? this.cortesDelDia,
      yaRealizadoHoy: yaRealizadoHoy ?? this.yaRealizadoHoy,
      exitoAlRealizar: exitoAlRealizar ?? this.exitoAlRealizar,
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Notifier — usando Notifier<T> igual que el resto del proyecto
// ───────────────────────────────────────────────────────────────
class CorteMercadoNotifier extends Notifier<CorteMercadoState> {
  StreamSubscription<List<Corte>>? _subscription;

  @override
  CorteMercadoState build() {
    ref.onDispose(() => _subscription?.cancel());
    return CorteMercadoState(fechaSeleccionada: DateTime.now());
  }

  /// Selecciona un mercado y se suscribe al stream de cortes del día en tiempo real.
  Future<void> seleccionarMercado(Mercado mercado) async {
    // Cancelar suscripción anterior
    await _subscription?.cancel();
    _subscription = null;

    state = state.copyWith(mercadoSeleccionado: mercado, isLoading: true);
    await _suscribirStream(mercado);
  }

  /// Cambia la fecha seleccionada y recarga los cortes.
  Future<void> seleccionarFecha(DateTime fecha) async {
    final mercado = state.mercadoSeleccionado;
    if (mercado == null) return;

    await _subscription?.cancel();
    _subscription = null;

    state = state.copyWith(
      fechaSeleccionada: fecha,
      isLoading: true,
      clearError: true,
    );
    await _suscribirStream(mercado);
  }

  Future<void> recargar() async {
    final mercado = state.mercadoSeleccionado;
    if (mercado == null) return;
    await _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(isLoading: true, clearError: true);
    await _suscribirStream(mercado);
  }

  Future<void> _suscribirStream(Mercado mercado) async {
    try {
      final user = ref.read(currentUsuarioProvider).value;
      if (user == null || mercado.id == null) {
        state = state.copyWith(isLoading: false, error: 'Datos insuficientes.');
        return;
      }

      final repo = ref.read(corteRepositoryProvider);
      final now = DateTime.now();
      final fecha = state.fechaSeleccionada;

      // Verificar si ya realizó corte de mercado hoy (solo si la fecha seleccionada es hoy)
      final yaRealizado =
          fecha.year == now.year &&
              fecha.month == now.month &&
              fecha.day == now.day
          ? (await repo.existeCorteMercadoHoy(
              mercadoId: mercado.id!,
              municipalidadId: user.municipalidadId ?? '',
              fecha: now,
            )).getOrElse((_) => false)
          : false;

      // Suscribirse al stream en tiempo real
      _subscription = repo
          .streamCortesDiaPorMercado(
            mercadoId: mercado.id!,
            municipalidadId: user.municipalidadId ?? '',
            fecha: fecha,
          )
          .listen(
            (cortes) {
              state = state.copyWith(
                isLoading: false,
                cortesDelDia: cortes,
                yaRealizadoHoy: yaRealizado,
              );
            },
            onError: (e) {
              state = state.copyWith(
                isLoading: false,
                error: 'Error al escuchar cortes: $e',
              );
            },
          );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar cortes: $e',
      );
    }
  }

  /// Crea el Corte de Mercado consolidando todos los cortes del día.
  Future<bool> realizarCorteMercado() async {
    final mercado = state.mercadoSeleccionado;
    if (mercado == null || state.cortesDelDia.isEmpty || state.yaRealizadoHoy) {
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = ref.read(currentUsuarioProvider).value;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado.',
        );
        return false;
      }

      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, now.day);
      final fin = inicio
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));

      final corteMercado = Corte(
        id: '',
        cobradorId: user.id!,
        cobradorNombre: user.nombre ?? 'Admin',
        municipalidadId: user.municipalidadId ?? '',
        fechaCorte: now,
        totalCobrado: state.totalConsolidado,
        cantidadRegistros: state.cantidadCobros,
        cantidadCobrados: state.cantidadCobrados,
        cantidadPendientes: state.cantidadPendientes,
        cobrosIds: state.cobrosIdsConsolidados,
        fechaInicioRango: inicio,
        fechaFinRango: fin,
        liquidado: false,
        tipo: 'mercado',
        mercadoId: mercado.id,
        mercadoNombre: mercado.nombre,
        cortesCobradorIds: state.cortesDelDia.map((c) => c.id).toList(),
      );

      final repo = ref.read(corteRepositoryProvider);
      final result = await repo.crearCorte(corteMercado);

      return result.fold(
        (failure) {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(
            isLoading: false,
            yaRealizadoHoy: true,
            exitoAlRealizar: true,
          );
          return true;
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final corteMercadoProvider =
    NotifierProvider<CorteMercadoNotifier, CorteMercadoState>(
      CorteMercadoNotifier.new,
    );
