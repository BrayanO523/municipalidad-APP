import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/theme_provider.dart';

class ShellLoading extends Notifier<bool> {
  @override
  bool build() => false;

  set value(bool val) => state = val;
}

final shellLoadingProvider = NotifierProvider<ShellLoading, bool>(
  ShellLoading.new,
);

class ShellScreen extends ConsumerWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(shellLoadingProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = constraints.maxWidth > 900;
        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: IgnorePointer(
                  ignoring: isLoading,
                  child: Row(
                    children: [
                      _SidebarNavigation(isExpanded: isExpanded),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
              if (isLoading)
                Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarNavigation extends ConsumerWidget {
  final bool isExpanded;

  const _SidebarNavigation({required this.isExpanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final colorScheme = Theme.of(context).colorScheme;
    final usuario = ref.watch(currentUsuarioProvider).value;
    final municipalidades = ref.watch(municipalidadesProvider).value ?? [];

    String nombreMunicipalidad = 'QRecauda Admin';
    if (usuario?.municipalidadId != null) {
      final mun = municipalidades
          .where((m) => m.id == usuario!.municipalidadId)
          .firstOrNull;
      if (mun != null && mun.nombre != null) {
        nombreMunicipalidad = mun.nombre!;
      } else {
        nombreMunicipalidad = usuario!.municipalidadId!;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isExpanded ? 260 : 72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      child: Column(
        children: [
          _SidebarHeader(
            isExpanded: isExpanded,
            municipalidad: nombreMunicipalidad,
            nombreCompleto: usuario?.nombre ?? 'Administrador',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  path: '/dashboard',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Cobradores',
                  path: '/usuarios',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.tag_rounded,
                  label: 'Correlativos',
                  path: '/correlativos',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.map_rounded,
                  label: 'Diseño de Rutas',
                  path: '/rutas-admin',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.store_rounded,
                  label: 'Mercados',
                  path: '/mercados',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.storefront_rounded,
                  label: 'Locales',
                  path: '/locales',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.category_rounded,
                  label: 'Tipos de Negocio',
                  path: '/tipos-negocio',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Cobros',
                  path: '/cobros',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.savings_rounded,
                  label: 'Saldos a Favor',
                  path: '/saldos-favor',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
                _NavItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Deudores',
                  path: '/deudores',
                  currentPath: location,
                  isExpanded: isExpanded,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _UserFooter(
            isExpanded: isExpanded,
            nombre: usuario?.nombre ?? 'Usuario',
            rol: usuario?.rol ?? '',
            onLogout: () async {
              final ds = ref.read(authDatasourceProvider);
              await ds.logout();
            },
          ),
        ],
      ),
    );
  }
}

class _UserFooter extends ConsumerWidget {
  final bool isExpanded;
  final String nombre;
  final VoidCallback onLogout;
  final String rol;

  const _UserFooter({
    required this.isExpanded,
    required this.nombre,
    required this.onLogout,
    required this.rol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(shellLoadingProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: isExpanded
          ? Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        rol.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.1),
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _ThemeToggleButton(isDark: isDark),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: isLoading ? null : onLogout,
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            )
          : Column(
              children: [
                _ThemeToggleButton(isDark: isDark),
                const SizedBox(height: 4),
                IconButton(
                  onPressed: isLoading ? null : onLogout,
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  final bool isDark;

  const _ThemeToggleButton({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            RotationTransition(turns: animation, child: child),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(isDark),
          size: 18,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      tooltip: isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool isExpanded;
  final String municipalidad;
  final String nombreCompleto;

  const _SidebarHeader({
    required this.isExpanded,
    required this.municipalidad,
    required this.nombreCompleto,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 15,
        vertical: 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
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
              size: 22,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    municipalidad,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    nombreCompleto,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.54),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;
  final bool isExpanded;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath == path;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 14 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: colorScheme.primary.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
