// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'app/bootstrap.dart';
import 'app/di/providers.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'core/platform/navigation_config.dart';

/// Referencia global al ProviderContainer de la web para poder
/// invalidar providers desde callbacks del navegador (tab visibility).
ProviderContainer? _webContainer;

void main() async {
  await bootstrap();

  final container = ProviderContainer(
    overrides: [
      navigationConfigProvider.overrideWithValue(DefaultNavigationConfig()),
      printerPersistenceDataSourceProvider.overrideWithValue(
        PrinterPersistenceLocalDataSource(),
      ),
    ],
  );
  _webContainer = container;

  // P3: Tab Visibility — pausa el stream de cobros cuando la pestaña no está visible.
  // Ahorra lecturas de fondo cuando el admin deja la pestaña minimizada horas.
  web.document.addEventListener(
    'visibilitychange',
    (web.Event _) {
      final isHidden = web.document.visibilityState == 'hidden';
      if (isHidden) {
        // El admin cambió de pestaña — invalidar el stream de cobros del día.
        // Con autoDispose activo, esto cancela la suscripción de Firestore.
        _webContainer?.invalidate(cobrosHoyProvider);
      }
      // Al volver visible, cobrosHoyProvider se re-suscribe automáticamente
      // la próxima vez que un widget lo observe (lazy re-subscription).
    }.toJS,
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
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

    return MaterialApp.router(
      title: 'QRecauda Municipalidad (Web)',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
    );
  }
}

