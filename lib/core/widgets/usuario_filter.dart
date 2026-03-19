import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/providers.dart';
import '../../features/usuarios/domain/entities/usuario.dart';

class UsuarioFilter extends ConsumerWidget {
  final String? selectedUsuarioId;
  final ValueChanged<Usuario?> onUsuarioChanged;
  final String label;

  const UsuarioFilter({
    super.key,
    required this.selectedUsuarioId,
    required this.onUsuarioChanged,
    this.label = 'Filtrar por Cobrador',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return usuariosAsync.when(
      data: (usuarios) {
        final cobradores = usuarios.where((u) => u.rol == 'cobrador').toList();
        final opciones = <MapEntry<String?, String>>[
          const MapEntry<String?, String>(null, 'Todos los cobradores'),
          ...cobradores.map(
            (u) => MapEntry<String?, String>(u.id, u.nombre ?? 'Sin nombre'),
          ),
        ];

        return DropdownButtonFormField<String?>(
          value: selectedUsuarioId,
          isExpanded: true,
          icon: Icon(
            Icons.person_search_rounded,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          dropdownColor: colorScheme.surface,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
          items: opciones.map((o) {
            return DropdownMenuItem<String?>(
              value: o.key,
              child: Text(
                o.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) => opciones
              .map(
                (o) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    o.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val == null) {
              onUsuarioChanged(null);
            } else {
              final user = cobradores.firstWhere((u) => u.id == val);
              onUsuarioChanged(user);
            }
          },
        );
      },
      loading: () => SizedBox(
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, __) => SizedBox(
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.error.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Error cargando cobradores',
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
