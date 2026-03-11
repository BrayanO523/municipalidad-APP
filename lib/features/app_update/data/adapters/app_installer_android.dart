import 'package:open_filex/open_filex.dart';

import '../../domain/repositories/app_installer_service.dart';

/// Implementación de [AppInstallerService] para Android.
///
/// Usa `open_filex` para abrir el APK con el instalador del sistema.
/// Se inyecta via entry point en `main.dart`.
class AppInstallerAndroid implements AppInstallerService {
  @override
  bool get isSupported => true;

  @override
  Future<void> install(String filePath) async {
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      throw Exception(
        'No se pudo abrir el instalador: ${result.message}',
      );
    }
  }
}
