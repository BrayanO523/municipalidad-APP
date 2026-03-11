import 'package:hive/hive.dart';

import '../../domain/entities/installed_version.dart';
import '../models/hive/installed_version_hive.dart';

/// Datasource local para historial de versiones instaladas (Hive).
class AppUpdateLocalDatasource {
  static const _boxName = 'installed_versions';

  Future<Box<InstalledVersionHive>> _openBox() =>
      Hive.openBox<InstalledVersionHive>(_boxName);

  /// Inserta una versión instalada, evitando duplicados por version+build.
  Future<void> insertVersion(InstalledVersion version) async {
    final box = await _openBox();
    final key = '${version.version}+${version.buildNumber}';

    // Evitar duplicados
    if (box.containsKey(key)) return;

    await box.put(key, InstalledVersionHive.fromEntity(version));
  }

  /// Retorna las versiones con estado de sincronización pendiente.
  Future<List<InstalledVersion>> getPendingSyncVersions() async {
    final box = await _openBox();
    return box.values
        .where((v) => v.syncStatus == 'pending')
        .map((v) => v.toEntity())
        .toList();
  }

  /// Marca una versión como sincronizada.
  Future<void> markAsSynced(String versionKey) async {
    final box = await _openBox();
    final item = box.get(versionKey);
    if (item != null) {
      item.syncStatus = 'synced';
      await item.save();
    }
  }

  /// Retorna todas las versiones instaladas (para consulta).
  Future<List<InstalledVersion>> getAllVersions() async {
    final box = await _openBox();
    return box.values.map((v) => v.toEntity()).toList();
  }
}
