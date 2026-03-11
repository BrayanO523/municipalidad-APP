import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/app_release_info.dart';
import '../../domain/entities/installed_version.dart';
import '../models/app_release_model.dart';

/// Datasource remoto para actualizaciones.
///
/// Usa Firestore para escuchar releases y Firebase Storage para descargar binarios.
class AppUpdateRemoteDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AppUpdateRemoteDatasource(this._firestore, this._storage);

  /// Escucha cambios en el documento `app_releases/latest` para la [platform].
  Stream<AppReleaseInfo?> watchLatestRelease(String platform) {
    return _firestore
        .doc('app_releases/latest')
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null || !data.containsKey(platform)) return null;

      final platformData = data[platform] as Map<String, dynamic>?;
      if (platformData == null) return null;

      return AppReleaseModel.fromFirestore(platformData).toEntity();
    });
  }

  /// Obtiene la URL de descarga desde Firebase Storage.
  Future<String> getDownloadUrl(String storagePath) {
    return _storage.ref(storagePath).getDownloadURL();
  }

  /// Descarga un archivo desde [url] con reporte de progreso.
  ///
  /// [onProgress] recibe valores de 0.0 a 1.0.
  /// Retorna los bytes del archivo descargado.
  Future<Uint8List> downloadFile(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    final contentLength = response.contentLength ?? 0;
    final List<int> bytes = [];
    int received = 0;

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(received / contentLength);
      }
    }

    return Uint8List.fromList(bytes);
  }

  /// Sincroniza las versiones instaladas a Firestore.
  Future<void> syncVersionHistory(
    List<InstalledVersion> versions, {
    required String deviceId,
  }) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection('empresa_device_versions');

    for (final v in versions) {
      final docRef = collection.doc('${deviceId}_${v.version}+${v.buildNumber}');
      batch.set(docRef, {
        'deviceId': deviceId,
        'version': v.version,
        'buildNumber': v.buildNumber,
        'platform': v.platform,
        'installedAt': Timestamp.fromDate(v.installedAt),
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
