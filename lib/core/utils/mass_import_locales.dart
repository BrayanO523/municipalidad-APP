import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../constants/firestore_collections.dart';
import 'id_normalizer.dart';

class MassImportLocales {
  static const String municipalidadId = 'MUN-choluteca';
  static const String mercadoId =
      'MER-mun-choluteca-mercado-inmaculada-concepcion-de-choluteca';
  static const String tipoNegocioId = 'TN-abarrotes';

  static const String _defaultTelefono = '00000000';
  static const String _defaultFrecuenciaCobro = 'diaria';
  static const String _scriptId = 'import_script';
  static const String _assetPath =
      'assets/import/locales_con_codigo_con_clave_y_ruta.csv';

  static Future<String> ejecutar() async {
    final db = FirebaseFirestore.instance;
    const batchSize = 400;
    final data = await _cargarDataDesdeCsv();

    await _ensureCatalogsExist(db);

    WriteBatch batch = db.batch();
    int total = 0;
    int procesadosEnBatch = 0;

    for (final item in data) {
      final docId = IdNormalizer.localId(mercadoId, item.clave);
      final nombreSocial = 'Local de ${item.nombre}';
      final codigo = item.codigo.trim();

      final docData = <String, dynamic>{
        'id': docId,
        'activo': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
        'actualizadoPor': _scriptId,
        'creadoEn': FieldValue.serverTimestamp(),
        'creadoPor': _scriptId,
        'cuotaDiaria': item.cuotaDiaria,
        'mercadoId': mercadoId,
        'municipalidadId': municipalidadId,
        'nombreSocial': nombreSocial,
        'nombreSocialLower': nombreSocial.toLowerCase(),
        'qrData': docId,
        'representante': item.nombre,
        'telefonoRepresentante': _defaultTelefono,
        'tipoNegocioId': tipoNegocioId,
        'clave': item.clave,
        'codigo': codigo,
        'codigoLower': codigo.toLowerCase(),
        'ruta': item.ruta,
        'frecuenciaCobro': _defaultFrecuenciaCobro,
        'deudaAcumulada': 0,
        'saldoAFavor': 0,
      };

      final ref = db.collection(FirestoreCollections.locales).doc(docId);
      batch.set(ref, docData);
      total++;
      procesadosEnBatch++;

      if (procesadosEnBatch >= batchSize) {
        await batch.commit();
        batch = db.batch();
        procesadosEnBatch = 0;
      }
    }

    if (procesadosEnBatch > 0) {
      await batch.commit();
    }

    return '✅ Importación masiva completada exitosamente. Total: $total locales creados/actualizados.';
  }

  static Future<String> recrearDesdeCsv() async {
    final db = FirebaseFirestore.instance;
    const batchSize = 400;
    final localesRef = db.collection(FirestoreCollections.locales);

    int eliminados = 0;
    WriteBatch batch = db.batch();
    int procesadosEnBatch = 0;

    final existentes =
        await localesRef.where('mercadoId', isEqualTo: mercadoId).get();

    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
      eliminados++;
      procesadosEnBatch++;

      if (procesadosEnBatch >= batchSize) {
        await batch.commit();
        batch = db.batch();
        procesadosEnBatch = 0;
      }
    }

    if (procesadosEnBatch > 0) {
      await batch.commit();
    }

    final resultadoImportacion = await ejecutar();
    return '✅ Recreación completada. Eliminados: $eliminados. $resultadoImportacion';
  }

  static Future<void> _ensureCatalogsExist(FirebaseFirestore db) async {
    final munRef = db
        .collection(FirestoreCollections.municipalidades)
        .doc(municipalidadId);
    final munDoc = await munRef.get();
    if (!munDoc.exists) {
      await munRef.set({
        'nombre': 'Choluteca',
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
        'creadoPor': _scriptId,
        'actualizadoEn': FieldValue.serverTimestamp(),
        'actualizadoPor': _scriptId,
      });
    }

    final merRef =
        db.collection(FirestoreCollections.mercados).doc(mercadoId);
    final merDoc = await merRef.get();
    if (!merDoc.exists) {
      await merRef.set({
        'nombre': 'Mercado Inmaculada Concepcion de Choluteca',
        'nombreLower': 'mercado inmaculada concepcion de choluteca',
        'municipalidadId': municipalidadId,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
        'creadoPor': _scriptId,
        'actualizadoEn': FieldValue.serverTimestamp(),
        'actualizadoPor': _scriptId,
        'ubicacion': 'Choluteca, Choluteca',
      });
    }

    final tipoRef =
        db.collection(FirestoreCollections.tiposNegocio).doc(tipoNegocioId);
    final tipoDoc = await tipoRef.get();
    if (!tipoDoc.exists) {
      await tipoRef.set({
        'nombre': 'Abarrotes',
        'descripcion': 'Tipo por defecto para importación masiva',
        'municipalidadId': municipalidadId,
        'activo': true,
        'creadoEn': FieldValue.serverTimestamp(),
        'creadoPor': _scriptId,
        'actualizadoEn': FieldValue.serverTimestamp(),
        'actualizadoPor': _scriptId,
      });
    }
  }

  static Future<List<_CsvLocal>> _cargarDataDesdeCsv() async {
    final csv = await rootBundle.loadString(_assetPath);
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final data = <_CsvLocal>[];
    final idsVistos = <String>{};

    for (int index = 1; index < lines.length; index++) {
      final fields = _parseCsvLine(lines[index]);
      if (fields.length < 5) {
        continue;
      }

      final codigo = fields[0].trim();
      final nombre = fields[1].trim();
      final cuotaDiaria = num.tryParse(fields[2].trim());
      final clave = fields[3].trim();
      final ruta = fields[4].trim();

      if (codigo.isEmpty ||
          nombre.isEmpty ||
          clave.isEmpty ||
          ruta.isEmpty ||
          cuotaDiaria == null) {
        continue;
      }

      final docId = IdNormalizer.localId(mercadoId, clave);
      if (idsVistos.contains(docId)) {
        continue;
      }

      idsVistos.add(docId);
      data.add(
        _CsvLocal(
          codigo: codigo,
          nombre: nombre,
          cuotaDiaria: cuotaDiaria,
          clave: clave,
          ruta: ruta,
        ),
      );
    }

    return data;
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int index = 0; index < line.length; index++) {
      final char = line[index];

      if (char == '"') {
        final nextIsQuote =
            insideQuotes && index + 1 < line.length && line[index + 1] == '"';
        if (nextIsQuote) {
          buffer.write('"');
          index++;
        } else {
          insideQuotes = !insideQuotes;
        }
        continue;
      }

      if (char == ',' && !insideQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    fields.add(buffer.toString());
    return fields;
  }
}

class _CsvLocal {
  final String codigo;
  final String nombre;
  final num cuotaDiaria;
  final String clave;
  final String ruta;

  const _CsvLocal({
    required this.codigo,
    required this.nombre,
    required this.cuotaDiaria,
    required this.clave,
    required this.ruta,
  });
}
