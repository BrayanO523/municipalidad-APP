/// Servicio de instalación de actualizaciones.
///
/// Interfaz pura Dart. Cada plataforma provee su implementación
/// vía entry points + DI.
abstract class AppInstallerService {
  /// Intenta instalar el binario ubicado en [filePath].
  Future<void> install(String filePath);

  /// Indica si esta plataforma soporta instalación automática de binarios.
  bool get isSupported;
}
