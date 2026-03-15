import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../domain/entities/gestion.dart';

class IncidenciaUI {
  final Gestion gestion;
  final String localNombre;
  final String localClave;
  final String localCodigo;
  final String cobradorNombre;

  IncidenciaUI({
    required this.gestion,
    required this.localNombre,
    required this.localClave,
    required this.localCodigo,
    required this.cobradorNombre,
  });
}

class IncidenciasAdminNotifier extends AsyncNotifier<List<IncidenciaUI>> {
  List<IncidenciaUI> _incidenciasOriginales = [];

  @override
  FutureOr<List<IncidenciaUI>> build() async {
    return _fetchData();
  }

  Future<List<IncidenciaUI>> _fetchData() async {
    final muniData = ref.read(currentUsuarioProvider).value;
    if (muniData?.municipalidadId == null) {
      return [];
    }

    final ds = ref.read(gestionDatasourceProvider);
    final list = await ds.listarTodas(muniData!.municipalidadId!);

    final localesDs = ref.read(localDatasourceProvider);
    final userDs = ref.read(authDatasourceProvider);

    final localesFuture = localesDs.listarTodos();
    final usersFuture = userDs.listarTodos(
      municipalidadId: muniData.municipalidadId,
    );

    final res = await Future.wait([localesFuture, usersFuture]);
    final locales = res[0] as List<dynamic>;
    final usuarios = res[1] as List<dynamic>;

    final Map<String, dynamic> localCache = {};
    final Map<String, String> userCache = {};

    for (var l in locales) {
      localCache[l.id] = {
        'nombre': l.nombreSocial ?? 'Sin nombre',
        'clave': l.clave ?? '-',
        'codigo': l.codigoCatastral ?? '-',
      };
    }

    for (var u in usuarios) {
      userCache[u.id] = u.nombre ?? 'Usuario Desconocido';
    }

    final List<IncidenciaUI> mapeadas = [];
    for (var g in list) {
      final loc =
          localCache[g.localId] ??
          {'nombre': 'Local desconocido', 'clave': '-', 'codigo': '-'};
      final cobr = userCache[g.cobradorId] ?? 'Cobrador desconocido';

      mapeadas.add(
        IncidenciaUI(
          gestion: g,
          localNombre: loc['nombre'] as String,
          localClave: loc['clave'] as String,
          localCodigo: loc['codigo'] as String,
          cobradorNombre: cobr,
        ),
      );
    }

    _incidenciasOriginales = mapeadas;
    _incidenciasOriginales.sort((a, b) {
      final d1 = b.gestion.timestamp ?? DateTime(2000);
      final d2 = a.gestion.timestamp ?? DateTime(2000);
      return d1.compareTo(d2);
    });

    return _incidenciasOriginales;
  }

  Future<void> cargarIncidencias() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }

  void filtrarPorFecha(DateTime fecha) {
    if (_incidenciasOriginales.isEmpty) return;

    final filtradas = _incidenciasOriginales.where((g) {
      final f = g.gestion.timestamp;
      if (f == null) return false;
      return f.year == fecha.year &&
          f.month == fecha.month &&
          f.day == fecha.day;
    }).toList();

    state = AsyncValue.data(filtradas);
  }
}

final incidenciasAdminProvider =
    AsyncNotifierProvider<IncidenciasAdminNotifier, List<IncidenciaUI>>(() {
      return IncidenciasAdminNotifier();
    });
