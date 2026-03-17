import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';
import '../../features/cobros/data/datasources/cobro_datasource.dart';
import '../../features/dashboard/data/datasources/stats_datasource.dart';
import '../../features/locales/data/datasources/local_datasource.dart';

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

  static Future<String> limpiarDatosObsoletosSistema() async {
    final db = FirebaseFirestore.instance;
    final statsDs = StatsDatasource(db);
    final ds = CobroDatasource(db, statsDs, LocalDatasource(db, statsDs));
    try {
      final total = await ds.inicializarCorrelativosSistema();
      return '✅ Limpieza de sistema completada. Total de registros afectados/limpiados: $total';
    } catch (e) {
      return '❌ Error durante la limpieza: $e';
    }
  }

  /// Vincula todos los registros (locales, cobros, usuarios) a Choluteca.
  /// Útil cuando se han importado datos con IDs incorrectos o nulos.
  static Future<String> vincularTodoACholuteca() async {
    final db = FirebaseFirestore.instance;
    final log = StringBuffer();
    const munId = 'MUN-choluteca';
    const merId = 'MER-mun-choluteca-mercado-inmaculada-concepcion-de-choluteca';

    int localesActualizados = 0;
    int usuariosActualizados = 0;
    int cobrosActualizados = 0;

    try {
      log.writeln('🚀 Iniciando vinculación masiva a Choluteca...');

      // 1. Actualizar Locales
      final localesSnap = await db.collection(FirestoreCollections.locales).get();
      WriteBatch batch = db.batch();
      int count = 0;

      for (var doc in localesSnap.docs) {
        final data = doc.data();
        final currentMun = data['municipalidadId'];
        final currentMer = data['mercadoId'];

        if (currentMun != munId || currentMer != merId) {
          batch.update(doc.reference, {
            'municipalidadId': munId,
            'mercadoId': merId,
          });
          localesActualizados++;
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
          }
        }
      }
      if (count > 0) await batch.commit();
      log.writeln('🏪 Locales vinculados: $localesActualizados');

      // 2. Actualizar Usuarios
      final usuariosSnap = await db.collection(FirestoreCollections.usuarios).get();
      batch = db.batch();
      count = 0;

      for (var doc in usuariosSnap.docs) {
        final data = doc.data();
        final currentMun = data['municipalidadId'];
        final rol = data['rol'];

        // Solo vinculamos si no tiene municipalidadId o si es cobrador/admin de esta mun
        if (currentMun != munId && (rol == 'cobrador' || rol == 'admin')) {
          batch.update(doc.reference, {
            'municipalidadId': munId,
            'mercadoId': merId, // Generalmente los cobradores están en este mercado
          });
          usuariosActualizados++;
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
          }
        }
      }
      if (count > 0) await batch.commit();
      log.writeln('👤 Usuarios vinculados: $usuariosActualizados');

      // 3. Actualizar Cobros
      final cobrosSnap = await db.collection(FirestoreCollections.cobros).get();
      batch = db.batch();
      count = 0;

      for (var doc in cobrosSnap.docs) {
        final data = doc.data();
        final currentMun = data['municipalidadId'];
        final currentMer = data['mercadoId'];

        if (currentMun != munId || currentMer != merId) {
          batch.update(doc.reference, {
            'municipalidadId': munId,
            'mercadoId': merId,
          });
          cobrosActualizados++;
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
          }
        }
      }
      if (count > 0) await batch.commit();
      log.writeln('💰 Cobros vinculados: $cobrosActualizados');

      log.writeln('\n✅ Vinculación completada con éxito.');
    } catch (e) {
      log.writeln('❌ Error durante la vinculación: $e');
    }

    return log.toString();
  }

  /// Calcula y asigna "mora" a los cobros históricos.
  /// Toma todos los cobros donde `montoMora` es nulo pero `montoAbonadoDeuda > 0`,
  /// asumiendo que el pago de deuda antigua fue mora.
  /// Luego actualiza los documentos de estadísticas globales y por mercado.
  static Future<String> migrarMoraHistorica() async {
    final db = FirebaseFirestore.instance;
    final log = StringBuffer();
    int cobrosActualizados = 0;

    try {
      log.writeln('🚀 Iniciando cálculo de Mora Histórica...');
      final cobrosSnap = await db.collection(FirestoreCollections.cobros).get();

      // Para acumular las actualizaciones de estadísticas.
      // Clave: municipalidadId o municipalidadId_mercadoId
      final Map<String, num> statsTotalMora = {};
      final Map<String, Map<String, num>> statsDiarioMora = {};

      WriteBatch batch = db.batch();
      int count = 0;

      for (var doc in cobrosSnap.docs) {
        final data = doc.data();
        final montoAbonadoDeuda = (data['montoAbonadoDeuda'] as num?) ?? 0;
        final montoMoraExistente = (data['montoMora'] as num?);

        // Si pagó deuda pero no tiene calculado el montoMora, lo recalculamos.
        if (montoMoraExistente == null && montoAbonadoDeuda > 0) {
          final munId = data['municipalidadId'] as String?;
          final merId = data['mercadoId'] as String?;
          if (munId == null) continue;

          final fechaMap = data['fecha'];
          if (fechaMap == null || fechaMap is! Timestamp) continue;

          final fechaCobro = fechaMap.toDate();
          // La mora histórica se define como cualquier pago a una deuda 
          // anterior al mes en curso del cobro
          final refMora = DateTime(fechaCobro.year, fechaCobro.month, 1);
          final dateKey = '${fechaCobro.year}-${fechaCobro.month.toString().padLeft(2, '0')}-${fechaCobro.day.toString().padLeft(2, '0')}';

          final fechasRaw = data['fechasDeudasSaldadas'] as List<dynamic>? ?? [];
          num moraCalculada = 0;

          if (fechasRaw.isNotEmpty) {
            int moraCount = 0;
            for (var r in fechasRaw) {
              final f = (r as Timestamp).toDate();
              if (f.isBefore(refMora)) {
                moraCount++;
              }
            }
            if (moraCount > 0) {
              // Asumimos cuotas equitativas para todas las deudas saldadas en el mismo recibo.
              moraCalculada = (montoAbonadoDeuda / fechasRaw.length) * moraCount;
            }
          } else {
             // Si el recibo pagó deuda pero, por un motivo histórico muy antiguo, 
             // no guardó el array de fechas, se vuelve imposible determinar si era 
             // mora vencida o deuda del mes. Podemos asumir conservadoramente mora.
             moraCalculada = montoAbonadoDeuda;
          }

          if (moraCalculada > 0) {
            batch.update(doc.reference, {'montoMora': moraCalculada});

            // Acumular para el documento de la municipalidad
            statsTotalMora[munId] = (statsTotalMora[munId] ?? 0) + moraCalculada;
            statsDiarioMora.putIfAbsent(munId, () => {});
            statsDiarioMora[munId]![dateKey] = (statsDiarioMora[munId]![dateKey] ?? 0) + moraCalculada;

            // Acumular para el documento del mercado
            if (merId != null) {
              final merStatsKey = '${munId}_$merId';
              statsTotalMora[merStatsKey] = (statsTotalMora[merStatsKey] ?? 0) + moraCalculada;
              statsDiarioMora.putIfAbsent(merStatsKey, () => {});
              statsDiarioMora[merStatsKey]![dateKey] = (statsDiarioMora[merStatsKey]![dateKey] ?? 0) + moraCalculada;
            }
          }

          cobrosActualizados++;
          count++;

          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
            log.writeln('   - Batch 400 cobros procesados...');
          }
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      log.writeln('💰 Cobros históricos actualizados: $cobrosActualizados');
      log.writeln('📊 Actualizando agregaciones en Stats...');

      // Actualizar los documentos de stats
      batch = db.batch();
      for (final statKey in statsTotalMora.keys) {
        final parts = statKey.split('_');
        final munId = parts[0];
        final merId = parts.length > 1 ? parts[1] : null;

        DocumentReference statRef;
        if (merId == null) {
          statRef = db.collection('stats_general').doc(munId);
        } else {
          statRef = db.collection('stats_general').doc(munId).collection('por_mercado').doc(merId);
        }

        final updates = <String, dynamic>{
          'totalMoraRecuperada': FieldValue.increment(statsTotalMora[statKey]!),
        };

        final diario = statsDiarioMora[statKey];
        if (diario != null) {
          diario.forEach((dateKey, moraAmount) {
            updates['diario.$dateKey.mora'] = FieldValue.increment(moraAmount);
          });
        }

        batch.update(statRef, updates);
      }

      await batch.commit();
      log.writeln('✅ Stats actualizados correctamente.');
      log.writeln('🎉 Migración completada.');

    } catch (e) {
      log.writeln('❌ Error en migración de Mora: $e');
    }

    return log.toString();
  }
}
