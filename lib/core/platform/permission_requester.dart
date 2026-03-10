/// Interfaz pura para solicitar permisos iniciales en plataformas móviles.
/// Esta clase es "Pure Dart" y se puede importar de forma segura en Web.
abstract class PermissionRequester {
  Future<void> requestInitialPermissions();
}
