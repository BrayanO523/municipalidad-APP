import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════
//  THEME MODE (Claro / Oscuro)
// ═══════════════════════════════════════════════════════════════════════

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════
//  PRIMARY COLOR (Color primario dinámico con persistencia)
// ═══════════════════════════════════════════════════════════════════════

const _prefKey = 'app_primary_color';

/// Provider que precarga el color guardado ANTES de que la app lo necesite.
/// Se resuelve una vez al arrancar y luego entrega el valor de forma síncrona.
final _savedColorFuture = FutureProvider<Color>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final savedValue = prefs.getInt(_prefKey);
  if (savedValue != null) {
    return Color(savedValue);
  }
  return kDefaultPrimaryColor;
});

class PrimaryColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    // Lee el valor precargado por el FutureProvider.
    // Si aún está cargando, usa el default; cuando se resuelva,
    // Riverpod invalidará este provider automáticamente.
    final asyncColor = ref.watch(_savedColorFuture);
    return asyncColor.when(
      data: (color) => color,
      loading: () => kDefaultPrimaryColor,
      error: (_, __) => kDefaultPrimaryColor,
    );
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt(_prefKey, color.value);
  }
}

final primaryColorProvider = NotifierProvider<PrimaryColorNotifier, Color>(
  PrimaryColorNotifier.new,
);
