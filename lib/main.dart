import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'app/bootstrap.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'app/di/providers.dart';
import 'core/platform/navigation_config.dart';
import 'features/app_update/data/adapters/app_installer_android.dart';

Future<void> main() async {
  await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        // Si compilan la web usando directamente main.dart, debemos forzar DefaultNavigationConfig.
        // Solo inyectamos MobileNavigationConfig si NO estamos compilando para Web.
        navigationConfigProvider.overrideWithValue(
          kIsWeb ? DefaultNavigationConfig() : MobileNavigationConfig(),
        ),
        printerPersistenceDataSourceProvider.overrideWithValue(
          PrinterPersistenceLocalDataSource(),
        ),
        // OTA: inyectar instalador Android para plataformas móviles
        appInstallerServiceProvider.overrideWithValue(
          AppInstallerAndroid(),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(primaryColorProvider);

    return MaterialApp.router(
      title: 'QRecauda Municipalidad',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(seedColor),
      darkTheme: AppTheme.darkTheme(seedColor),
    );
  }
}
