import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../features/cobros/data/models/hive/cobro_hive.dart';
import '../features/locales/data/models/hive/local_hive.dart';
import '../features/mercados/data/models/hive/mercado_hive.dart';
import '../firebase_options.dart';

/// Lógica de inicialización compartida entre todas las plataformas.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. i18n
  await initializeDateFormatting('es', null);
  Intl.defaultLocale = 'es';
  
  // 2. Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 3. Hive (Base de datos local y offline)
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(CobroHiveAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LocalHiveAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(MercadoHiveAdapter());
  }
}
