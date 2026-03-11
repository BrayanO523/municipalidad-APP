import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../app_update/presentation/viewmodels/app_update_viewmodel.dart';
import '../../../app_update/presentation/widgets/app_update_dialog.dart';
import '../widgets/printer_config_dialog.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CobradorShell extends ConsumerStatefulWidget {
  final Widget child;

  const CobradorShell({super.key, required this.child});

  @override
  ConsumerState<CobradorShell> createState() => _CobradorShellState();
}

class _CobradorShellState extends ConsumerState<CobradorShell> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usuario = ref.watch(currentUsuarioProvider).value;
    final updateState = ref.watch(appUpdateNotifierProvider);

    // Mostrar diálogo automáticamente cuando hay actualización disponible
    ref.listen<AppUpdateState>(appUpdateNotifierProvider, (prev, next) {
      if (next.availableRelease != null &&
          !next.isPostponed &&
          next.status == AppUpdateStatus.idle &&
          !_dialogShown) {
        _dialogShown = true;
        AppUpdateDialog.show(context);
      }
      if (next.status == AppUpdateStatus.postponed ||
          (next.availableRelease == null && _dialogShown)) {
        _dialogShown = false;
      }
    });

    final hasUpdate = updateState.availableRelease != null;

    return Scaffold(
      drawer: _buildDrawer(context, colorScheme, textTheme, hasUpdate, updateState),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, colorScheme, textTheme, usuario),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DRAWER LATERAL
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDrawer(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool hasUpdate,
    AppUpdateState updateState,
  ) {
    final currentPrimary = ref.watch(primaryColorProvider);

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    color: colorScheme.onPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'QRecauda',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Panel del Cobrador',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Inicio',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/cobrador');
                  },
                ),
                _DrawerItem(
                  icon: Icons.analytics_rounded,
                  label: 'Resumen Operativo',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/cobrador/resumen');
                  },
                ),
                _DrawerItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Realizar Corte Diario',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/cobrador/corte');
                  },
                ),
                _DrawerItem(
                  icon: Icons.history_rounded,
                  label: 'Mi Historial de Cortes',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/cobrador/cortes-historial');
                  },
                ),
                const Divider(indent: 16, endIndent: 16, height: 24),
                _DrawerItem(
                  icon: Icons.system_update_rounded,
                  label: 'Actualización',
                  subtitle: hasUpdate
                      ? 'v${updateState.availableRelease!.version} disponible'
                      : 'Sin actualizaciones',
                  hasBadge: hasUpdate,
                  onTap: () {
                    Navigator.pop(context);
                    if (hasUpdate) {
                      AppUpdateDialog.show(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ La aplicación está actualizada'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Selector de Tema
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker(context, ref, currentPrimary);
              },
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: currentPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5), width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color del Tema',
                          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Toca para personalizar',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.palette_rounded, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  COLOR PICKER
  // ═══════════════════════════════════════════════════════════════════
  void _showColorPicker(BuildContext context, WidgetRef ref, Color currentColor) {
    Color pickedColor = currentColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: pickedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Elige el Color del Tema',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ColorPicker(
                  pickerColor: pickedColor,
                  onColorChanged: (color) {
                    setLocalState(() => pickedColor = color);
                  },
                  colorPickerWidth: 280,
                  pickerAreaHeightPercent: 0.6,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                  pickerAreaBorderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(height: 8),
                // Toggle Modo Claro / Oscuro dentro del BottomSheet
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ref.read(themeModeProvider.notifier).toggle();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Builder(
                      builder: (context) {
                        final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
                        final textTheme = Theme.of(context).textTheme;
                        return Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                key: ValueKey(isDark),
                                color: isDark ? Colors.amber : Colors.orange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDark ? 'Modo Oscuro' : 'Modo Claro',
                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Switch(
                              value: isDark,
                              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                              thumbIcon: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Icon(Icons.dark_mode_rounded, size: 16);
                                }
                                return const Icon(Icons.light_mode_rounded, size: 16);
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          ref.read(primaryColorProvider.notifier).setColor(pickedColor);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTopBar(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    dynamic usuario,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu button
          Builder(
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded),
                color: colorScheme.primary,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // App Title + User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QRecauda',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        usuario?.nombre ?? 'Cobrador',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'COBRADOR',
                        style: TextStyle(
                          fontSize: 8,
                          color: colorScheme.onPrimaryContainer,
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

          const SizedBox(width: 4),

          // Action Buttons
          _TopBarButton(
            icon: Icons.map_rounded,
            tooltip: 'Ver Mapa de Ruta',
            onPressed: () => context.push('/cobrador/mapa'),
          ),
          const SizedBox(width: 4),
          _TopBarButton(
            icon: Icons.print_rounded,
            tooltip: 'Configurar Impresora',
            isActive: Consumer(
              builder: (context, ref, _) {
                final isConnected = ref.watch(printerConnectionProvider);
                return Icon(
                  Icons.print_rounded,
                  size: 18,
                  color: isConnected
                      ? AppColors.success
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                );
              },
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  minChildSize: 0.4,
                  maxChildSize: 0.85,
                  expand: false,
                  builder: (context, scrollController) =>
                      PrinterConfigDialog(scrollController: scrollController),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          _TopBarButton(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar Sesión',
            isDanger: true,
            onPressed: () async {
              final ds = ref.read(authDatasourceProvider);
              await ds.logout();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  WIDGETS PRIVADOS REUTILIZABLES
// ═══════════════════════════════════════════════════════════════════════

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool hasBadge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.hasBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Badge(
        isLabelVisible: hasBadge,
        backgroundColor: colorScheme.error,
        smallSize: 8,
        child: Icon(icon, color: colorScheme.primary, size: 22),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDanger;
  final Widget? isActive;

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDanger = false,
    this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDanger
            ? colorScheme.errorContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        icon: isActive ??
            Icon(
              icon,
              size: 18,
              color: isDanger
                  ? colorScheme.error
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
        tooltip: tooltip,
      ),
    );
  }
}
