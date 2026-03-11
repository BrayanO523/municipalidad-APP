import '../../domain/repositories/app_installer_service.dart';

/// Stub de [AppInstallerService] para plataformas sin soporte
/// de instalación automática (Web, iOS, Desktop).
///
/// [isSupported] retorna `false` para que la UI muestre
/// un mensaje alternativo (ej. redirigir a tienda).
class AppInstallerStub implements AppInstallerService {
  @override
  bool get isSupported => false;

  @override
  Future<void> install(String filePath) {
    throw UnsupportedError(
      'La instalación automática no está soportada en esta plataforma. '
      'Por favor descarga la actualización manualmente.',
    );
  }
}
