import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../constants/firestore_collections.dart';

class MassMergeLocalesFromCsv {
  static const String _assetPath = 'assets/import/locales_20260316.csv';

  /// Importa/actualiza locales por docId usando `merge:true` para no borrar campos
  /// que no existan en el CSV (ej: `codigoLower`, `qrData`, etc.).
  ///
  /// Nota: Los campos vacíos en CSV se omiten (no limpian valores existentes).
  static Future<String> ejecutar() async {
    final csv = await rootBundle.loadString(_assetPath);
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return 'CSV vacío';
    final header = _parseCsvLine(lines.first);

    int idx(String name) => header.indexOf(name);
    final iId = idx('id');
    final iNombre = idx('nombreSocial');
    final iNombreLower = idx('nombreSocialLower');
    final iRep = idx('representante');
    final iTel = idx('telefonoRepresentante');
    final iMercado = idx('mercadoId');
    final iMun = idx('municipalidadId');
    final iCodigo = idx('codigo');
    final iCodigoLower = idx('codigoLower');
    final iClave = idx('clave');
    final iCat = idx('codigoCatastral');
    final iTipo = idx('tipoNegocioId');
    final iCuota = idx('cuotaDiaria');
    final iDeuda = idx('deudaAcumulada');
    final iSaldo = idx('saldoAFavor');
    final iFreq = idx('frecuenciaCobro');
    final iActivo = idx('activo');
    final iEspacio = idx('espacioM2');
    final iLat = idx('latitud');
    final iLng = idx('longitud');
    final iCreado = idx('creadoEn');
    final iAct = idx('actualizadoEn');
    final iPerimetro = idx('perimetro');

    if (iId == -1) return 'CSV inválido: falta columna id';

    final db = FirebaseFirestore.instance;
    final col = db.collection(FirestoreCollections.locales);

    int procesados = 0;
    int errores = 0;
    const batchSize = 400;
    WriteBatch batch = db.batch();
    int inBatch = 0;

    for (int li = 1; li < lines.length; li++) {
      final fields = _parseCsvLine(lines[li]);
      if (fields.length <= iId) continue;

      final docId = fields[iId].trim();
      if (docId.isEmpty) continue;

      String? getStr(int i) {
        if (i < 0 || i >= fields.length) return null;
        final v = fields[i].trim();
        return v.isEmpty ? null : v;
      }

      num? getNum(int i) {
        final s = getStr(i);
        if (s == null) return null;
        return num.tryParse(s);
      }

      bool? getBool(int i) {
        final s = getStr(i);
        if (s == null) return null;
        final v = s.toLowerCase();
        if (v == 'true') return true;
        if (v == 'false') return false;
        return null;
      }

      Timestamp? getTs(int i) {
        final s = getStr(i);
        if (s == null) return null;
        final dt = DateTime.tryParse(s);
        if (dt == null) return null;
        return Timestamp.fromDate(dt);
      }

      final data = <String, dynamic>{
        // Mantener el id en el doc (ya existe en tu BD exportada)
        'id': docId,
      };

      final nombre = getStr(iNombre);
      final representante = getStr(iRep);
      final codigo = getStr(iCodigo);

      void putIfNotNull(String key, Object? value) {
        if (value == null) return;
        data[key] = value;
      }

      putIfNotNull('nombreSocial', nombre);
      putIfNotNull('representante', representante);
      putIfNotNull('telefonoRepresentante', getStr(iTel));
      putIfNotNull('mercadoId', getStr(iMercado));
      putIfNotNull('municipalidadId', getStr(iMun));
      putIfNotNull('codigo', codigo);
      putIfNotNull('clave', getStr(iClave));
      putIfNotNull('codigoCatastral', getStr(iCat));
      putIfNotNull('tipoNegocioId', getStr(iTipo));
      putIfNotNull('cuotaDiaria', getNum(iCuota));
      putIfNotNull('deudaAcumulada', getNum(iDeuda));
      putIfNotNull('saldoAFavor', getNum(iSaldo));
      putIfNotNull('frecuenciaCobro', getStr(iFreq));
      putIfNotNull('activo', getBool(iActivo));
      putIfNotNull('espacioM2', getNum(iEspacio));

      final creadoEn = getTs(iCreado);
      final actualizadoEn = getTs(iAct);
      putIfNotNull('creadoEn', creadoEn);
      putIfNotNull('actualizadoEn', actualizadoEn);

      // Ubicación (si viene).
      final lat = getNum(iLat);
      final lng = getNum(iLng);
      if (lat != null && lng != null) {
        data['ubicacion'] = GeoPoint(lat.toDouble(), lng.toDouble());
      }

      // perimetro (si existe en CSV en un formato que se pueda parsear, aquí no).
      // Por seguridad, solo lo aplicamos si viene no vacío y es JSON válido.
      final perRaw = getStr(iPerimetro);
      if (perRaw != null) {
        try {
          // Se deja como string si el backend lo espera así (hoy no).
          // En tu modelo actual, `perimetro` es List<GeoPoint>, así que no lo tocamos.
        } catch (_) {}
      }

      // Campos derivados útiles para búsquedas
      putIfNotNull('nombreSocialLower', getStr(iNombreLower) ?? nombre?.toLowerCase());
      putIfNotNull('codigoLower', getStr(iCodigoLower) ?? codigo?.toLowerCase());
      // Mantener qrData si no existe; merge no borra, pero si está nulo, lo rellenamos.
      putIfNotNull('qrData', docId);

      try {
        final ref = col.doc(docId);
        batch.set(ref, data, SetOptions(merge: true));
        inBatch++;
        procesados++;

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

    return 'Merge CSV locales: procesados=$procesados, errores=$errores';
  }

  // Parser simple de CSV (soporta comillas dobles y "" escape).
  static List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch == ',' && !inQuotes) {
        out.add(sb.toString());
        sb.clear();
        continue;
      }
      sb.write(ch);
    }
    out.add(sb.toString());
    return out;
  }
}

