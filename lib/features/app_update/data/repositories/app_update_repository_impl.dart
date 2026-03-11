import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/app_release_info.dart';
import '../../domain/entities/installed_version.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/app_update_local_datasource.dart';
import '../datasources/app_update_remote_datasource.dart';

/// Implementación del repositorio de actualizaciones.
///
/// Orquesta los datasources remoto (Firestore/Storage) y local (Hive).
/// Maneja carpeta temporal, caché, limpieza de binarios y sincronización.
class AppUpdateRepositoryImpl implements AppUpdateRepository {
  final AppUpdateRemoteDatasource _remoteDatasource;
  final AppUpdateLocalDatasource _localDatasource;
  final String _deviceId;

  AppUpdateRepositoryImpl(
    this._remoteDatasource,
    this._localDatasource, {
    required String deviceId,
  }) : _deviceId = deviceId;

  @override
  Stream<AppReleaseInfo?> watchLatestRelease(String platform) {
    return _remoteDatasource.watchLatestRelease(platform);
  }

  @override
  Future<String> downloadRelease(
    AppReleaseInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    // Determinar carpeta de descarga
    final dir = await _getDownloadDirectory();
    final filePath = '${dir.path}/${info.fileName}';
    final file = File(filePath);

    // Si ya existe y no está vacío → caché válida
    if (await file.exists() && (await file.length()) > 0) {
      debugPrint('AppUpdateRepo: Archivo en caché: $filePath');
      return filePath;
    }

    // Limpiar binarios antiguos antes de descargar
    await _cleanOldBinaries(dir, info.fileName);

    // Obtener URL y descargar
    final url = await _remoteDatasource.getDownloadUrl(info.storagePath);
    final Uint8List bytes = await _remoteDatasource.downloadFile(
      url,
      onProgress: onProgress,
    );

    // Guardar en disco
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('AppUpdateRepo: Archivo guardado en $filePath');

    return filePath;
  }

  @override
  Future<bool> isAlreadyDownloaded(AppReleaseInfo info) async {
    final dir = await _getDownloadDirectory();
    final file = File('${dir.path}/${info.fileName}');
    return await file.exists() && (await file.length()) > 0;
  }

  @override
  Future<void> recordInstalledVersion(InstalledVersion version) async {
    await _localDatasource.insertVersion(version);
  }

  @override
  Future<void> syncVersionHistory() async {
    final pending = await _localDatasource.getPendingSyncVersions();
    if (pending.isEmpty) return;

    await _remoteDatasource.syncVersionHistory(
      pending,
      deviceId: _deviceId,
    );

    // Marcar como sincronizadas
    for (final v in pending) {
      final key = '${v.version}+${v.buildNumber}';
      await _localDatasource.markAsSynced(key);
    }
  }

  /// Retorna la carpeta de descarga adecuada para la plataforma.
  Future<Directory> _getDownloadDirectory() async {
    final Directory baseDir;

    // Desktop → applicationSupport, Móvil → applicationDocuments
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      baseDir = await getApplicationSupportDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final updateDir = Directory('${baseDir.path}/app_updates');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  /// Elimina binarios antiguos (.apk, .exe, .dmg) en la carpeta,
  /// excluyendo [keepFileName].
  Future<void> _cleanOldBinaries(
    Directory dir,
    String keepFileName,
  ) async {
    const binaryExtensions = ['.apk', '.exe', '.dmg', '.AppImage', '.deb'];

    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name == keepFileName) continue;

          final hasExtension = binaryExtensions.any(
            (ext) => name.toLowerCase().endsWith(ext.toLowerCase()),
          );
          if (hasExtension) {
            await entity.delete();
            debugPrint('AppUpdateRepo: Eliminado binario antiguo: $name');
          }
        }
      }
    } catch (e) {
      debugPrint('AppUpdateRepo: Error limpiando binarios: $e');
    }
  }
}
