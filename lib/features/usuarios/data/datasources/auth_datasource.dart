import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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

      // 3. Crear el documento en Firestore
      final nuevoUsuario = UsuarioJson(
        id: uid,
        email: email,
        nombre: nombre,
        rol: 'cobrador',
        municipalidadId: municipalidadId,
        mercadoId: mercadoId,
        rutaAsignada: rutaAsignada,
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
    final doc = await _firestore
        .collection(FirestoreCollections.usuarios)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UsuarioJson.fromJson(doc.data()!, docId: doc.id);
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
}
