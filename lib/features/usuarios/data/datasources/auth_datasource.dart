import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart' as hive;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../models/usuario_model.dart';

class AuthDatasource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthDatasource(this._auth, this._firestore);

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<void> logout() async {
    // Limpiar caché local al cerrar sesión para aislar datos entre usuarios
    try {
      final boxLocales = await hive.Hive.openBox('localesBox');
      await boxLocales.clear();
      final boxCobros = await hive.Hive.openBox('cobrosBox');
      await boxCobros.clear();

      // Limpiar persistencia offline de Firestore
      await _firestore.clearPersistence();
    } catch (_) {}

    await _auth.signOut();
  }

  /// Crea un usuario (cobrador) sin cerrar la sesión actual del administrador.
  /// Esto se logra instanciando una app secundaria de Firebase.
  Future<void> registrarCobrador({
    required String email,
    required String password,
    required String nombre,
    required String municipalidadId,
    String? mercadoId,
    List<String>? rutaAsignada,
    String? codigoCobrador,
  }) async {
    // 1. Inicializar una app de Firebase temporal
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      // 2. Crear usuario usando la auth de la app temporal
      final FirebaseAuth authTemp = FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await authTemp.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Autogenerar código si viene vacío
      String? finalCodigo = codigoCobrador;
      if (finalCodigo == null || finalCodigo.trim().isEmpty) {
        finalCodigo = await sugerirSiguienteCodigoCobrador(municipalidadId);
      }

      // 3. Crear el documento en Firestore
      final nuevoUsuario = UsuarioJson(
        id: uid,
        email: email,
        nombre: nombre,
        rol: 'cobrador',
        municipalidadId: municipalidadId,
        mercadoId: mercadoId,
        rutaAsignada: rutaAsignada,
        codigoCobrador: finalCodigo,
        activo: true,
        creadoEn: DateTime.now(),
        creadoPor: currentFirebaseUser?.uid,
        actualizadoEn: DateTime.now(),
        actualizadoPor: currentFirebaseUser?.uid,
      );

      await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(uid)
          .set(nuevoUsuario.toJson());
    } finally {
      // 4. Destruir la app temporal
      await tempApp.delete();
    }
  }

  /// [DEV] Crea un usuario administrador sin cerrar sesión del admin actual.
  /// Usa el mismo patrón de app secundaria de Firebase.
  Future<void> registrarAdmin({
    required String email,
    required String password,
    required String nombre,
    required String municipalidadId,
    String? mercadoId,
  }) async {
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'AdminApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final FirebaseAuth authTemp = FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await authTemp.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      final nuevoAdmin = UsuarioJson(
        id: uid,
        email: email,
        nombre: nombre,
        rol: 'admin',
        municipalidadId: municipalidadId,
        mercadoId: mercadoId,
        activo: true,
        creadoEn: DateTime.now(),
        creadoPor: currentFirebaseUser?.uid,
        actualizadoEn: DateTime.now(),
        actualizadoPor: currentFirebaseUser?.uid,
      );

      await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(uid)
          .set(nuevoAdmin.toJson());
    } finally {
      await tempApp.delete();
    }
  }

  Future<void> actualizarRutaUsuario(String uid, List<String> rutaIds) async {
    await _firestore.collection(FirestoreCollections.usuarios).doc(uid).update({
      'rutaAsignada': rutaIds,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarUsuario(String uid, Map<String, dynamic> data) async {
    await _firestore.collection(FirestoreCollections.usuarios).doc(uid).update({
      ...data,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'actualizadoPor': currentFirebaseUser?.uid,
    });
  }

  Future<UsuarioJson?> obtenerUsuario(String uid) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    final source = isOffline ? Source.cache : Source.serverAndCache;

    try {
      final doc = await _firestore
          .collection(FirestoreCollections.usuarios)
          .doc(uid)
          .get(GetOptions(source: source));
      if (!doc.exists) return null;
      final usuario = UsuarioJson.fromJson(doc.data()!, docId: doc.id);

      // Sincronizar campos críticos para modo Offline
      if (usuario.esCobrador) {
        final prefs = await SharedPreferences.getInstance();
        if (usuario.codigoCobrador != null) {
          await prefs.setString('prefijo_${usuario.id}', usuario.codigoCobrador!);
        }
        if (usuario.ultimoCorrelativo != null) {
          final int anio = usuario.anioCorrelativo ?? DateTime.now().year;
          await prefs.setInt('correlativo_${usuario.id}_$anio', usuario.ultimoCorrelativo!);
        }
      }

      return usuario;
    } catch (e) {
      // Si falla desde cache o server, intentar fallback seguro
      if (!isOffline) {
        final docCache = await _firestore
            .collection(FirestoreCollections.usuarios)
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        if (docCache.exists) {
          return UsuarioJson.fromJson(docCache.data()!, docId: docCache.id);
        }
      }
      return null;
    }
  }

  Future<List<UsuarioJson>> listarTodos({String? municipalidadId}) async {
    Query query = _firestore.collection(FirestoreCollections.usuarios);

    if (municipalidadId != null && municipalidadId.isNotEmpty) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) => UsuarioJson.fromJson(
            doc.data() as Map<String, dynamic>,
            docId: doc.id,
          ),
        )
        .toList();
  }

  Stream<List<UsuarioJson>> streamTodos({String? municipalidadId}) {
    Query query = _firestore.collection(FirestoreCollections.usuarios);

    if (municipalidadId != null && municipalidadId.isNotEmpty) {
      query = query.where('municipalidadId', isEqualTo: municipalidadId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => UsuarioJson.fromJson(
              doc.data() as Map<String, dynamic>,
              docId: doc.id,
            ),
          )
          .toList();
    });
  }

  Future<void> eliminarUsuario(String uid) async {
    // Nota: Esto elimina el documento de Firestore.
    // Para eliminar completamente de Firebase Auth, se requiere usar Admin SDK en Cloud Functions.
    await _firestore.collection(FirestoreCollections.usuarios).doc(uid).delete();
  }

  Future<String> sugerirSiguienteCodigoCobrador(String municipalidadId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.usuarios)
        .where('municipalidadId', isEqualTo: municipalidadId)
        .where('rol', isEqualTo: 'cobrador')
        .get();

    int maxNum = 0;
    final regex = RegExp(r'^C(\d+)$', caseSensitive: false);

    for (var doc in snapshot.docs) {
      final codigo = doc.data()['codigoCobrador'] as String?;
      if (codigo != null) {
        final match = regex.firstMatch(codigo);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxNum) {
            maxNum = num;
          }
        }
      }
    }

    return 'C${maxNum + 1}';
  }
}
