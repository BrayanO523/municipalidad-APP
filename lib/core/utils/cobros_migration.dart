import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';

/// Migración de datos: rellena el campo [mercadoId] en todos los cobros
/// que actualmente no lo tienen, cruzando con la colección [locales].
///
/// ⚠️ Executar UNA sola vez. Luego puede quitarse el botón que la dispara.
class CobrosMigration {
  static Future<String> rellenarMercadoId() async {
    final db = FirebaseFirestore.instance;
    final log = StringBuffer();
    int actualizados = 0;
    int sinLocal = 0;
    int omitidos = 0;

    try {
      // 1. Cargar todos los cobros que NO tienen mercadoId
      final cobrosSnapshot = await db
          .collection(FirestoreCollections.cobros)
          .where('mercadoId', isNull: true)
          .get();

      log.writeln(
        '📋 Cobros sin mercadoId encontrados: ${cobrosSnapshot.docs.length}',
      );

      if (cobrosSnapshot.docs.isEmpty) {
        log.writeln('✅ Nada que migrar, todos los cobros ya tienen mercadoId.');
        return log.toString();
      }

      // 2. Cargar todos los locales una sola vez para hacer el cruce en memoria
      final localesSnapshot = await db
          .collection(FirestoreCollections.locales)
          .get();

      // Mapa: localId -> mercadoId
      final Map<String, String?> localToMercado = {
        for (final doc in localesSnapshot.docs)
          doc.id: doc.data()['mercadoId'] as String?,
      };

      log.writeln('🏪 Locales cargados: ${localToMercado.length}');

      // 3. Batch para actualizaciones masivas (Firestore permite hasta 500 por batch)
      WriteBatch batch = db.batch();
      int batchCount = 0;
      const int maxBatch = 400; // margen de seguridad

      for (final cobroDoc in cobrosSnapshot.docs) {
        final localId = cobroDoc.data()['localId'] as String?;
        if (localId == null) {
          log.writeln('⚠️  Cobro ${cobroDoc.id} no tiene localId, omitiendo.');
          omitidos++;
          continue;
        }

        final mercadoId = localToMercado[localId];
        if (mercadoId == null) {
          log.writeln(
            '⚠️  Local $localId no encontrado o sin mercadoId, omitiendo cobro ${cobroDoc.id}.',
          );
          sinLocal++;
          continue;
        }

        batch.update(cobroDoc.reference, {'mercadoId': mercadoId});
        actualizados++;
        batchCount++;

        // Commit cuando llegamos al límite
        if (batchCount >= maxBatch) {
          await batch.commit();
          log.writeln('💾 Batch de $batchCount cobros guardado.');
          batch = db.batch();
          batchCount = 0;
        }
      }

      // Commit del batch final
      if (batchCount > 0) {
        await batch.commit();
        log.writeln('💾 Batch final de $batchCount cobros guardado.');
      }

      log.writeln('');
      log.writeln('✅ Migración completada:');
      log.writeln('   • Actualizados: $actualizados');
      log.writeln('   • Sin localId: $omitidos');
      log.writeln('   • Local no encontrado: $sinLocal');
    } catch (e) {
      log.writeln('❌ Error durante la migración: $e');
    }

    return log.toString();
  }
}
