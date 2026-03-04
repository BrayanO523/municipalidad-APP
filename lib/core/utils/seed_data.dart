import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firestore_collections.dart';

/// Siembra datos iniciales de prueba en Firestore.
/// Ejecutar UNA vez, luego eliminar la llamada.
class SeedData {
  static Future<String> ejecutar() async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final log = StringBuffer();
    final now = Timestamp.now();

    try {
      // 1. Crear usuario admin en Auth
      const email = 'admin@mercados.gob';
      const password = 'Admin123!';
      UserCredential? cred;
      try {
        cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        log.writeln('✅ Usuario Auth creado: $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cred = await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          log.writeln('ℹ️ Usuario Auth ya existía, sesión iniciada');
        } else {
          rethrow;
        }
      }

      final uid = cred.user!.uid;

      // 2. Documento de usuario en Firestore
      await db.collection(FirestoreCollections.usuarios).doc(uid).set({
        'activo': true,
        'actualizadoEn': now,
        'actualizadoPor': 'seed',
        'creadoEn': now,
        'creadoPor': 'seed',
        'email': email,
        'municipalidadId': 'MUN-villa-nueva',
        'nombre': 'Administrador General',
        'rol': 'admin',
      });
      log.writeln('✅ Documento usuario admin creado');

      // 2b. Crear usuario cobrador en Auth
      await auth.signOut();
      const cobradorEmail = 'cobrador@mercados.gob';
      const cobradorPassword = 'Cobrador123!';
      UserCredential? cobradorCred;
      try {
        cobradorCred = await auth.createUserWithEmailAndPassword(
          email: cobradorEmail,
          password: cobradorPassword,
        );
        log.writeln('✅ Usuario Auth cobrador creado: $cobradorEmail');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cobradorCred = await auth.signInWithEmailAndPassword(
            email: cobradorEmail,
            password: cobradorPassword,
          );
          log.writeln('ℹ️ Usuario cobrador ya existía');
        } else {
          rethrow;
        }
      }

      final cobradorUid = cobradorCred.user!.uid;

      await db.collection(FirestoreCollections.usuarios).doc(cobradorUid).set({
        'activo': true,
        'actualizadoEn': now,
        'actualizadoPor': 'seed',
        'creadoEn': now,
        'creadoPor': 'seed',
        'email': cobradorEmail,
        'municipalidadId': 'MUN-villa-nueva',
        'nombre': 'Juan Cobrador',
        'rol': 'cobrador',
      });
      log.writeln('✅ Documento usuario cobrador creado');

      // Re-login como admin para continuar
      await auth.signOut();
      await auth.signInWithEmailAndPassword(email: email, password: password);

      // 3. Municipalidad
      await db
          .collection(FirestoreCollections.municipalidades)
          .doc('MUN-villa-nueva')
          .set({
            'activa': true,
            'actualizadoEn': now,
            'actualizadoPor': 'seed',
            'creadoEn': now,
            'creadoPor': 'seed',
            'departamento': 'Guatemala',
            'municipio': 'Villa Nueva',
            'nombre': 'Municipalidad de Villa Nueva',
            'porcentaje': 10,
          });
      log.writeln('✅ Municipalidad creada: Villa Nueva');

      // 4. Tipo de negocio
      final tiposNegocio = {
        'TN-verduleria': {
          'nombre': 'Verdulería',
          'descripcion': 'Venta de verduras y hortalizas',
        },
        'TN-carniceria': {
          'nombre': 'Carnicería',
          'descripcion': 'Venta de carnes y embutidos',
        },
        'TN-comedor': {
          'nombre': 'Comedor',
          'descripcion': 'Venta de comida preparada',
        },
        'TN-ropa': {
          'nombre': 'Ropa y Calzado',
          'descripcion': 'Venta de prendas de vestir',
        },
        'TN-abarrotes': {
          'nombre': 'Abarrotes',
          'descripcion': 'Productos de consumo básico',
        },
      };

      for (final entry in tiposNegocio.entries) {
        await db
            .collection(FirestoreCollections.tiposNegocio)
            .doc(entry.key)
            .set({
              ...entry.value,
              'activo': true,
              'actualizadoEn': now,
              'actualizadoPor': 'seed',
              'creadoEn': now,
              'creadoPor': 'seed',
            });
      }
      log.writeln('✅ ${tiposNegocio.length} tipos de negocio creados');

      // 5. Mercado
      await db
          .collection(FirestoreCollections.mercados)
          .doc('MER-villa-nueva-central')
          .set({
            'activo': true,
            'actualizadoEn': now,
            'actualizadoPor': 'seed',
            'creadoEn': now,
            'creadoPor': 'seed',
            'municipalidadId': 'MUN-villa-nueva',
            'nombre': 'Mercado Central',
            'ubicacion': 'Zona 1, Villa Nueva',
          });
      log.writeln('✅ Mercado creado: Central');

      // 6. Locales
      final locales = [
        {
          'num': '001',
          'nombre': 'Verduras Doña María',
          'rep': 'María López',
          'tipo': 'TN-verduleria',
          'm2': 6,
          'cuota': 15,
        },
        {
          'num': '002',
          'nombre': 'Carnes Don Pedro',
          'rep': 'Pedro García',
          'tipo': 'TN-carniceria',
          'm2': 8,
          'cuota': 25,
        },
        {
          'num': '003',
          'nombre': 'Comedor La Abuela',
          'rep': 'Rosa Martínez',
          'tipo': 'TN-comedor',
          'm2': 12,
          'cuota': 30,
        },
        {
          'num': '004',
          'nombre': 'Ropa El Buen Precio',
          'rep': 'Carlos Hernández',
          'tipo': 'TN-ropa',
          'm2': 10,
          'cuota': 20,
        },
        {
          'num': '005',
          'nombre': 'Abarrotes La Esquina',
          'rep': 'Ana Ramírez',
          'tipo': 'TN-abarrotes',
          'm2': 5,
          'cuota': 12,
        },
        {
          'num': '006',
          'nombre': 'Frutas Tropicales',
          'rep': 'Luis Morales',
          'tipo': 'TN-verduleria',
          'm2': 7,
          'cuota': 18,
        },
        {
          'num': '007',
          'nombre': 'Pollo Frito Express',
          'rep': 'Sandra Velásquez',
          'tipo': 'TN-comedor',
          'm2': 9,
          'cuota': 22,
        },
        {
          'num': '008',
          'nombre': 'Tienda Don José',
          'rep': 'José Pérez',
          'tipo': 'TN-abarrotes',
          'm2': 6,
          'cuota': 15,
        },
      ];

      for (final l in locales) {
        final docId = 'LOC-MER-villa-nueva-central-${l['num']}';
        await db.collection(FirestoreCollections.locales).doc(docId).set({
          'activo': true,
          'actualizadoEn': now,
          'actualizadoPor': 'seed',
          'creadoEn': now,
          'creadoPor': 'seed',
          'cuotaDiaria': l['cuota'],
          'espacioM2': l['m2'],
          'mercadoId': 'MER-villa-nueva-central',
          'municipalidadId': 'MUN-villa-nueva',
          'nombreSocial': l['nombre'],
          'qrData': docId,
          'representante': l['rep'],
          'tipoNegocioId': l['tipo'],
        });
      }
      log.writeln('✅ ${locales.length} locales creados');

      // 7. Cobros de ejemplo
      final hoy = DateTime.now();
      final cobros = [
        {
          'local': 'LOC-MER-villa-nueva-central-001',
          'monto': 15,
          'cuota': 15,
          'saldo': 0,
          'estado': 'cobrado',
        },
        {
          'local': 'LOC-MER-villa-nueva-central-002',
          'monto': 20,
          'cuota': 25,
          'saldo': 5,
          'estado': 'abono_parcial',
        },
        {
          'local': 'LOC-MER-villa-nueva-central-003',
          'monto': 30,
          'cuota': 30,
          'saldo': 0,
          'estado': 'cobrado',
        },
        {
          'local': 'LOC-MER-villa-nueva-central-005',
          'monto': 0,
          'cuota': 12,
          'saldo': 12,
          'estado': 'pendiente',
        },
      ];

      for (var i = 0; i < cobros.length; i++) {
        final c = cobros[i];
        final fecha = Timestamp.fromDate(hoy);
        final docId =
            'COB-${c['local']}-${hoy.year}${hoy.month.toString().padLeft(2, '0')}${hoy.day.toString().padLeft(2, '0')}-$i';
        await db.collection(FirestoreCollections.cobros).doc(docId).set({
          'actualizadoEn': now,
          'actualizadoPor': 'seed',
          'cobradorId': uid,
          'creadoEn': now,
          'creadoPor': 'seed',
          'cuotaDiaria': c['cuota'],
          'estado': c['estado'],
          'fecha': fecha,
          'localId': c['local'],
          'mercadoId': 'MER-villa-nueva-central',
          'monto': c['monto'],
          'observaciones': 'Dato de prueba',
          'saldoPendiente': c['saldo'],
        });
      }
      log.writeln('✅ ${cobros.length} cobros de ejemplo creados');
      log.writeln('');
      log.writeln('🔑 Admin: admin@mercados.gob / Admin123!');
      log.writeln('🔑 Cobrador: cobrador@mercados.gob / Cobrador123!');
    } catch (e) {
      log.writeln('❌ Error: $e');
    }

    return log.toString();
  }
}
