import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../constants/firestore_collections.dart';
import 'id_normalizer.dart';

class MassImportFaltantesLocalesInmaculada {
  static const String mercadoId =
      'MER-mun-choluteca-mercado-inmaculada-concepcion-de-choluteca';
  static const String municipalidadId = 'MUN-choluteca';

  static const String _defaultTelefono = '00000000';
  static const String _defaultTipoNegocioId = 'TN-abarrotes';
  static const String _defaultFrecuenciaCobro = 'diaria';
  static const String _scriptId = 'import_faltantes_script';
  static const String _assetPath =
      'assets/import/faltantes_inmaculada_001_019_333.csv';

  /// Importa SOLO los locales faltantes (hojas 001/019/333) que:
  /// - Tienen clave conocida (docId basado en `clave`)
  /// - Fueron omitidos manualmente los casos especiales (codigo 335 y 616)
  ///
  /// Seguridad:
  /// - Si el docId ya existe -> se salta
  /// - Si ya existe otro doc con el mismo `codigo` dentro del mercado -> se salta
  static Future<String> ejecutar() async {
    final db = FirebaseFirestore.instance;
    const batchSize = 400;
    final localesCol = db.collection(FirestoreCollections.locales);

    final data = await _cargarDataDesdeCsv();

    int creados = 0;
    int saltadosPorId = 0;
    int saltadosPorCodigo = 0;
    int errores = 0;

    // Precargar existentes del mercado para no depender de indices compuestos.
    final existentesSnap =
        await localesCol.where('mercadoId', isEqualTo: mercadoId).get();
    final existentesIds = existentesSnap.docs.map((d) => d.id).toSet();
    final existentesCodigosLower = <String>{};
    for (final d in existentesSnap.docs) {
      final v = d.data()['codigo'];
      if (v == null) continue;
      final s = v.toString().trim().toLowerCase();
      if (s.isEmpty) continue;
      existentesCodigosLower.add(s);
    }

    WriteBatch batch = db.batch();
    int inBatch = 0;

    for (final item in data) {
      final codigo = item.codigo;
      final clave = item.clave;
      final representante = item.representante;
      final cuotaDiaria = item.cuotaDiaria;

      final docId = IdNormalizer.localId(mercadoId, clave);
      final ref = localesCol.doc(docId);

      try {
        if (existentesIds.contains(docId)) {
          saltadosPorId++;
          continue;
        }

        final codigoLower = codigo.trim().toLowerCase();
        if (existentesCodigosLower.contains(codigoLower)) {
          saltadosPorCodigo++;
          continue;
        }

        final nombreSocial = 'Local de $representante';
        final data = <String, dynamic>{
          'id': docId,
          'activo': true,
          'actualizadoEn': FieldValue.serverTimestamp(),
          'actualizadoPor': _scriptId,
          'creadoEn': FieldValue.serverTimestamp(),
          'creadoPor': _scriptId,
          'cuotaDiaria': cuotaDiaria,
          'mercadoId': mercadoId,
          'municipalidadId': municipalidadId,
          'nombreSocial': nombreSocial,
          'nombreSocialLower': nombreSocial.toLowerCase(),
          'qrData': docId,
          'representante': representante,
          'telefonoRepresentante': _defaultTelefono,
          'tipoNegocioId': _defaultTipoNegocioId,
          'clave': clave,
          'codigo': codigo,
          'codigoLower': codigoLower,
          'frecuenciaCobro': _defaultFrecuenciaCobro,
          'deudaAcumulada': 0,
          'saldoAFavor': 0,
        };

        batch.set(ref, data);
        inBatch++;
        creados++;
        existentesIds.add(docId);
        existentesCodigosLower.add(codigoLower);

        if (inBatch >= batchSize) {
          await batch.commit();
          batch = db.batch();
          inBatch = 0;
        }
      } catch (_) {
        errores++;
      }
    }

    if (inBatch > 0) {
      try {
        await batch.commit();
      } catch (_) {
        // Consideramos el lote como error global.
        errores += inBatch;
      }
    }

    return 'Import faltantes: creados=$creados, skip_id=$saltadosPorId, skip_codigo=$saltadosPorCodigo, errores=$errores';
  }

  /// Revertir importación:
  /// - Lee el mismo CSV usado para importar
  /// - Calcula docId por `clave`
  /// - Solo elimina si el doc:
  ///   - existe
  ///   - pertenece al mercado objetivo
  ///   - fue creado por este script (`creadoPor == _scriptId`)
  ///   - no tiene movimientos (deuda/saldo en 0)
  ///
  /// No intenta borrar cobros relacionados; si un local ya tuvo cobros/modificaciones,
  /// se deja intacto por seguridad.
  static Future<String> revertir() async {
    final db = FirebaseFirestore.instance;
    const batchSize = 400;
    final localesCol = db.collection(FirestoreCollections.locales);

    final data = await _cargarDataDesdeCsv();

    int eliminados = 0;
    int noExistia = 0;
    int noEraDelScript = 0;
    int conMovimiento = 0;
    int errores = 0;

    WriteBatch batch = db.batch();
    int inBatch = 0;

    for (final item in data) {
      final docId = IdNormalizer.localId(mercadoId, item.clave);
      final ref = localesCol.doc(docId);

      try {
        final snap = await ref.get();
        if (!snap.exists) {
          noExistia++;
          continue;
        }

        final m = snap.data();
        if (m == null) {
          errores++;
          continue;
        }

        if ((m['mercadoId'] ?? '').toString() != mercadoId) {
          // Documento con id igual pero otro mercado (muy raro).
          noEraDelScript++;
          continue;
        }

        if ((m['creadoPor'] ?? '').toString() != _scriptId) {
          noEraDelScript++;
          continue;
        }

        final deuda = num.tryParse((m['deudaAcumulada'] ?? 0).toString()) ?? 0;
        final saldo = num.tryParse((m['saldoAFavor'] ?? 0).toString()) ?? 0;
        if (deuda != 0 || saldo != 0) {
          conMovimiento++;
          continue;
        }

        batch.delete(ref);
        inBatch++;
        eliminados++;

        if (inBatch >= batchSize) {
          await batch.commit();
          batch = db.batch();
          inBatch = 0;
        }
      } catch (_) {
        errores++;
      }
    }

    if (inBatch > 0) {
      try {
        await batch.commit();
      } catch (_) {
        errores += inBatch;
      }
    }

    return 'Revert faltantes: eliminados=$eliminados, no_existia=$noExistia, no_script=$noEraDelScript, con_movimiento=$conMovimiento, errores=$errores';
  }

  static Future<List<_LocalFaltante>> _cargarDataDesdeCsv() async {
    final csv = await rootBundle.loadString(_assetPath);
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final out = <_LocalFaltante>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == 0) continue; // header

      final fields = _parseCsvQuotedLine(line);
      if (fields.length < 5) continue;

      final codigo = fields[1].trim();
      final clave = fields[2].trim();
      final representante = fields[3].trim();
      final cuota = num.tryParse(fields[4].trim());
      if (codigo.isEmpty || clave.isEmpty || representante.isEmpty) continue;
      if (cuota == null) continue;

      out.add(
        _LocalFaltante(
          codigo: codigo,
          clave: clave,
          representante: representante,
          cuotaDiaria: cuota,
        ),
      );
    }
    return out;
  }

  static List<String> _parseCsvQuotedLine(String line) {
    final matches = RegExp(r'\"((?:[^\"]|\"\")*)\"').allMatches(line);
    return matches
        .map((m) => (m.group(1) ?? '').replaceAll('""', '"'))
        .toList(growable: false);
  }
}

class _LocalFaltante {
  final String codigo;
  final String clave;
  final String representante;
  final num cuotaDiaria;

  const _LocalFaltante({
    required this.codigo,
    required this.clave,
    required this.representante,
    required this.cuotaDiaria,
  });
}
