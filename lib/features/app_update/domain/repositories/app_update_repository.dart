import '../entities/app_release_info.dart';
import '../entities/installed_version.dart';

/// Contrato del repositorio de actualizaciones.
///
/// Interfaz pura Dart (sin plugins ni imports de plataforma).
abstract class AppUpdateRepository {
  /// Escucha el último release disponible para la [platform].
  Stream<AppReleaseInfo?> watchLatestRelease(String platform);

  /// Descarga el binario del release.
  /// Retorna la ruta local del archivo guardado.
  /// [onProgress] recibe valores de 0.0 a 1.0.
  Future<String> downloadRelease(
    AppReleaseInfo info, {
    void Function(double progress)? onProgress,
  });

  /// Verifica si el binario ya fue descargado y cacheado.
  Future<bool> isAlreadyDownloaded(AppReleaseInfo info);

  /// Registra una versión como instalada localmente.
  Future<void> recordInstalledVersion(InstalledVersion version);

  /// Sincroniza el historial de versiones pendientes hacia Firestore.
  Future<void> syncVersionHistory();
}
