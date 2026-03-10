import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'app/router/app_router.dart';

import 'core/platform/permission_requester_factory.dart';

/// Observador para depuración de providers.
base class Logger extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('''
⚠️ ERROR EN PROVIDER: ${context.provider.name ?? context.provider.runtimeType}
Error: $error
''');
  }
}

void main() async {
  // Inicialización común (Firebase, Hive, i18n, etc.)
  await bootstrap();
  
  // Solicitar permisos iniciales (Solo en plataformas móviles, gestionado por fábrica)
  await getPermissionRequester().requestInitialPermissions();

  runApp(ProviderScope(
    observers: [Logger()],
    child: const MunicipalidadApp(),
  ));
}

class MunicipalidadApp extends ConsumerWidget {
  const MunicipalidadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Municipalidad App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );

  }
}
