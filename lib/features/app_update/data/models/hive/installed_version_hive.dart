import 'package:hive/hive.dart';

import '../../../domain/entities/installed_version.dart';

part 'installed_version_hive.g.dart';

/// Modelo Hive para persistir el historial de versiones instaladas.
@HiveType(typeId: 10)
class InstalledVersionHive extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String version;

  @HiveField(2)
  final int buildNumber;

  @HiveField(3)
  final String platform;

  @HiveField(4)
  final DateTime installedAt;

  @HiveField(5)
  String syncStatus;

  InstalledVersionHive({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.installedAt,
    this.syncStatus = 'pending',
  });

  /// Convierte a entidad de dominio.
  InstalledVersion toEntity() {
    return InstalledVersion(
      id: id,
      version: version,
      buildNumber: buildNumber,
      platform: platform,
      installedAt: installedAt,
      syncStatus: syncStatus,
    );
  }

  /// Crea desde entidad de dominio.
  factory InstalledVersionHive.fromEntity(InstalledVersion entity) {
    return InstalledVersionHive(
      id: entity.id,
      version: entity.version,
      buildNumber: entity.buildNumber,
      platform: entity.platform,
      installedAt: entity.installedAt,
      syncStatus: entity.syncStatus,
    );
  }
}
