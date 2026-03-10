import '../../../../core/platform/permission_requester.dart';

class StubPermissionRequester implements PermissionRequester {
  @override
  Future<void> requestInitialPermissions() async {
    // No-op para Web o plataformas sin gestión de permisos standard por plugin
  }
}

PermissionRequester getPlatformPermissionRequester() => StubPermissionRequester();

