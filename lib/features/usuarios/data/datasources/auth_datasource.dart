import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<UsuarioJson?> obtenerUsuario(String uid) async {
    final doc = await _firestore
        .collection(FirestoreCollections.usuarios)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UsuarioJson.fromJson(doc.data()!, docId: doc.id);
  }
}
