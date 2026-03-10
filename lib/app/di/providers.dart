import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/utils/date_formatter.dart';
import '../../features/cobros/data/datasources/cobro_datasource.dart';
import '../../features/cobros/domain/entities/cobro.dart';
import '../../features/locales/data/datasources/local_datasource.dart';
import '../../features/locales/domain/entities/local.dart';
import '../../features/mercados/data/datasources/mercado_datasource.dart';
import '../../features/mercados/domain/entities/mercado.dart';
import '../../features/municipalidades/data/datasources/municipalidad_datasource.dart';
import '../../features/municipalidades/domain/entities/municipalidad.dart';
import '../../features/tipos_negocio/domain/entities/tipo_negocio.dart';
import '../../features/tipos_negocio/data/datasources/tipo_negocio_datasource.dart';
import '../../features/usuarios/data/datasources/auth_datasource.dart';
import '../../features/usuarios/domain/entities/usuario.dart';
import '../../features/cortes/data/datasources/corte_datasource.dart';
import '../../features/cortes/domain/repositories/corte_repository.dart';
import '../../features/cortes/data/repositories/corte_repository_impl.dart';
import '../../features/cortes/domain/entities/corte.dart';
import '../../features/dashboard/data/datasources/stats_datasource.dart';
import '../../core/platform/printer_persistence_datasource.dart';
import '../../features/shared/data/datasources/printer_persistence_local_datasource.dart';

import '../../features/cobros/data/datasources/cobro_local_datasource.dart';
import '../../features/locales/data/datasources/local_local_datasource.dart';
import '../../features/mercados/data/datasources/mercado_local_datasource.dart';
import '../../features/municipalidades/data/datasources/municipalidad_local_datasource.dart';

import '../../features/cobros/domain/repositories/cobro_repository.dart';
import '../../features/locales/domain/repositories/local_repository.dart';
import '../../features/mercados/domain/repositories/mercado_repository.dart';
import '../../features/municipalidades/domain/repositories/municipalidad_repository.dart';

import '../../features/cobros/data/repositories/cobro_repository_impl.dart';
import '../../features/locales/data/repositories/local_repository_impl.dart';
import '../../features/mercados/data/repositories/mercado_repository_impl.dart';
import '../../features/municipalidades/data/repositories/municipalidad_repository_impl.dart';

import '../../core/platform/navigation_config.dart';
export '../../core/platform/printer_provider.dart';
export '../../core/platform/printer_service.dart';
export '../../features/shared/presentation/viewmodels/printer_notifier.dart';

// Navigation configuration provider (overridden in entry points)
final navigationConfigProvider = Provider<NavigationConfig>((ref) {
  return DefaultNavigationConfig();
});

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

// Printer Persistence
final printerPersistenceDataSourceProvider = Provider<PrinterPersistenceDataSource>(
  (_) => PrinterPersistenceLocalDataSource(),
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

// Local Datasources (Hive)
final _connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final localLocalDatasourceProvider = Provider<LocalLocalDatasource>(
  (ref) => LocalLocalDatasource(),
);

final mercadoLocalDatasourceProvider = Provider<MercadoLocalDatasource>(
  (ref) => MercadoLocalDatasource(),
);

final municipalidadLocalDatasourceProvider =
    Provider<MunicipalidadLocalDatasource>(
      (ref) => MunicipalidadLocalDatasource(),
    );

final cobroLocalDatasourceProvider = Provider<CobroLocalDatasource>(
  (ref) => CobroLocalDatasource(),
);

// Remote Datasources (Firestore)
final municipalidadDatasourceProvider = Provider<MunicipalidadDatasource>(
  (ref) => MunicipalidadDatasource(ref.read(firestoreProvider)),
);

final mercadoDatasourceProvider = Provider<MercadoDatasource>(
  (ref) => MercadoDatasource(ref.read(firestoreProvider)),
);

final statsDatasourceProvider = Provider<StatsDatasource>(
  (ref) => StatsDatasource(ref.read(firestoreProvider)),
);

final localDatasourceProvider = Provider<LocalDatasource>(
  (ref) => LocalDatasource(
    ref.read(firestoreProvider),
    ref.read(statsDatasourceProvider),
  ),
);

final tipoNegocioDatasourceProvider = Provider<TipoNegocioDatasource>(
  (ref) => TipoNegocioDatasource(ref.read(firestoreProvider)),
);

final cobroDatasourceProvider = Provider<CobroDatasource>(
  (ref) => CobroDatasource(
    ref.read(firestoreProvider),
    ref.read(statsDatasourceProvider),
  ),
);

final corteDatasourceProvider = Provider<CorteDatasource>(
  (ref) => CorteDatasource(ref.read(firestoreProvider)),
);

// Repositories
final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepositoryImpl(
    ref.read(localDatasourceProvider),
    ref.read(localLocalDatasourceProvider),
    ref.read(_connectivityProvider),
  );
});

final mercadoRepositoryProvider = Provider<MercadoRepository>((ref) {
  return MercadoRepositoryImpl(
    ref.read(mercadoDatasourceProvider),
    ref.read(mercadoLocalDatasourceProvider),
    ref.read(_connectivityProvider),
  );
});

final municipalidadRepositoryProvider = Provider<MunicipalidadRepository>((
  ref,
) {
  return MunicipalidadRepositoryImpl(
    ref.read(municipalidadDatasourceProvider),
    ref.read(municipalidadLocalDatasourceProvider),
    ref.read(_connectivityProvider),
  );
});

final cobroRepositoryProvider = Provider<CobroRepository>((ref) {
  return CobroRepositoryImpl(
    ref.read(cobroDatasourceProvider),
    ref.read(cobroLocalDatasourceProvider),
    ref.read(_connectivityProvider),
    ref.read(localRepositoryProvider),
  );
});

final corteRepositoryProvider = Provider<CorteRepository>((ref) {
  return CorteRepositoryImpl(
    ref.read(corteDatasourceProvider),
  );
});

// Data providers (fetchers)
final municipalidadesProvider = StreamProvider<List<Municipalidad>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(municipalidadDatasourceProvider);
  if (user?.municipalidadId != null) {
    return ds.streamTodas().map(
      (all) => all.where((m) => m.id == user!.municipalidadId).toList(),
    );
  }
  return ds.streamTodas();
});

final municipalidadActualProvider = Provider<Municipalidad?>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final todasRaw = ref.watch(municipalidadesProvider).value ?? [];
  // Forzamos el cast a la interfaz base para evitar conflictos de tipos en closures (Web/JS)
  final todas = todasRaw.cast<Municipalidad>();

  if (user?.municipalidadId == null) return null;
  if (todas.isEmpty) return null;

  return todas.firstWhere(
    (m) => m.id == user!.municipalidadId,
    orElse: () => todas.first,
  );
});

final mercadosProvider = StreamProvider<List<Mercado>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final repo = ref.read(mercadoRepositoryProvider);
  if (user?.municipalidadId != null) {
    return repo.streamPorMunicipalidad(user!.municipalidadId!);
  }
  return repo.streamTodos();
});

final localesProvider = StreamProvider<List<Local>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(localDatasourceProvider);
  if (user?.municipalidadId != null) {
    return ds.streamPorMunicipalidad(user!.municipalidadId!);
  }
  return ds.streamTodos();
});

final tiposNegocioProvider = StreamProvider<List<TipoNegocio>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(tipoNegocioDatasourceProvider);
  if (user?.municipalidadId != null) {
    return ds.streamPorMunicipalidad(user!.municipalidadId!);
  }
  return ds.streamTodos();
});

final cobrosRecientesProvider = StreamProvider<List<Cobro>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  if (user == null || user.municipalidadId == null) return Stream.value([]);
  final ds = ref.read(cobroDatasourceProvider);
  return ds.streamRecientes(municipalidadId: user.municipalidadId!);
});

final statsProvider = StreamProvider<StatsModel>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  if (user == null || user.municipalidadId == null) return Stream.value(StatsModel());
  final ds = ref.read(statsDatasourceProvider);
  return ds.streamStats(user.municipalidadId!);
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

  // Si hay rango explícito, úsarlo. Si no, usar el día de hoy
  // sin .limit() para que lleguen TODOS los cobros del período.
  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day);
  final rangoEfectivo = rango ?? DateTimeRange(start: hoy, end: hoy);

  return ds.streamPorRangoFechas(
    rangoEfectivo.start,
    rangoEfectivo.end,
    municipalidadId: user?.municipalidadId,
  );
});

enum DashboardPeriod { hoy, semana, mes, anio, personalizado }

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
      case DashboardPeriod.anio:
        range = DateTimeRange(start: DateTime(today.year, 1, 1), end: today);
        label = 'Año';
        description = 'Desde el 1 de enero de ${today.year} hasta hoy';
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
  if (user == null) return Stream.value([]);

  final ds = ref.read(cobroDatasourceProvider);
  final filter = ref.watch(dashboardFilterProvider);

  if (filter.period == DashboardPeriod.hoy) {
    return ds.streamPorFecha(
      filter.range.start,
      municipalidadId: user.municipalidadId,
    );
  } else {
    // Para rangos históricos, usamos listarPorRangoFechas (atómico)
    // Stream.fromFuture convierte el Future en un Stream que emite una vez y cierra.
    return Stream.fromFuture(
      ds.listarPorRangoFechas(
        filter.range.start,
        filter.range.end,
        municipalidadId: user.municipalidadId,
      ).then((list) => list.cast<Cobro>()),
    );
  }
});

final usuariosProvider = StreamProvider<List<Usuario>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  final ds = ref.read(authDatasourceProvider);
  return ds.streamTodos(municipalidadId: user?.municipalidadId);
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

final localesCobradorProvider = StreamProvider<List<Local>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  if (user == null) return Stream.value([]);
  final ds = ref.read(localDatasourceProvider);

  // OPTIMIZACIÓN: Solo escuchar el Mercado asignado si existe.
  // Evita descargar toda la municipalidad (lecturas masivas).
  if (user.mercadoId != null) {
    return ds.streamPorMercado(user.mercadoId!).map((locales) {
      if (user.rutaAsignada != null && user.rutaAsignada!.isNotEmpty) {
        return locales.where((l) => user.rutaAsignada!.contains(l.id)).toList();
      }
      return locales;
    });
  }

  // Fallback seguro: Si no tiene mercado, pero sí municipalidad (raro para cobrador)
  if (user.municipalidadId != null) {
    // Aquí limitamos a 50 como salvaguarda si algo falla en la asignación
    return ds.streamPorMunicipalidad(user.municipalidadId!).map((l) => l.take(50).toList());
  }

  return Stream.value([]);
});

final cobrosHoyCobradorProvider = StreamProvider<List<Cobro>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  if (user == null) return Stream.value([]);
  final ds = ref.read(cobroDatasourceProvider);
  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day);

  return ds.streamPorFecha(hoy, municipalidadId: user.municipalidadId).map((
    cobros,
  ) {
    if (user.mercadoId != null) {
      return cobros.where((c) => c.mercadoId == user.mercadoId).toList();
    }
    return cobros;
  });
});

@Deprecated('Usar cortesAdminPaginadosProvider para evitar fugas de lectura')
final cortesHistorialAdminProvider = StreamProvider<List<Corte>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  if (user == null || user.municipalidadId == null) return Stream.value([]);
  final repo = ref.read(corteRepositoryProvider);
  return repo.streamPorMunicipalidad(user.municipalidadId!);
});

@Deprecated('Usar cortesCobradorPaginadosProvider para evitar fugas de lectura')
final cortesHistorialCobradorProvider = StreamProvider<List<Corte>>((ref) {
  final user = ref.watch(currentUsuarioProvider).value;
  if (user == null || user.id == null) return Stream.value([]);
  final repo = ref.read(corteRepositoryProvider);
  return repo.streamPorCobrador(user.id!);
});
