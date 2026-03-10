import 'permission_requester.dart';
import '../../features/shared/data/adapters/stub_permission_requester.dart'
    if (dart.library.io) '../../features/shared/data/adapters/mobile_permission_requester.dart';

/// Fábrica que devuelve la implementación correcta de PermissionRequester
/// basándose en la plataforma.
PermissionRequester getPermissionRequester() {
  // getPermissionRequester() está definido en ambos archivos importados condicionadamente.
  return getPlatformPermissionRequester();
}

// Nota: Para que esto funcione, necesitamos que las funciones en los adapters 
// tengan el MISMO NOMBRE que esperamos llamar aquí.
// He usado getPermissionRequester() en los adapters, lo renombraré a getPlatformPermissionRequester() 
// para coherencia con el patrón de la impresora.
