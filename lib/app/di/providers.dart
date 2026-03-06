import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart';
import '../../features/cobros/data/datasources/cobro_datasource.dart';
import '../../features/cobros/domain/entities/cobro.dart';
import '../../features/locales/data/datasources/local_datasource.dart';
import '../../features/locales/domain/entities/local.dart';
import '../../features/mercados/data/datasources/mercado_datasource.dart';
import '../../features/mercados/domain/entities/mercado.dart';
import '../../features/municipalidades/data/datasources/municipalidad_datasource.dart';
import '../../features/municipalidades/domain/entities/municipalidad.dart';
import '../../features/tipos_negocio/data/datasources/tipo_negocio_datasource.dart';
import '../../features/tipos_negocio/domain/entities/tipo_negocio.dart';
import '../../features/usuarios/data/datasources/auth_datasource.dart';
import '../../features/usuarios/domain/entities/usuario.dart';

// Firebase instances
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

// Auth
final authDatasourceProvider = Provider<AuthDatasource>(
  (ref) => AuthDatasource(
    ref.read(firebaseAuthProvider),
    ref.read(firestoreProvider),
  ),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseAuthProvider).authStateChanges();
});

final currentUsuarioProvider = FutureProvider<Usuario?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  final ds = ref.read(authDatasourceProvider);
  return ds.obtenerUsuario(user.uid);
});

// Datasources
final municipalidadDatasourceProvider = Provider<MunicipalidadDatasource>(
  (ref) => MunicipalidadDatasource(ref.read(firestoreProvider)),
);

final mercadoDatasourceProvider = Provider<MercadoDatasource>(
  (ref) => MercadoDatasource(ref.read(firestoreProvider)),
);

final localDatasourceProvider = Provider<LocalDatasource>(
  (ref) => LocalDatasource(ref.read(firestoreProvider)),
);

final tipoNegocioDatasourceProvider = Provider<TipoNegocioDatasource>(
  (ref) => TipoNegocioDatasource(ref.read(firestoreProvider)),
);

final cobroDatasourceProvider = Provider<CobroDatasource>(
  (ref) => CobroDatasource(ref.read(firestoreProvider)),
);

// Data providers (fetchers)
final municipalidadesProvider = FutureProvider<List<Municipalidad>>((
  ref,
) async {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(municipalidadDatasourceProvider);
  final all = await ds.listarTodas();
  if (user?.municipalidadId != null) {
    return all.where((m) => m.id == user!.municipalidadId).toList();
  }
  return all;
});

final mercadosProvider = FutureProvider<List<Mercado>>((ref) async {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(mercadoDatasourceProvider);
  if (user?.municipalidadId != null) {
    return ds.listarPorMunicipalidad(user!.municipalidadId!);
  }
  return ds.listarTodos();
});

final localesProvider = StreamProvider<List<Local>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(localDatasourceProvider);
  if (user?.municipalidadId != null) {
    return ds.streamPorMunicipalidad(user!.municipalidadId!);
  }
  return ds.streamTodos();
});

final tiposNegocioProvider = FutureProvider<List<TipoNegocio>>((ref) async {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(tipoNegocioDatasourceProvider);
  if (user?.municipalidadId != null) {
    return ds.listarPorMunicipalidad(user!.municipalidadId!);
  }
  return ds.listarTodos();
});

final cobrosRecientesProvider = StreamProvider<List<Cobro>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(cobroDatasourceProvider);
  return ds.streamRecientes(municipalidadId: user?.municipalidadId);
});

class FechaFiltroCobrosNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setRango(DateTimeRange? rango) {
    state = rango;
  }
}

final fechaFiltroCobrosProvider =
    NotifierProvider<FechaFiltroCobrosNotifier, DateTimeRange?>(
      FechaFiltroCobrosNotifier.new,
    );

final cobrosFiltradosProvider = StreamProvider<List<Cobro>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(cobroDatasourceProvider);
  final rango = ref.watch(fechaFiltroCobrosProvider);

  if (rango != null) {
    return ds.streamPorRangoFechas(
      rango.start,
      rango.end,
      municipalidadId: user?.municipalidadId,
    );
  }

  return ds.streamRecientes(municipalidadId: user?.municipalidadId);
});

enum DashboardPeriod { hoy, semana, mes, personalizado }

class DashboardFilterState {
  final DashboardPeriod period;
  final DateTimeRange range;
  final String label;
  final String description;

  DashboardFilterState({
    required this.period,
    required this.range,
    required this.label,
    required this.description,
  });

  DashboardFilterState copyWith({
    DashboardPeriod? period,
    DateTimeRange? range,
    String? label,
    String? description,
  }) {
    return DashboardFilterState(
      period: period ?? this.period,
      range: range ?? this.range,
      label: label ?? this.label,
      description: description ?? this.description,
    );
  }
}

class DashboardFilterNotifier extends Notifier<DashboardFilterState> {
  @override
  DashboardFilterState build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DashboardFilterState(
      period: DashboardPeriod.hoy,
      range: DateTimeRange(start: today, end: today),
      label: 'Hoy',
      description: 'Solo datos del día de hoy',
    );
  }

  void setPeriod(DashboardPeriod period) {
    if (period == DashboardPeriod.personalizado &&
        state.period == DashboardPeriod.personalizado) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTimeRange range;
    String label = '';
    String description = '';

    switch (period) {
      case DashboardPeriod.hoy:
        range = DateTimeRange(start: today, end: today);
        label = 'Hoy';
        description = 'Solo datos del día de hoy';
        break;
      case DashboardPeriod.semana:
        range = DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
        label = 'Semana';
        description = 'Últimos 7 días de actividad';
        break;
      case DashboardPeriod.mes:
        range = DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: today,
        );
        label = 'Mes';
        description =
            'Desde el 1 de ${DateFormatter.getMonthName(today)} hasta hoy';
        break;
      case DashboardPeriod.personalizado:
        range = state.range;
        label = 'Personalizado';
        description = 'Rango de fechas seleccionado';
        break;
    }
    state = DashboardFilterState(
      period: period,
      range: range,
      label: label,
      description: description,
    );
  }

  void setCustomRange(DateTimeRange range) {
    state = DashboardFilterState(
      period: DashboardPeriod.personalizado,
      range: range,
      label: 'Personalizado',
      description:
          'Periodo del ${DateFormatter.formatDate(range.start)} al ${DateFormatter.formatDate(range.end)}',
    );
  }
}

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterNotifier, DashboardFilterState>(
      DashboardFilterNotifier.new,
    );

// Mantener compatibilidad mínima o migrar usos de fechaDashboardProvider
@Deprecated('Usar dashboardFilterProvider')
final fechaDashboardProvider = Provider<DateTime>((ref) {
  return ref.watch(dashboardFilterProvider).range.start;
});

final cobrosHoyProvider = StreamProvider<List<Cobro>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(cobroDatasourceProvider);
  final filter = ref.watch(dashboardFilterProvider);

  if (filter.period == DashboardPeriod.hoy) {
    return ds.streamPorFecha(
      filter.range.start,
      municipalidadId: user?.municipalidadId,
    );
  } else {
    return ds.streamPorRangoFechas(
      filter.range.start,
      filter.range.end,
      municipalidadId: user?.municipalidadId,
    );
  }
});

final usuariosProvider = FutureProvider<List<Usuario>>((ref) async {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(authDatasourceProvider);
  return ds.listarTodos(municipalidadId: user?.municipalidadId);
});

final localStreamProvider = StreamProvider.family<Local?, String>((ref, id) {
  final ds = ref.read(localDatasourceProvider);
  return ds.streamPorId(id);
});

final localCobrosStreamProvider = StreamProvider.family<List<Cobro>, String>((
  ref,
  id,
) {
  final ds = ref.read(cobroDatasourceProvider);
  return ds.streamPorLocal(id);
});
