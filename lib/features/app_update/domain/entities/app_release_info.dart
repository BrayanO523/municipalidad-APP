/// Información de un release disponible para una plataforma.
///
/// Entidad de dominio pura (sin dependencias externas).
class AppReleaseInfo {
  final String version;
  final int buildNumber;
  final String storagePath;
  final String fileName;
  final DateTime? updatedAt;

  const AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.storagePath,
    required this.fileName,
    this.updatedAt,
  });

  @override
  String toString() =>
      'AppReleaseInfo(v$version+$buildNumber, file=$fileName)';
}
