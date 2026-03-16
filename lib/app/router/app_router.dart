import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cobrador/presentation/screens/cobrador_home_screen.dart';
import '../../features/cobrador/presentation/screens/cobrador_estado_cuenta_screen.dart';
import '../../features/cobrador/presentation/screens/cobrador_shell.dart';
import '../../features/cobrador/presentation/screens/qr_scanner_screen.dart';
import '../../features/cobros/presentation/screens/cobros_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/reportes/presentation/screens/resumen_reportes_screen.dart';
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
import '../../features/gestiones/presentation/screens/incidencias_admin_screen.dart';
import '../../features/usuarios/domain/entities/usuario.dart';
import '../../features/usuarios/presentation/screens/correlativos_control_screen.dart';
import '../../features/usuarios/presentation/screens/cobros_cobrador_screen.dart';
import '../../features/cortes/presentation/screens/corte_nuevo_screen.dart';
import '../../features/cortes/presentation/screens/cortes_historial_screen.dart';
import '../../features/cortes/presentation/screens/corte_detalle_screen.dart';
import '../../features/cortes/presentation/screens/corte_mercado_screen.dart';
import '../../features/cortes/domain/entities/corte.dart';
import '../../features/usuarios/presentation/screens/crear_admin_screen.dart';
import '../../features/dev/presentation/screens/firestore_viewer_screen.dart';
import '../../features/dev/presentation/screens/dev_seeder_screen.dart';
import '../../features/dev/presentation/screens/debug_deuda_manager_screen.dart';
import '../di/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  // Usamos .select para observar ÚNICAMENTE el estado de carga y el rol.
  // Así evitamos que la aplicación reconstruya el GoRouter (cerrando modales como el recibo)
  // cuando cambian datos irrelevantes para el ruteo en el currentUsuarioProvider
  // (por ejemplo, cuando se actualiza el 'correlativoReciboActual' tras un cobro).
  final isUsuarioLoading = ref.watch(
    currentUsuarioProvider.select((data) => data.isLoading),
  );
  final esCobrador = ref.watch(
    currentUsuarioProvider.select((data) => data.value?.esCobrador),
  );

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState.isLoading || isUsuarioLoading) {
        return '/splash';
      }

      final isLoggedIn = authState.value != null;
      final isGoingToLogin = state.uri.toString() == '/login';
      final isGoingToSplash = state.uri.toString() == '/splash';

      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }

      // Si está logueado pero intenta ir al login o splash, redirigir según su rol.
      if (isLoggedIn && (isGoingToLogin || isGoingToSplash)) {
        if (esCobrador == true) return '/cobrador';
        return '/dashboard'; // Default admin
      }

      // Protección de rutas: Si es cobrador intentando acceder a admin
      if (isLoggedIn) {
        if (esCobrador == true) {
          final path = state.uri.toString();
          if (!path.startsWith('/cobrador') && path != '/login') {
            return '/cobrador';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const Scaffold(
          backgroundColor: Color(0xFF10121B),
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
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
            path: '/incidencias',
            name: 'incidencias',
            builder: (context, state) => const IncidenciasAdminScreen(),
          ),
          GoRoute(
            path: '/correlativos',
            name: 'correlativos',
            builder: (context, state) => const CorrelativosControlScreen(),
            routes: [
              GoRoute(
                path: 'cobrador',
                name: 'cobrador-cobros-admin',
                builder: (context, state) {
                  final cobrador = state.extra as Usuario;
                  return CobrosCobradorScreen(cobrador: cobrador);
                },
              ),
            ],
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
          GoRoute(
            path: '/cortes-mercado',
            name: 'cortes-mercado-admin',
            builder: (context, state) => const CortesMercadoScreen(),
          ),
          GoRoute(
            path: '/cortes-historial',
            name: 'cortes-historial-admin',
            builder: (context, state) =>
                const CortesHistorialScreen(isAdmin: true),
          ),
          GoRoute(
            path: '/corte-detalle',
            name: 'corte-detalle-admin',
            builder: (context, state) {
              final corte = state.extra as Corte;
              return CorteDetalleScreen(corte: corte);
            },
          ),
          // Solo disponible en debug, nunca en release/deploy
          if (kDebugMode) ...[
            GoRoute(
              path: '/crear-admin',
              name: 'crear-admin',
              builder: (context, state) => const CrearAdminScreen(),
            ),
            GoRoute(
              path: '/dev-firestore',
              name: 'dev-firestore',
              builder: (context, state) => const FirestoreViewerScreen(),
            ),
            GoRoute(
              path: '/dev-seeder',
              name: 'dev-seeder',
              builder: (context, state) => const DevSeederScreen(),
            ),
            GoRoute(
              path: '/debug-deuda-manager',
              name: 'debug-deuda-manager',
              builder: (context, state) => const DebugDeudaManagerScreen(),
            ),
          ],
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
          GoRoute(
            path: '/cobrador/corte',
            name: 'cobrador-corte',
            builder: (context, state) => const CorteNuevoScreen(),
          ),
          GoRoute(
            path: '/cobrador/cortes-historial',
            name: 'cobrador-cortes-historial',
            builder: (context, state) =>
                const CortesHistorialScreen(isAdmin: false),
          ),
          GoRoute(
            path: '/cobrador/corte-detalle',
            name: 'corte-detalle-cobrador',
            builder: (context, state) {
              final corte = state.extra as Corte;
              return CorteDetalleScreen(corte: corte);
            },
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
          GoRoute(
            path: '/cobrador/resumen',
            name: 'cobrador-resumen',
            builder: (context, state) => const ResumenReportesScreen(),
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
