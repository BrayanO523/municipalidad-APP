import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/app_update_viewmodel.dart';
import 'app_update_dialog.dart';

/// Badge de actualización que se muestra cuando el usuario postpone.
///
/// Coloca este widget sobre un ícono existente (ej. en AppBar o BottomNav)
/// para indicar que hay una actualización pendiente.
class AppUpdateBadge extends ConsumerWidget {
  /// Widget hijo sobre el cual se coloca el badge.
  final Widget child;

  const AppUpdateBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateNotifierProvider);
    final showBadge = state.availableRelease != null &&
        (state.isPostponed ||
            state.status == AppUpdateStatus.readyToInstall ||
            state.status == AppUpdateStatus.postponed);

    if (!showBadge) return child;

    return GestureDetector(
      onTap: () {
        ref.read(appUpdateNotifierProvider.notifier).showUpdateAgain();
        AppUpdateDialog.show(context);
      },
      child: Badge(
        backgroundColor: Theme.of(context).colorScheme.error,
        smallSize: 10,
        child: child,
      ),
    );
  }
}
