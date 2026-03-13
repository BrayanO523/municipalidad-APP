import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../../core/widgets/scrollable_table.dart';
import '../../data/models/mercado_model.dart';
import '../../domain/entities/mercado.dart';
import '../widgets/map_picker_modal.dart';
import '../viewmodels/mercados_paginados_notifier.dart';

class MercadosScreen extends ConsumerStatefulWidget {
  const MercadosScreen({super.key});

  @override
  ConsumerState<MercadosScreen> createState() => _MercadosScreenState();
}

class _MercadosScreenState extends ConsumerState<MercadosScreen> {
  String _searchColumn = 'Nombre';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mercadosPaginadosProvider.notifier).cargarPagina();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mercadosPaginadosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isMobile = outerConstraints.maxWidth <= 700;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MercadosHeader(
                  onSearch: (q) => ref.read(mercadosPaginadosProvider.notifier).buscar(q),
                  onAdd: () => _showFormDialog(context),
                  selectedColumn: _searchColumn,
                  onColumnChanged: (val) {
                    if (val != null) {
                      setState(() => _searchColumn = val);
                    }
                  },
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: state.cargando && state.mercados.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : state.errorMsg != null
                          ? Center(
                              child: Text(
                                state.errorMsg!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            )
                          : state.mercados.isEmpty
                              ? Center(
                                  child: Text(
                                    'No se encontraron mercados',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: _MercadosTable(
                                        mercados: state.mercados,
                                        onEdit: (m) => _showFormDialog(context, mercado: m),
                                        onDelete: (m) => _confirmDelete(context, m),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _PaginationBar(
                                      currentPage: state.paginaActual - 1,
                                      onPrev: state.paginaActual > 1
                                          ? () => ref.read(mercadosPaginadosProvider.notifier).irAPaginaAnterior()
                                          : null,
                                      onNext: state.hayMas
                                          ? () => ref.read(mercadosPaginadosProvider.notifier).irAPaginaSiguiente()
                                          : null,
                                      isCargando: state.cargando,
                                    ),
                                  ],
                                ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Mercado mercado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Mercado'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el mercado "${mercado.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ds = ref.read(mercadoDatasourceProvider);
      await ds.eliminar(mercado.id!);
      ref.read(mercadosPaginadosProvider.notifier).recargar();
    }
  }

  void _showFormDialog(BuildContext context, {Mercado? mercado}) {
    final isEditing = mercado != null;
    final nombreCtrl = TextEditingController(text: mercado?.nombre);
    final ubicacionCtrl = TextEditingController(text: mercado?.ubicacion);
    final currentAdmin = ref.read(currentUsuarioProvider).value;
    String? selectedMunicipalidadId =
        mercado?.municipalidadId ?? currentAdmin?.municipalidadId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Mercado' : 'Nuevo Mercado'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ubicacionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación Descriptiva',
                    hintText: 'Ej. Zona 1, frente al parque',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  tileColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: const Icon(Icons.map_rounded, color: Colors.blueAccent),
                  title: Text(
                    'Perímetro del Mercado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    mercado?.perimetro != null || (mercado?.perimetro?.isNotEmpty ?? false)
                        ? 'Área definida (${mercado!.perimetro!.length} puntos)'
                        : 'Sin definir en el mapa',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                  ),
                  onTap: () async {
                    final List<LatLng>? result = await showDialog<List<LatLng>>(
                      context: context,
                      builder: (ctx) => MapPickerModal(
                        mode: MapPickerMode.polygon,
                        initialPoints: mercado?.perimetro
                            ?.map((p) => LatLng(p['lat']!, p['lng']!))
                            .toList(),
                      ),
                    );

                    if (result != null) {
                      setDialogState(() {
                        mercado = Mercado(
                          id: mercado?.id,
                          nombre: nombreCtrl.text,
                          ubicacion: ubicacionCtrl.text,
                          perimetro: result
                              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                              .toList(),
                          latitud: result.first.latitude,
                          longitud: result.first.longitude,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMunicipalidadId == null) return;
                final ds = ref.read(mercadoDatasourceProvider);
                final now = DateTime.now();

                final docId = isEditing
                    ? mercado!.id!
                    : IdNormalizer.mercadoId(
                        currentAdmin?.municipalidadId ?? 'MUN',
                        nombreCtrl.text,
                      );

                final model = MercadoJson(
                  activo: true,
                  actualizadoEn: now,
                  actualizadoPor: 'admin',
                  creadoEn: isEditing ? mercado!.creadoEn : now,
                  creadoPor: isEditing ? mercado!.creadoPor : 'admin',
                  id: docId,
                  municipalidadId: selectedMunicipalidadId,
                  nombre: nombreCtrl.text,
                  ubicacion: ubicacionCtrl.text,
                  perimetro: mercado?.perimetro,
                  latitud: mercado?.latitud,
                  longitud: mercado?.longitud,
                );

                if (isEditing) {
                  await ds.actualizar(docId, model.toJson());
                } else {
                  await ds.crear(docId, model.toJson());
                }
                ref.read(mercadosPaginadosProvider.notifier).recargar();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Actualizar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MercadosHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final String selectedColumn;
  final ValueChanged<String?> onColumnChanged;

  const _MercadosHeader({
    required this.onSearch,
    required this.onAdd,
    required this.selectedColumn,
    required this.onColumnChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mercados',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestión de mercados de QRecauda',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedColumn,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                        isDense: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                        items: ['Nombre', 'Ubicación'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: onColumnChanged,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mercados',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestión de mercados de QRecauda',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedColumn,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                  isDense: true,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  items: ['Nombre', 'Ubicación'].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: onColumnChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 260,
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}

class _MercadosTable extends StatelessWidget {
  final List<Mercado> mercados;
  final ValueChanged<Mercado> onEdit;
  final ValueChanged<Mercado> onDelete;

  const _MercadosTable({
    required this.mercados,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ScrollableTable(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Ubicación')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Fecha Creación')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: mercados.map((m) {
            return DataRow(
              cells: [
                DataCell(Text(m.nombre ?? '-')),
                DataCell(Text(m.ubicacion ?? '-')),
                DataCell(_ActiveChip(active: m.activo ?? false)),
                DataCell(
                  Text(
                    m.creadoEn != null ? DateFormatter.formatDate(m.creadoEn!) : '-',
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () => onEdit(m),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => onDelete(m),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final bool active;

  const _ActiveChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? const Color(0xFF00D9A6) : Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: active ? const Color(0xFF00D9A6) : Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isCargando;

  const _PaginationBar({
    required this.currentPage,
    required this.onPrev,
    required this.onNext,
    required this.isCargando,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página anterior',
        ),
        const SizedBox(width: 8),
        Text(
          'Página ${currentPage + 1}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
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
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
          tooltip: 'Página siguiente',
        ),
      ],
    );
  }
}

