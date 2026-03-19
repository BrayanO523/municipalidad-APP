import 'package:flutter/material.dart';

/// Encabezado de columna interactivo para DataTable con soporte de ordenamiento.
///
/// Al presionar el encabezado:
/// - Si la columna NO es la activa:  → activa en ascendente
/// - Si ya es activa + ascendente:   → cambia a descendente
/// - Si ya es activa + descendente:  → desactiva (sin orden)
class SortableColumn extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const SortableColumn({
    super.key,
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.onSurface;

    IconData? icon;
    if (isActive) {
      icon = ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: icon != null
                  ? Icon(
                      icon,
                      key: ValueKey('$label-$ascending'),
                      size: 14,
                      color: colorScheme.primary,
                    )
                  : Icon(
                      Icons.unfold_more_rounded,
                      key: const ValueKey('inactive'),
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
