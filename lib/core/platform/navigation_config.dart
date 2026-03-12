import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NavItemConfig {
  final IconData icon;
  final String label;
  final String path;

  const NavItemConfig({
    required this.icon,
    required this.label,
    required this.path,
  });
}

abstract class NavigationConfig {
  List<NavItemConfig> getMenuItems();
}

class DefaultNavigationConfig implements NavigationConfig {
  @override
  List<NavItemConfig> getMenuItems() {
    return [
      const NavItemConfig(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/dashboard',
      ),
      const NavItemConfig(
        icon: Icons.people_alt_rounded,
        label: 'Cobradores',
        path: '/usuarios',
      ),
      const NavItemConfig(
        icon: Icons.tag_rounded,
        label: 'Correlativos',
        path: '/correlativos',
      ),
      const NavItemConfig(
        icon: Icons.map_rounded,
        label: 'Diseño de Rutas',
        path: '/rutas-admin',
      ),
      const NavItemConfig(
        icon: Icons.store_rounded,
        label: 'Mercados',
        path: '/mercados',
      ),
      const NavItemConfig(
        icon: Icons.storefront_rounded,
        label: 'Locales',
        path: '/locales',
      ),
      const NavItemConfig(
        icon: Icons.category_rounded,
        label: 'Tipos de Negocio',
        path: '/tipos-negocio',
      ),
      const NavItemConfig(
        icon: Icons.store_mall_directory_rounded,
        label: 'Corte de Mercado',
        path: '/cortes-mercado',
      ),
      const NavItemConfig(
        icon: Icons.history_edu_rounded,
        label: 'Historial de Cortes',
        path: '/cortes-historial',
      ),
      const NavItemConfig(
        icon: Icons.receipt_long_rounded,
        label: 'Cobros',
        path: '/cobros',
      ),
      const NavItemConfig(
        icon: Icons.savings_rounded,
        label: 'Saldos a Favor',
        path: '/saldos-favor',
      ),
      const NavItemConfig(
        icon: Icons.warning_amber_rounded,
        label: 'Deudores',
        path: '/deudores',
      ),
      // Solo visible en modo debug (flutter run). En deploy de Firebase no aparece.
      if (kDebugMode) ...[
        const NavItemConfig(
          icon: Icons.admin_panel_settings,
          label: '[DEV] Crear Admin',
          path: '/crear-admin',
        ),
        const NavItemConfig(
          icon: Icons.data_object_rounded,
          label: '[DEV] Visor DB',
          path: '/dev-firestore',
        ),
        const NavItemConfig(
          icon: Icons.rocket_launch_rounded,
          label: '[DEV] Seeder FIFO',
          path: '/dev-seeder',
        ),
      ]
    ];
  }
}

class MobileNavigationConfig extends DefaultNavigationConfig {
  @override
  List<NavItemConfig> getMenuItems() {
    final items = super.getMenuItems();
    // Insertamos 'Resumen Operativo' después de Dashboard (índice 1)
    items.insert(
      1,
      const NavItemConfig(
        icon: Icons.analytics_rounded,
        label: 'Resumen Operativo',
        path: '/reportes-resumen',
      ),
    );
    return items;
  }
}
