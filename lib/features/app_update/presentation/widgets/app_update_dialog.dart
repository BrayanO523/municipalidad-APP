import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/app_update_viewmodel.dart';

/// Diálogo de actualización OTA.
///
/// Muestra info de la nueva versión, barra de progreso durante
/// la descarga, y opciones de "Actualizar ahora" / "Más tarde".
class AppUpdateDialog extends ConsumerWidget {
  const AppUpdateDialog({super.key});

  /// Muestra el diálogo si hay actualización disponible.
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateNotifierProvider);
    final notifier = ref.read(appUpdateNotifierProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Actualización disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _buildContent(state, theme, colorScheme),
      actions: _buildActions(state, notifier, context, colorScheme),
    );
  }

  Widget _buildContent(
    AppUpdateState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final release = state.availableRelease;

    switch (state.status) {
      case AppUpdateStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Descargando v${release?.version ?? ""}...',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.downloadProgress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case AppUpdateStatus.readyToInstall:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
            const SizedBox(height: 12),
            Text(
              'v${release?.version ?? ""} lista para instalar',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case AppUpdateStatus.installing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Instalando...', style: theme.textTheme.bodyMedium),
          ],
        );

      case AppUpdateStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? 'Error desconocido',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );

      default:
        // idle / checking — mostrar info de la nueva versión
        if (release == null) {
          return const Text('Verificando actualizaciones...');
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Una nueva versión está disponible:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.new_releases, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v${release.version}+${release.buildNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        release.fileName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  List<Widget> _buildActions(
    AppUpdateState state,
    AppUpdateNotifier notifier,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    switch (state.status) {
      case AppUpdateStatus.downloading:
      case AppUpdateStatus.installing:
        // Sin botones durante descarga/instalación
        return [];

      case AppUpdateStatus.readyToInstall:
        return [
          TextButton(
            onPressed: () {
              notifier.postpone();
              Navigator.of(context).pop();
            },
            child: const Text('Más tarde'),
          ),
          FilledButton.icon(
            onPressed: () => notifier.installUpdate(),
            icon: const Icon(Icons.install_mobile, size: 18),
            label: const Text('Instalar'),
          ),
        ];

      case AppUpdateStatus.error:
        return [
          TextButton(
            onPressed: () {
              notifier.postpone();
              Navigator.of(context).pop();
            },
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () => notifier.retry(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
          ),
        ];

      default:
        // idle / checking — mostrar opciones principales
        if (state.availableRelease == null) return [];
        return [
          TextButton(
            onPressed: () {
              notifier.postpone();
              Navigator.of(context).pop();
            },
            child: const Text('Más tarde'),
          ),
          FilledButton.icon(
            onPressed: () => notifier.startDownload(),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Actualizar ahora'),
          ),
        ];
    }
  }
}
