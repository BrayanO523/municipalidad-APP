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

    return usuariosAsync.when(
      data: (usuarios) {
        // Filtrar solo usuarios activos y con rol cobrador (aunque el provider ya debería hacerlo)
        final cobradores = usuarios.where((u) => u.rol == 'cobrador').toList();

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedUsuarioId,
              hint: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 13,
                ),
              ),
              icon: Icon(
                Icons.person_search_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
              ),
              isDense: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'Todos los cobradores',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ...cobradores.map((u) {
                  return DropdownMenuItem<String>(
                    value: u.id,
                    child: Text(u.nombre ?? 'Sin nombre'),
                  );
                }),
              ],
              onChanged: (val) {
                if (val == null) {
                  onUsuarioChanged(null);
                } else {
                  final user = cobradores.firstWhere((u) => u.id == val);
                  onUsuarioChanged(user);
                }
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
    );
  }
}
