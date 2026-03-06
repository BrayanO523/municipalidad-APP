import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';

/// Siembra datos iniciales de prueba en Firestore.
/// Ejecutar UNA vez, luego eliminar la llamada.
class SeedData {
  static Future<String> ejecutar() async {
    final db = FirebaseFirestore.instance;
    final log = StringBuffer();
    final now = Timestamp.now();

    try {
      log.writeln('--- INICIANDO CARGA DE COBROS REALISTAS ---');

      // 1. Limpiar cobros existentes
      final cobrosOld = await db.collection(FirestoreCollections.cobros).get();
      for (var doc in cobrosOld.docs) {
        await doc.reference.delete();
      }
      log.writeln('✅ Cobros antiguos eliminados (${cobrosOld.docs.length})');

      // 2. Obtener locales existentes
      final localesSnapshot = await db
          .collection(FirestoreCollections.locales)
          .get();
      if (localesSnapshot.docs.isEmpty) {
        return '❌ Error: No hay locales en la base de datos. Ejecuta el seed completo primero o crea locales manualmente.';
      }

      final hoy = DateTime.now();
      int cobrosCreados = 0;

      for (var localDoc in localesSnapshot.docs) {
        final localId = localDoc.id;
        final data = localDoc.data();
        final nombre = data['nombreSocial'] ?? 'Sin nombre';
        final cuota = (data['cuotaDiaria'] ?? 22).toDouble();

        log.writeln('Procesando: $nombre...');

        num deudaTotal = 0;

        // Generar 14 días de historial
        for (int i = 0; i < 14; i++) {
          final fecha = hoy.subtract(Duration(days: i));
          final fechaStr =
              '${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';
          final docId = 'COB-$localId-$fechaStr';

          String estado = 'cobrado';
          num montoPagado = cuota;
          num saldoPendiente = 0;

          // Lógica específica para Pollo Frito Express (7 días de deuda)
          if (nombre.contains('Pollo Frito Express')) {
            if (i < 7) {
              // Los últimos 7 días (0-6)
              estado = 'pendiente';
              montoPagado = 0;
              saldoPendiente = cuota;
              deudaTotal += cuota;
            }
          }
          // Lógica aleatoria para otros locales para dar variedad
          else {
            if (i % 5 == 0) {
              // Un día de deuda cada 5 días
              estado = 'pendiente';
              montoPagado = 0;
              saldoPendiente = cuota;
              deudaTotal += cuota;
            } else if (i == 1 && nombre.length % 2 == 0) {
              // Algunos con abono parcial ayer
              estado = 'abono_parcial';
              montoPagado = (cuota / 2).round();
              saldoPendiente = cuota - montoPagado;
              deudaTotal += saldoPendiente;
            }
          }

          await db.collection(FirestoreCollections.cobros).doc(docId).set({
            'actualizadoEn': now,
            'actualizadoPor': 'seed_fix',
            'cobradorId': 'seed',
            'creadoEn': now,
            'creadoPor': 'seed_fix',
            'cuotaDiaria': cuota,
            'estado': estado,
            'fecha': Timestamp.fromDate(fecha),
            'localId': localId,
            'mercadoId': data['mercadoId'] ?? 'MER-villa-nueva-central',
            'monto': montoPagado,
            'observaciones': 'Historial generado por script de sincronización',
            'saldoPendiente': saldoPendiente,
            'telefonoRepresentante':
                '9${(1000000 + localId.hashCode % 100000).toString().padLeft(7, '0')}',
          });
          cobrosCreados++;
        }

        // Actualizar el local con la deuda calculada
        await db.collection(FirestoreCollections.locales).doc(localId).update({
          'deudaAcumulada': deudaTotal,
          'saldoAFavor': 0, // Reiniciar saldo a favor para este local
          'telefonoRepresentante':
              '9${(1000000 + localId.hashCode % 100000).toString().padLeft(7, '0')}',
        });

        log.writeln('  -> L$deudaTotal de deuda generada.');
      }

      log.writeln('\n✅ SEED FINALIZADO');
      log.writeln('🚀 Cobros creados: $cobrosCreados');
      log.writeln('📊 Locales sincronizados: ${localesSnapshot.docs.length}');
    } catch (e) {
      log.writeln('❌ Error crítico: $e');
    }

    return log.toString();
  }
}
