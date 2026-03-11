/// Registro de una versión instalada localmente.
///
/// Entidad de dominio pura (sin dependencias externas).
class InstalledVersion {
  final String id;
  final String version;
  final int buildNumber;
  final String platform;
  final DateTime installedAt;
  /// Estado de sincronización: 'pending' o 'synced'.
  final String syncStatus;

  const InstalledVersion({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.installedAt,
    this.syncStatus = 'pending',
  });

  InstalledVersion copyWith({String? syncStatus}) {
    return InstalledVersion(
      id: id,
      version: version,
      buildNumber: buildNumber,
      platform: platform,
      installedAt: installedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  String toString() =>
      'InstalledVersion(v$version+$buildNumber, $platform, $syncStatus)';
}
