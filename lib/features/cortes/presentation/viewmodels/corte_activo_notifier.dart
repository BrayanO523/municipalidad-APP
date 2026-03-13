import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import 'cortes_paginados_notifier.dart';
import '../../domain/entities/corte.dart';

// State class for the active cut
class CorteActivoState {
  final bool isLoading;
  final String? error;
  final double total;
  final int cantidad; // total de locales en ruta
  final int cantidadCobrados;
  final int cantidadPendientes;
  final DateTime fecha;
  final List<String> cobrosIds;
  final bool yaRealizadoHoy;
  /// Lista ligera [{localId, nombreSocial, montoPendiente}] para persistir y mostrar.
  final List<Map<String, dynamic>> pendientesInfo;

  const CorteActivoState({
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.cantidad = 0,
    this.cantidadCobrados = 0,
    this.cantidadPendientes = 0,
    required this.fecha,
    this.cobrosIds = const [],
    this.yaRealizadoHoy = false,
    this.pendientesInfo = const [],
  });

  CorteActivoState copyWith({
    bool? isLoading,
    String? error,
    double? total,
    int? cantidad,
    int? cantidadCobrados,
    int? cantidadPendientes,
    DateTime? fecha,
    List<String>? cobrosIds,
    bool? yaRealizadoHoy,
    List<Map<String, dynamic>>? pendientesInfo,
  }) {
    return CorteActivoState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      cantidad: cantidad ?? this.cantidad,
      cantidadCobrados: cantidadCobrados ?? this.cantidadCobrados,
      cantidadPendientes: cantidadPendientes ?? this.cantidadPendientes,
      fecha: fecha ?? this.fecha,
      cobrosIds: cobrosIds ?? this.cobrosIds,
      yaRealizadoHoy: yaRealizadoHoy ?? this.yaRealizadoHoy,
      pendientesInfo: pendientesInfo ?? this.pendientesInfo,
    );
  }
}

// Notifier — uses plain Notifier<T> matching the rest of the project
class CorteActivoNotifier extends Notifier<CorteActivoState> {
  @override
  CorteActivoState build() {
    final cobrosAsync = ref.watch(cobrosHoyCobradorProvider);
    final historialAsync = ref.watch(cortesHoyCobradorStreamProvider);
    final localesAsync = ref.watch(localesCobradorProvider);

    final cobros = cobrosAsync.value ?? [];
    final historial = historialAsync.value ?? [];
    final todosLocales = localesAsync.value ?? [];
    final localesActivos = todosLocales.where((l) => l.activo == true).toList();

    double total = 0;
    final List<String> ids = [];
    final Map<String, num> pagosCuotaPorLocal = {};

    for (final cobro in cobros) {
      if (cobro.id != null) ids.add(cobro.id!);
      final monto = (cobro.monto ?? 0).toDouble();
      final estado = cobro.estado ?? '';

      // Dinero físico recaudado
      if (estado == 'cobrado' || estado == 'cobrado_saldo') {
        total += monto;
      }

      // Pagos a cuota por local (igual al dashboard)
      final lid = cobro.localId;
      if (lid != null) {
        pagosCuotaPorLocal[lid] =
            (pagosCuotaPorLocal[lid] ?? 0) + (cobro.pagoACuota ?? 0);
      }
    }

    // Clasificar locales como cobrados o pendientes
    int cobrados = 0;
    int pendientes = 0;
    final List<Map<String, dynamic>> listaPendientes = [];

    for (final local in localesActivos) {
      final pagoCuotaL = pagosCuotaPorLocal[local.id] ?? 0;
      final saldoFavor = local.saldoAFavor ?? 0;
      final cuota = local.cuotaDiaria ?? 0;

      if ((pagoCuotaL >= cuota) || (saldoFavor >= cuota)) {
        cobrados++;
      } else {
        pendientes++;
        listaPendientes.add({
          'localId': local.id ?? '',
          'nombreSocial': local.nombreSocial ?? 'S/N',
          'montoPendiente': (cuota - pagoCuotaL).toDouble(),
        });
      }
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
      cantidad: localesActivos.length,
      cantidadCobrados: cobrados,
      cantidadPendientes: pendientes,
      fecha: now,
      cobrosIds: ids,
      yaRealizadoHoy: realizado,
      pendientesInfo: listaPendientes,
    );
  }

  /// Persiste el corte en Firestore usando el repositorio.
  Future<bool> realizarCorte() async {
    // Permitir corte si hay locales en la ruta (aunque no haya cobros)
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

      // Obtener nombre del mercado para incluirlo en el corte
      String? mercadoNombre;
      if (user.mercadoId != null && user.mercadoId!.isNotEmpty) {
        final mercadoRepo = ref.read(mercadoRepositoryProvider);
        final mercado = await mercadoRepo.obtenerPorId(user.mercadoId!);
        mercadoNombre = mercado?.nombre;
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
        cantidadCobrados: state.cantidadCobrados,
        cantidadPendientes: state.cantidadPendientes,
        cobrosIds: state.cobrosIds,
        fechaInicioRango: inicio,
        fechaFinRango: fin,
        liquidado: false,
        tipo: 'cobrador',
        mercadoId: user.mercadoId,
        mercadoNombre: mercadoNombre,
        pendientesInfo: state.pendientesInfo,
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
          // Invalidar el historial paginado para que se refresque con el nuevo corte
          ref.invalidate(cortesCobradorPaginadosProvider);
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

