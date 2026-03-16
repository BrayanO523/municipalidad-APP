import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../constants/firestore_collections.dart';
import 'id_normalizer.dart';

class MassImportEventuales {
  static const String municipalidadId = 'MUN-choluteca';
  static const String mercadoId =
      'MER-mun-choluteca-mercado-inmaculada-concepcion-de-choluteca';
  static const String tipoNegocioId = 'TN-abarrotes';

  static const String _defaultTelefono = '00000000';
  static const String _defaultFrecuenciaCobro = 'diaria';
  static const String _scriptId = 'import_eventuales_script';
  static const String _assetPath =
      'assets/import/eventuales_completo_con_ruta.csv';

  static Future<String> ejecutar() async {
    final db = FirebaseFirestore.instance;
    const batchSize = 400;
    final data = await _cargarDataDesdeCsv();

    await _ensureCatalogsExist(db);

    WriteBatch batch = db.batch();
    int total = 0;
    int procesadosEnBatch = 0;

    for (final item in data) {
      final docData = <String, dynamic>{
        'id': item.id,
        'activo': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
        'actualizadoPor': _scriptId,
        'creadoEn': FieldValue.serverTimestamp(),
        'creadoPor': _scriptId,
        'cuotaDiaria': item.cuotaDiaria,
        'mercadoId': mercadoId,
        'municipalidadId': municipalidadId,
        'nombreSocial': 'Eventual de ${item.nombre}',
        'nombreSocialLower': 'eventual de ${item.nombre}'.toLowerCase(),
        'qrData': item.id,
        'representante': item.nombre,
        'telefonoRepresentante': _defaultTelefono,
        'tipoNegocioId': tipoNegocioId,
        'clave': '',
        'frecuenciaCobro': _defaultFrecuenciaCobro,
        'deudaAcumulada': 0,
        'saldoAFavor': 0,
        if (item.ruta != null && item.ruta!.isNotEmpty) 'ruta': item.ruta,
      };

      final ref = db.collection(FirestoreCollections.locales).doc(item.id);
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

    return '✅ Importación de eventuales completada. Total: $total eventuales creados/actualizados.';
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

  static Future<List<_CsvEventual>> _cargarDataDesdeCsv() async {
    final csv = await rootBundle.loadString(_assetPath);
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final data = <_CsvEventual>[];
    final idsVistos = <String>{};
    final ocurrenciasPorNombre = <String, int>{};

    for (int index = 1; index < lines.length; index++) {
      final fields = _parseCsvLine(lines[index]);
      if (fields.length < 3) {
        continue;
      }

      final nombre = fields[0].trim();
      final cuotaDiaria = num.tryParse(fields[1].trim());
      final ruta = fields[2].trim();

      if (nombre.isEmpty || cuotaDiaria == null) {
        continue;
      }

      final nombreNormalizado = IdNormalizer.normalize(nombre);
      final ocurrenciaActual = (ocurrenciasPorNombre[nombreNormalizado] ?? 0) + 1;
      ocurrenciasPorNombre[nombreNormalizado] = ocurrenciaActual;

      final docId =
          'LOC-$mercadoId-eventual-$nombreNormalizado-${ocurrenciaActual.toString().padLeft(2, '0')}';

      if (idsVistos.contains(docId)) {
        continue;
      }

      idsVistos.add(docId);
      data.add(
        _CsvEventual(
          id: docId,
          nombre: nombre,
          cuotaDiaria: cuotaDiaria,
          ruta: ruta.isEmpty ? null : ruta,
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

class _CsvEventual {
  final String id;
  final String nombre;
  final num cuotaDiaria;
  final String? ruta;

  const _CsvEventual({
    required this.id,
    required this.nombre,
    required this.cuotaDiaria,
    required this.ruta,
  });
}
