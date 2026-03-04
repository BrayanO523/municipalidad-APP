import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final ds = ref.read(municipalidadDatasourceProvider);
  return ds.listarTodas();
});

final mercadosProvider = FutureProvider<List<Mercado>>((ref) async {
  final ds = ref.read(mercadoDatasourceProvider);
  return ds.listarTodos();
});

final localesProvider = FutureProvider<List<Local>>((ref) async {
  final ds = ref.read(localDatasourceProvider);
  return ds.listarTodos();
});

final tiposNegocioProvider = FutureProvider<List<TipoNegocio>>((ref) async {
  final ds = ref.read(tipoNegocioDatasourceProvider);
  return ds.listarTodos();
});

final cobrosRecientesProvider = FutureProvider<List<Cobro>>((ref) async {
  final ds = ref.read(cobroDatasourceProvider);
  return ds.listarRecientes();
});

final cobrosHoyProvider = FutureProvider<List<Cobro>>((ref) async {
  final ds = ref.read(cobroDatasourceProvider);
  return ds.listarPorFecha(DateTime.now());
});
