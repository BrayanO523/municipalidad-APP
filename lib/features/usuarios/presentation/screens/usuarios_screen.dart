import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/usuario.dart';
import '../viewmodels/usuarios_paginados_notifier.dart';
import 'cobrador_historial_screen.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchColumn = 'Nombre';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(usuariosPaginadosProvider.notifier).cargarPagina();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(usuariosPaginadosProvider.notifier).buscar(value);
    });
  }

  Future<void> _limpiarFiltros() async {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _searchColumn = 'Nombre');
    await ref.read(usuariosPaginadosProvider.notifier).restablecerFiltros();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usuariosPaginadosProvider);
    final notifier = ref.read(usuariosPaginadosProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 760;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UsuariosHeader(
                  paginaActual: state.paginaActual,
                  totalRegistros: state.totalRegistros,
                  searchController: _searchCtrl,
                  onSearch: _onSearchChanged,
                  onReload: notifier.recargar,
                  onClear: _limpiarFiltros,
                  onAdd: () => _showFormDialog(context),
                  selectedColumn: _searchColumn,
                  onColumnChanged: (val) {
                    if (val == null) return;
                    setState(() => _searchColumn = val);
                    notifier.cambiarColumnaBusqueda(val);
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: state.cargando && state.usuarios.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : state.errorMsg != null
                      ? Center(
                          child: Text(
                            state.errorMsg!,
                            style: TextStyle(
                              color: context.semanticColors.danger,
                            ),
                          ),
                        )
                      : _buildContentCard(context, state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, UsuariosPaginadosState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: state.usuarios.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron cobradores',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  )
                : _UsuariosTable(
                    usuarios: state.usuarios,
                    onEdit: (u) => _showFormDialog(context, usuario: u),
                    onDelete: (u) => _confirmDelete(context, u),
                  ),
          ),
          if (state.totalRegistros > 0)
            _PaginationBar(
              currentPage: state.paginaActual,
              totalPages: state.totalPaginas,
              onPrev: state.paginaActual > 1
                  ? ref
                        .read(usuariosPaginadosProvider.notifier)
                        .irAPaginaAnterior
                  : null,
              onNext: state.paginaActual < state.totalPaginas
                  ? ref
                        .read(usuariosPaginadosProvider.notifier)
                        .irAPaginaSiguiente
                  : null,
              isCargando: state.cargando,
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Usuario usuario) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cobrador'),
        content: Text(
          '¿Estás seguro de que deseas eliminar al cobrador "${usuario.nombre}"?\n\nEsta acción NO se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.semanticColors.danger,
              foregroundColor: context.semanticColors.onDanger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ds = ref.read(authDatasourceProvider);
      try {
        await ds.eliminarUsuario(usuario.id!);
        ref.read(usuariosPaginadosProvider.notifier).recargar();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _showFormDialog(BuildContext context, {Usuario? usuario}) {
    final isEditing = usuario != null;
    final nombreCtrl = TextEditingController(text: usuario?.nombre);
    final emailCtrl = TextEditingController(text: usuario?.email);
    final passCtrl = TextEditingController();
    final codigoCtrl = TextEditingController(text: usuario?.codigoCobrador);

    final currentAdmin = ref.read(currentUsuarioProvider).value;
    final ds = ref.read(authDatasourceProvider);

    if (!isEditing && currentAdmin?.municipalidadId != null) {
      ds.sugerirSiguienteCodigoCobrador(currentAdmin!.municipalidadId!).then((
        sugerencia,
      ) {
        codigoCtrl.text = sugerencia;
      });
    }

    // Estado mutable del diálogo — se declara aquí para ser accesible por el Consumer
    String? selectedMercadoId = usuario?.mercadoId;
    final List<String> selectedLocalesIds = usuario?.rutaAsignada != null
        ? List<String>.from(usuario!.rutaAsignada!)
        : [];
    String localSearchQuery = '';
    // Sets para multi-selección con checkboxes
    final Set<String> checkedDisponibles = {};
    final Set<String> checkedAsignados = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Consumer(
          builder: (ctx, ref, _) {
            // ✅ FIX: Leemos mercados DENTRO del Consumer para garantizar datos frescos
            // Antes se leía con ref.read() fuera del builder, lo que daba [] si aún no cargaba
            final mercados = ref.watch(mercadosProvider).value ?? [];
            final mercadosFiltrados = mercados
                .where(
                  (m) =>
                      m.id == selectedMercadoId ||
                      m.municipalidadId == currentAdmin?.municipalidadId,
                )
                .toList();

            return AlertDialog(
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
                        controller: codigoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Código Cobrador',
                          hintText: 'C1',
                          filled: true,
                          helperText:
                              'No repetir con otro cobrador de la misma municipalidad',
                        ),
                        onChanged: (val) {
                          final upper = val.toUpperCase();
                          if (val != upper) {
                            codigoCtrl.value = codigoCtrl.value.copyWith(
                              text: upper,
                              selection: TextSelection.collapsed(
                                offset: upper.length,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                        ),
                        enabled: !isEditing,
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
                      // Dropdown de Mercado — se refresh automático vía Consumer
                      DropdownButtonFormField<String>(
                        initialValue:
                            mercadosFiltrados.any(
                              (m) => m.id == selectedMercadoId,
                            )
                            ? selectedMercadoId
                            : null,
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
                        Row(
                          children: [
                            Text(
                              'Asignar Locales',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Buscar local...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 16,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                ),
                                onChanged: (val) => setDialogState(
                                  () => localSearchQuery = val,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Consumer(
                            builder: (ctx, ref, _) {
                              final localesAsync = ref.watch(localesProvider);
                              final usuariosAsync = ref.watch(usuariosProvider);

                              return localesAsync.when(
                                data: (allLocales) {
                                  final usuarios = usuariosAsync.value ?? [];
                                  final Set<String> localesOcupados = {};
                                  for (final u in usuarios) {
                                    if (isEditing && u.id == usuario.id) {
                                      continue;
                                    }
                                    if (u.rutaAsignada != null) {
                                      localesOcupados.addAll(u.rutaAsignada!);
                                    }
                                  }

                                  final query = localSearchQuery.toLowerCase();
                                  final localesMercado = allLocales
                                      .where(
                                        (l) => l.mercadoId == selectedMercadoId,
                                      )
                                      .where((l) {
                                        if (query.isEmpty) return true;
                                        final nombre =
                                            l.nombreSocial?.toLowerCase() ?? '';
                                        final ruta =
                                            l.ruta?.toLowerCase() ?? '';
                                        return nombre.contains(query) ||
                                            ruta.contains(query);
                                      })
                                      .toList();

                                  final localesAsignados = localesMercado
                                      .where(
                                        (l) =>
                                            selectedLocalesIds.contains(l.id),
                                      )
                                      .toList();

                                  final localesDisponibles = localesMercado
                                      .where(
                                        (l) =>
                                            !selectedLocalesIds.contains(
                                              l.id,
                                            ) &&
                                            !localesOcupados.contains(l.id),
                                      )
                                      .toList();

                                  if (localesMercado.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No hay locales en este mercado',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.54),
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }

                                  Widget buildCheckTile(
                                    String id,
                                    String title,
                                    bool isChecked,
                                    ValueChanged<bool?> onCheck,
                                    VoidCallback onTap,
                                    IconData trailingIcon,
                                    Color trailingColor,
                                  ) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: onTap,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                            vertical: 2.0,
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: Checkbox(
                                                  value: isChecked,
                                                  onChanged: onCheck,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                trailingIcon,
                                                size: 14,
                                                color: trailingColor,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return Row(
                                    children: [
                                      // ── Columna izquierda: Disponibles ──
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.6),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Checkbox(
                                                      value:
                                                          localesDisponibles
                                                              .isNotEmpty &&
                                                          localesDisponibles.every(
                                                            (l) =>
                                                                checkedDisponibles
                                                                    .contains(
                                                                      l.id,
                                                                    ),
                                                          ),
                                                      tristate: true,
                                                      onChanged: (_) => setDialogState(() {
                                                        final allChecked =
                                                            localesDisponibles.every(
                                                              (l) =>
                                                                  checkedDisponibles
                                                                      .contains(
                                                                        l.id,
                                                                      ),
                                                            );
                                                        if (allChecked) {
                                                          checkedDisponibles
                                                              .clear();
                                                        } else {
                                                          for (final l
                                                              in localesDisponibles) {
                                                            if (l.id != null) {
                                                              checkedDisponibles
                                                                  .add(l.id!);
                                                            }
                                                          }
                                                        }
                                                      }),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Sin asignar (${localesDisponibles.length})',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.54,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: localesDisponibles.isEmpty
                                                  ? Center(
                                                      child: Text(
                                                        'Nada aquí',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.24,
                                                                  ),
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      itemCount:
                                                          localesDisponibles
                                                              .length,
                                                      itemBuilder: (ctx, i) {
                                                        final loc =
                                                            localesDisponibles[i];
                                                        return buildCheckTile(
                                                          loc.id ?? '',
                                                          loc.nombreSocial ??
                                                              'Sin nombre',
                                                          checkedDisponibles
                                                              .contains(loc.id),
                                                          (
                                                            val,
                                                          ) => setDialogState(() {
                                                            if (val == true) {
                                                              checkedDisponibles
                                                                  .add(loc.id!);
                                                            } else {
                                                              checkedDisponibles
                                                                  .remove(
                                                                    loc.id,
                                                                  );
                                                            }
                                                          }),
                                                          () => setDialogState(
                                                            () =>
                                                                selectedLocalesIds
                                                                    .add(
                                                                      loc.id!,
                                                                    ),
                                                          ),
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          context
                                                              .semanticColors
                                                              .success,
                                                        );
                                                      },
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ── Columna central: Botones de acción ──
                                      Container(
                                        width: 36,
                                        decoration: BoxDecoration(
                                          border: Border.symmetric(
                                            vertical: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Mover todos >>
                                            Tooltip(
                                              message: 'Asignar todos',
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons
                                                      .keyboard_double_arrow_right,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 32,
                                                    ),
                                                onPressed:
                                                    localesDisponibles.isEmpty
                                                    ? null
                                                    : () => setDialogState(() {
                                                        for (final l
                                                            in localesDisponibles) {
                                                          if (l.id != null) {
                                                            selectedLocalesIds
                                                                .add(l.id!);
                                                          }
                                                        }
                                                        checkedDisponibles
                                                            .clear();
                                                      }),
                                              ),
                                            ),
                                            // Mover seleccionados >
                                            Tooltip(
                                              message: 'Asignar seleccionados',
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.chevron_right,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 32,
                                                    ),
                                                onPressed:
                                                    checkedDisponibles.isEmpty
                                                    ? null
                                                    : () => setDialogState(() {
                                                        selectedLocalesIds
                                                            .addAll(
                                                              checkedDisponibles,
                                                            );
                                                        checkedDisponibles
                                                            .clear();
                                                      }),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Devolver seleccionados <
                                            Tooltip(
                                              message: 'Quitar seleccionados',
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.chevron_left,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 32,
                                                    ),
                                                onPressed:
                                                    checkedAsignados.isEmpty
                                                    ? null
                                                    : () => setDialogState(() {
                                                        selectedLocalesIds
                                                            .removeWhere(
                                                              (id) =>
                                                                  checkedAsignados
                                                                      .contains(
                                                                        id,
                                                                      ),
                                                            );
                                                        checkedAsignados
                                                            .clear();
                                                      }),
                                              ),
                                            ),
                                            // Devolver todos <<
                                            Tooltip(
                                              message: 'Quitar todos',
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons
                                                      .keyboard_double_arrow_left,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 32,
                                                    ),
                                                onPressed:
                                                    localesAsignados.isEmpty
                                                    ? null
                                                    : () => setDialogState(() {
                                                        final asignadosIds =
                                                            localesAsignados
                                                                .map(
                                                                  (l) => l.id!,
                                                                )
                                                                .toSet();
                                                        selectedLocalesIds
                                                            .removeWhere(
                                                              (id) =>
                                                                  asignadosIds
                                                                      .contains(
                                                                        id,
                                                                      ),
                                                            );
                                                        checkedAsignados
                                                            .clear();
                                                      }),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ── Columna derecha: Asignados ──
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.6),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Checkbox(
                                                      value:
                                                          localesAsignados
                                                              .isNotEmpty &&
                                                          localesAsignados.every(
                                                            (l) =>
                                                                checkedAsignados
                                                                    .contains(
                                                                      l.id,
                                                                    ),
                                                          ),
                                                      tristate: true,
                                                      onChanged: (_) => setDialogState(() {
                                                        final allChecked =
                                                            localesAsignados.every(
                                                              (l) =>
                                                                  checkedAsignados
                                                                      .contains(
                                                                        l.id,
                                                                      ),
                                                            );
                                                        if (allChecked) {
                                                          checkedAsignados
                                                              .clear();
                                                        } else {
                                                          for (final l
                                                              in localesAsignados) {
                                                            if (l.id != null) {
                                                              checkedAsignados
                                                                  .add(l.id!);
                                                            }
                                                          }
                                                        }
                                                      }),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Asignados (${localesAsignados.length})',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: localesAsignados.isEmpty
                                                  ? Center(
                                                      child: Text(
                                                        'Ninguno',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.24,
                                                                  ),
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      itemCount:
                                                          localesAsignados
                                                              .length,
                                                      itemBuilder: (ctx, i) {
                                                        final loc =
                                                            localesAsignados[i];
                                                        return buildCheckTile(
                                                          loc.id ?? '',
                                                          loc.nombreSocial ??
                                                              'Sin nombre',
                                                          checkedAsignados
                                                              .contains(loc.id),
                                                          (
                                                            val,
                                                          ) => setDialogState(
                                                            () {
                                                              if (val == true) {
                                                                checkedAsignados
                                                                    .add(
                                                                      loc.id!,
                                                                    );
                                                              } else {
                                                                checkedAsignados
                                                                    .remove(
                                                                      loc.id,
                                                                    );
                                                              }
                                                            },
                                                          ),
                                                          () => setDialogState(
                                                            () =>
                                                                selectedLocalesIds
                                                                    .remove(
                                                                      loc.id,
                                                                    ),
                                                          ),
                                                          Icons.close_rounded,
                                                          context
                                                              .semanticColors
                                                              .danger,
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
                    final municipalidadId = currentAdmin?.municipalidadId ?? '';
                    var codigo = codigoCtrl.text.trim().toUpperCase();

                    if (nombre.isEmpty ||
                        (!isEditing && (email.isEmpty || pass.isEmpty))) {
                      return;
                    }

                    if (municipalidadId.isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se puede guardar: el administrador no tiene municipalidad asignada.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final ds = ref.read(authDatasourceProvider);
                      if (codigo.isEmpty) {
                        codigo = await ds.sugerirSiguienteCodigoCobrador(
                          municipalidadId,
                        );
                        codigoCtrl.text = codigo;
                      }

                      final codigoLibre = await ds.codigoCobradorDisponible(
                        municipalidadId: municipalidadId,
                        codigo: codigo,
                        excluirUsuarioId: usuario?.id,
                      );

                      if (!codigoLibre) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ya existe un cobrador con el código $codigo en esta municipalidad.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      if (isEditing) {
                        await ds.actualizarUsuario(usuario.id!, {
                          'nombre': nombre,
                          'mercadoId': selectedMercadoId,
                          'rutaAsignada': selectedLocalesIds,
                          'codigoCobrador': codigo,
                        });
                      } else {
                        await ds.registrarCobrador(
                          email: email,
                          password: pass,
                          nombre: nombre,
                          municipalidadId: municipalidadId,
                          mercadoId: selectedMercadoId,
                          rutaAsignada: selectedLocalesIds,
                          codigoCobrador: codigo,
                        );
                      }
                      ref.read(usuariosPaginadosProvider.notifier).recargar();
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
            );
          },
        ),
      ),
    );
  }
}

class _UsuariosHeader extends StatelessWidget {
  final int paginaActual;
  final int totalRegistros;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onReload;
  final Future<void> Function() onClear;
  final VoidCallback onAdd;
  final String selectedColumn;
  final ValueChanged<String?> onColumnChanged;
  const _UsuariosHeader({
    required this.paginaActual,
    required this.totalRegistros,
    required this.searchController,
    required this.onSearch,
    required this.onReload,
    required this.onClear,
    required this.onAdd,
    required this.selectedColumn,
    required this.onColumnChanged,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isDesktop = w >= 1100;
            final isTablet = w >= 760 && w < 1100;
            final isMobile = w < 760;
            Widget actions({required bool compact}) {
              final compactStyle = OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
              );
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: compactStyle,
                      onPressed: onReload,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Recargar'),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      style: compactStyle,
                      onPressed: () => onClear(),
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                      label: const Text('Limpiar'),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 14,
                        ),
                      ),
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Agregar'),
                    ),
                  ),
                ],
              );
            }

            final headerLeft = Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cobradores',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                      ),
                      Text(
                        'Pagina ' +
                            paginaActual.toString() +
                            ' - ' +
                            totalRegistros.toString() +
                            ' registros',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final header = isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerLeft,
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actions(compact: true),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: headerLeft),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: actions(compact: !isDesktop),
                        ),
                      ),
                    ],
                  );
            Widget filtersDesktop() {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 220,
                    child: _SearchColumnDropdown(
                      value: selectedColumn,
                      onChanged: onColumnChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SearchInput(
                      controller: searchController,
                      onChanged: onSearch,
                    ),
                  ),
                ],
              );
            }

            Widget filtersTablet() {
              return Column(
                children: [
                  _SearchColumnDropdown(
                    value: selectedColumn,
                    onChanged: onColumnChanged,
                  ),
                  const SizedBox(height: 8),
                  _SearchInput(
                    controller: searchController,
                    onChanged: onSearch,
                  ),
                ],
              );
            }

            final filtersGroup = Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.22,
                ),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: isTablet || isMobile ? filtersTablet() : filtersDesktop(),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, const SizedBox(height: 8), filtersGroup],
            );
          },
        ),
      ),
    );
  }
}

class _SearchColumnDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _SearchColumnDropdown({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: const Icon(Icons.arrow_drop_down_rounded),
      decoration: InputDecoration(
        labelText: 'Buscar por',
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: 'Nombre', child: Text('Nombre')),
        DropdownMenuItem(
          value: 'Correo electronico',
          child: Text('Correo electronico'),
        ),
        DropdownMenuItem(value: 'Codigo', child: Text('Codigo')),
        DropdownMenuItem(value: 'Mercado', child: Text('Mercado (ID)')),
      ],
      onChanged: onChanged,
    );
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchInput({required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Buscar cobrador',
        hintText: 'Nombre, correo, codigo o mercado...',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _UsuariosTable extends ConsumerWidget {
  final List<Usuario> usuarios;
  final ValueChanged<Usuario> onEdit;
  final ValueChanged<Usuario> onDelete;
  const _UsuariosTable({
    required this.usuarios,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mercados = ref.watch(mercadosProvider).value ?? [];
    return ListView.separated(
      itemCount: usuarios.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
      ),
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
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              u.nombre?.substring(0, 1).toUpperCase() ?? 'U',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            u.nombre ?? '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: LayoutBuilder(
            builder: (context, subtitleConstraints) {
              final isNarrow = subtitleConstraints.maxWidth < 300;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.email ?? '',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Codigo: ' +
                          (u.codigoCobrador ?? 'S/C') +
                          ' - ' +
                          strMercado,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (u.creadoEn != null)
                      Text(
                        'Creado: ' + DateFormatter.formatDate(u.creadoEn!),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (u.email ?? '') +
                        ' - Codigo: ' +
                        (u.codigoCobrador ?? 'S/C') +
                        ' - Mercado: ' +
                        strMercado,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    u.creadoEn != null
                        ? 'Creado: ' + DateFormatter.formatDate(u.creadoEn!)
                        : 'Creado: -',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
                onPressed: () => onEdit(u),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(
                  Icons.analytics_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          CobradorHistorialScreen(cobrador: u),
                    ),
                  );
                },
                tooltip: 'Ver historial',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_rounded,
                  color: context.semanticColors.danger,
                ),
                onPressed: () => onDelete(u),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
    required this.isCargando,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isCargando)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: isCargando ? null : onPrev,
            color: onPrev != null
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
            tooltip: 'Pagina anterior',
          ),
          const SizedBox(width: 8),
          Text(
            'Pagina ' + currentPage.toString() + ' de ' + totalPages.toString(),
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isCargando ? null : onNext,
            color: onNext != null
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
            tooltip: 'Pagina siguiente',
          ),
        ],
      ),
    );
  }
}
