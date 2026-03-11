import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../widgets/printer_config_dialog.dart';

class CobradorShell extends ConsumerWidget {
  final Widget child;

  const CobradorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final usuario = ref.watch(currentUsuarioProvider).value;

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QRecauda',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard_rounded, color: colorScheme.primary),
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context);
                context.go('/cobrador');
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics_rounded, color: colorScheme.primary),
              title: const Text('Resumen Operativo'),
              onTap: () {
                Navigator.pop(context);
                context.push('/cobrador/resumen');
              },
            ),
            ListTile(
              leading: Icon(Icons.point_of_sale_rounded, color: colorScheme.primary),
              title: const Text('Realizar Corte Diario'),
              onTap: () {
                Navigator.pop(context);
                context.push('/cobrador/corte');
              },
            ),
            ListTile(
              leading: Icon(Icons.history_rounded, color: colorScheme.primary),
              title: const Text('Mi Historial de Cortes'),
              onTap: () {
                Navigator.pop(context);
                context.push('/cobrador/cortes-historial');
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outline, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      color: colorScheme.primary,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QRecauda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                usuario?.nombre ?? 'Cobrador',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'COBRADOR',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => context.push('/cobrador/mapa'),
                    icon: Icon(
                      Icons.map_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    tooltip: 'Ver Mapa de Ruta',
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const PrinterConfigDialog(),
                      );
                    },
                    icon: Consumer(
                      builder: (context, ref, _) {
                        final isConnected =
                            ref.watch(printerConnectionProvider);
                        return Icon(
                          Icons.print_rounded,
                          size: 20,
                          color: isConnected
                              ? Colors.greenAccent
                              : colorScheme.primary,
                        );
                      },
                    ),
                    tooltip: 'Configurar Impresora',
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final ds = ref.read(authDatasourceProvider);
                      await ds.logout();
                    },
                    icon: Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    tooltip: 'Cerrar Sesión',
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
