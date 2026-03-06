import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cobrador/presentation/screens/cobrador_home_screen.dart';
import '../../features/cobrador/presentation/screens/cobrador_estado_cuenta_screen.dart';
import '../../features/cobrador/presentation/screens/cobrador_shell.dart';
import '../../features/cobrador/presentation/screens/qr_scanner_screen.dart';
import '../../features/cobros/presentation/screens/cobros_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/locales/domain/entities/local.dart';
import '../../features/locales/presentation/screens/local_historial_screen.dart';
import '../../features/locales/presentation/screens/locales_screen.dart';
import '../../features/locales/presentation/screens/deudores_screen.dart';
import '../../features/locales/presentation/screens/saldos_favor_screen.dart';
import '../../features/mercados/presentation/screens/mercados_screen.dart';
// import '../../features/municipalidades/presentation/screens/municipalidades_screen.dart';
import '../../features/rutas/presentation/screens/rutas_admin_screen.dart';
import '../../features/rutas/presentation/screens/cobrador_map_screen.dart';
import '../../features/shell/presentation/screens/shell_screen.dart';
import '../../features/tipos_negocio/presentation/screens/tipos_negocio_screen.dart';
import '../../features/usuarios/presentation/screens/login_screen.dart';
import '../../features/usuarios/presentation/screens/usuarios_screen.dart';
import '../di/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final usuarioAsync = ref.watch(currentUsuarioProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isGoingToLogin = state.uri.toString() == '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) {
        final usuario = usuarioAsync.value;
        if (usuario != null && usuario.esCobrador) return '/cobrador';
        return '/dashboard';
      }

      // Cobrador trying to access admin routes
      final usuario = usuarioAsync.value;
      if (usuario != null && usuario.esCobrador) {
        final path = state.uri.toString();
        if (!path.startsWith('/cobrador') && path != '/login') {
          return '/cobrador';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Admin routes
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/usuarios',
            name: 'usuarios',
            builder: (context, state) => const UsuariosScreen(),
          ),
          GoRoute(
            path: '/rutas-admin',
            name: 'rutas-admin',
            builder: (context, state) => const RutasAdminScreen(),
          ),
          /* 
          GoRoute(
            path: '/municipalidades',
            name: 'municipalidades',
            builder: (context, state) => const MunicipalidadesScreen(),
          ),
          */
          GoRoute(
            path: '/mercados',
            name: 'mercados',
            builder: (context, state) => const MercadosScreen(),
          ),
          GoRoute(
            path: '/locales',
            name: 'locales',
            builder: (context, state) => const LocalesScreen(),
            routes: [
              GoRoute(
                path: ':id/historial',
                name: 'local-historial',
                builder: (context, state) {
                  final local = state.extra as Local;
                  return LocalHistorialScreen(local: local);
                },
              ),
            ],
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
          GoRoute(
            path: '/saldos-favor',
            name: 'saldos-favor',
            builder: (context, state) => const SaldosFavorScreen(),
          ),
          GoRoute(
            path: '/deudores',
            name: 'deudores',
            builder: (context, state) => const DeudoresScreen(),
          ),
        ],
      ),
      // Cobrador routes
      ShellRoute(
        builder: (context, state, child) => CobradorShell(child: child),
        routes: [
          GoRoute(
            path: '/cobrador',
            name: 'cobrador',
            builder: (context, state) => const CobradorHomeScreen(),
          ),
          // Historial de local accesible desde el cobrador
          GoRoute(
            path: '/cobrador/local/:id/historial',
            name: 'cobrador-local-historial',
            builder: (context, state) {
              final local = state.extra as Local;
              return LocalHistorialScreen(local: local);
            },
          ),
          GoRoute(
            path: '/cobrador/local/:id/cuenta',
            name: 'cobrador-local-cuenta',
            builder: (context, state) {
              final local = state.extra as Local;
              return CobradorEstadoCuentaScreen(local: local);
            },
          ),
          GoRoute(
            path: '/cobrador/mapa',
            name: 'cobrador-mapa',
            builder: (context, state) => const CobradorMapScreen(),
          ),
        ],
      ),
      // QR Scanner (fullscreen, fuera del shell)
      GoRoute(
        path: '/cobrador/scan',
        name: 'cobrador-scan',
        builder: (context, state) => const QrScannerScreen(),
      ),
    ],
  );
});
