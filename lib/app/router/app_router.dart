import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cobros/presentation/screens/cobros_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/locales/presentation/screens/locales_screen.dart';
import '../../features/mercados/presentation/screens/mercados_screen.dart';
import '../../features/municipalidades/presentation/screens/municipalidades_screen.dart';
import '../../features/shell/presentation/screens/shell_screen.dart';
import '../../features/tipos_negocio/presentation/screens/tipos_negocio_screen.dart';
import '../../features/usuarios/presentation/screens/login_screen.dart';
import '../di/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isGoingToLogin = state.uri.toString() == '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/municipalidades',
            name: 'municipalidades',
            builder: (context, state) => const MunicipalidadesScreen(),
          ),
          GoRoute(
            path: '/mercados',
            name: 'mercados',
            builder: (context, state) => const MercadosScreen(),
          ),
          GoRoute(
            path: '/locales',
            name: 'locales',
            builder: (context, state) => const LocalesScreen(),
          ),
          GoRoute(
            path: '/tipos-negocio',
            name: 'tipos-negocio',
            builder: (context, state) => const TiposNegocioScreen(),
          ),
          GoRoute(
            path: '/cobros',
            name: 'cobros',
            builder: (context, state) => const CobrosScreen(),
          ),
        ],
      ),
    ],
  );
});
