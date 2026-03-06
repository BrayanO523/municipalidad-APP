import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../domain/entities/usuario.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(usuariosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UsuariosHeader(
              onSearch: (q) => setState(() => _searchQuery = q),
              onAdd: () => _showFormDialog(context),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: usuariosAsync.when(
                data: (list) {
                  final filtrados = list.where((u) {
                    // Solo mostrar cobradores en esta pantalla
                    if (u.rol != 'cobrador') return false;

                    final searchStr = _searchQuery.toLowerCase();
                    return (u.nombre?.toLowerCase().contains(searchStr) ??
                            false) ||
                        (u.email?.toLowerCase().contains(searchStr) ?? false);
                  }).toList();

                  if (filtrados.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron usuarios',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return _UsuariosTable(
                    usuarios: filtrados,
                    onEdit: (u) => _showFormDialog(context, usuario: u),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFormDialog(BuildContext context, {Usuario? usuario}) {
    final isEditing = usuario != null;
    final nombreCtrl = TextEditingController(text: usuario?.nombre);
    final emailCtrl = TextEditingController(text: usuario?.email);
    final passCtrl = TextEditingController(); // Solo para creacion

    final currentAdmin = ref.read(currentUsuarioProvider).value;
    final mercados = ref.read(mercadosProvider).value ?? [];

    String? selectedMercadoId = usuario?.mercadoId;
    final List<String> selectedLocalesIds = usuario?.rutaAsignada != null
        ? List<String>.from(usuario!.rutaAsignada!)
        : [];

    // Solo mostrar mercados de la municipalidad del admin
    final mercadosFiltrados = mercados
        .where(
          (m) =>
              m.id == selectedMercadoId ||
              m.municipalidadId == currentAdmin?.municipalidadId,
        )
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Cobrador' : 'Nuevo Cobrador'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                    ),
                    enabled: !isEditing, // Evitar cambiar auth email por ahora
                  ),
                  if (!isEditing) const SizedBox(height: 12),
                  if (!isEditing)
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      obscureText: true,
                    ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMercadoId,
                    decoration: const InputDecoration(
                      labelText: 'Mercado Asignado',
                    ),
                    items: mercadosFiltrados.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text(m.nombre ?? 'Sin nombre'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedMercadoId = val),
                  ),
                  const SizedBox(height: 16),
                  if (selectedMercadoId != null) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Asignar Locales',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Consumer(
                        builder: (ctx, ref, _) {
                          final localesAsync = ref.watch(localesProvider);
                          final usuariosAsync = ref.watch(usuariosProvider);

                          return localesAsync.when(
                            data: (allLocales) {
                              final usuarios = usuariosAsync.value ?? [];

                              // Recolectar locales asignados a CUALQUIER otro usuario (excluyendo el actual en edición)
                              final Set<String> localesOcupados = {};
                              for (final u in usuarios) {
                                if (isEditing && u.id == usuario.id) continue;
                                if (u.rutaAsignada != null) {
                                  localesOcupados.addAll(u.rutaAsignada!);
                                }
                              }

                              // Filtrar locales que pertenecen al mercado seleccionado
                              final localesMercado = allLocales
                                  .where(
                                    (l) => l.mercadoId == selectedMercadoId,
                                  )
                                  .toList();

                              // Clasificamos las dos listas interactuantes
                              final localesAsignados = localesMercado
                                  .where(
                                    (l) => selectedLocalesIds.contains(l.id),
                                  )
                                  .toList();

                              final localesDisponibles = localesMercado
                                  .where(
                                    (l) =>
                                        !selectedLocalesIds.contains(l.id) &&
                                        !localesOcupados.contains(l.id),
                                  )
                                  .toList();

                              if (localesMercado.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No hay locales en este mercado',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }

                              // Estilo utilitario para los items
                              Widget buildListTile(
                                String title,
                                VoidCallback onTap,
                                IconData icon,
                                Color iconColor,
                              ) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onTap,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 6.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            icon,
                                            size: 16,
                                            color: iconColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Row(
                                children: [
                                  // Columna Izquierda: Sin Asignar
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(4),
                                          color: Colors.black12,
                                          child: const Text(
                                            'Sin asignar',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: localesDisponibles.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'Nada aquí',
                                                    style: TextStyle(
                                                      color: Colors.white24,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount:
                                                      localesDisponibles.length,
                                                  itemBuilder: (ctx, i) {
                                                    final loc =
                                                        localesDisponibles[i];
                                                    return buildListTile(
                                                      loc.nombreSocial ??
                                                          'Sin nombre',
                                                      () => setDialogState(
                                                        () => selectedLocalesIds
                                                            .add(loc.id!),
                                                      ),
                                                      Icons
                                                          .arrow_forward_ios_rounded,
                                                      Colors.green.shade400,
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const VerticalDivider(
                                    width: 1,
                                    color: Colors.white10,
                                  ),
                                  // Columna Derecha: Asignados
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(4),
                                          color: Colors.black12,
                                          child: const Text(
                                            'Asignado a este usuario',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueAccent,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: localesAsignados.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'Ninguno',
                                                    style: TextStyle(
                                                      color: Colors.white24,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount:
                                                      localesAsignados.length,
                                                  itemBuilder: (ctx, i) {
                                                    final loc =
                                                        localesAsignados[i];
                                                    return buildListTile(
                                                      loc.nombreSocial ??
                                                          'Sin nombre',
                                                      () => setDialogState(
                                                        () => selectedLocalesIds
                                                            .remove(loc.id),
                                                      ),
                                                      Icons.close_rounded,
                                                      Colors.red.shade400,
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const Center(
                              child: Text('Error al cargar locales'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final pass = passCtrl.text.trim();

                if (nombre.isEmpty ||
                    (!isEditing && (email.isEmpty || pass.isEmpty))) {
                  return; // validaciones basicas
                }

                try {
                  final ds = ref.read(authDatasourceProvider);
                  if (isEditing) {
                    await ds.actualizarUsuario(usuario.id!, {
                      'nombre': nombre,
                      'mercadoId': selectedMercadoId,
                      'rutaAsignada': selectedLocalesIds,
                    });
                  } else {
                    await ds.registrarCobrador(
                      email: email,
                      password: pass,
                      nombre: nombre,
                      municipalidadId: currentAdmin?.municipalidadId ?? '',
                      mercadoId: selectedMercadoId,
                      rutaAsignada: selectedLocalesIds,
                    );
                  }
                  ref.invalidate(usuariosProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsuariosHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _UsuariosHeader({required this.onSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        const Text(
          'Gestión de Cobradores',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 250,
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar cobrador...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 18,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Crear Cobrador'),
        ),
      ],
    );
  }
}

class _UsuariosTable extends ConsumerWidget {
  final List<Usuario> usuarios;
  final ValueChanged<Usuario> onEdit;

  const _UsuariosTable({required this.usuarios, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mercados = ref.watch(mercadosProvider).value ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        itemCount: usuarios.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final u = usuarios[index];
          final strMercado =
              mercados.where((m) => m.id == u.mercadoId).firstOrNull?.nombre ??
              'No asignado';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              child: Text(
                u.nombre?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              u.nombre ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${u.email} • Mercado: $strMercado',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white54),
              onPressed: () => onEdit(u),
            ),
          );
        },
      ),
    );
  }
}
