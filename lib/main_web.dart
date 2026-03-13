import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/bootstrap.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'app/di/providers.dart';
import 'core/platform/navigation_config.dart';

void main() async {
  await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        // En la Web forzamos el DefaultNavigationConfig (sin Resumen Operativo)
        navigationConfigProvider.overrideWithValue(DefaultNavigationConfig()),
        printerPersistenceDataSourceProvider.overrideWithValue(
          PrinterPersistenceLocalDataSource(),
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
      title: 'QRecauda Municipalidad (Web)',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(seedColor),
      darkTheme: AppTheme.darkTheme(seedColor),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
