import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../data/models/tipo_negocio_model.dart';
import '../../domain/entities/tipo_negocio.dart';

class TiposNegocioScreen extends ConsumerStatefulWidget {
  const TiposNegocioScreen({super.key});

  @override
  ConsumerState<TiposNegocioScreen> createState() => _TiposNegocioScreenState();
}

class _TiposNegocioScreenState extends ConsumerState<TiposNegocioScreen> {
  String _searchQuery = '';
  String _searchColumn = 'Nombre';

  @override
  Widget build(BuildContext context) {
    final tiposNegocio = ref.watch(tiposNegocioProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TiposHeader(
              onSearch: (q) => setState(() => _searchQuery = q),
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
              child: tiposNegocio.when(
                data: (list) {
                  final filtered = list.where((t) {
                    final query = _searchQuery.toLowerCase();
                    if (_searchColumn == 'Nombre') {
                      return (t.nombre ?? '').toLowerCase().contains(query);
                    } else if (_searchColumn == 'Descripción') {
                      return (t.descripcion ?? '').toLowerCase().contains(
                        query,
                      );
                    }
                    return false;
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No se encontraron tipos de negocio',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                      ),
                    );
                  }
                  return _TiposTable(
                    tipos: filtered,
                    onEdit: (t) => _showFormDialog(context, tipo: t),
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

  void _showFormDialog(BuildContext context, {TipoNegocio? tipo}) {
    final isEditing = tipo != null;
    final nombreCtrl = TextEditingController(text: tipo?.nombre);
    final descripcionCtrl = TextEditingController(text: tipo?.descripcion);
    final currentAdmin = ref.read(currentUsuarioProvider).value;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEditing ? 'Editar Tipo de Negocio' : 'Nuevo Tipo de Negocio',
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
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
              final ds = ref.read(tipoNegocioDatasourceProvider);
              final now = DateTime.now();
              final docId = isEditing
                  ? tipo.id!
                  : IdNormalizer.tipoNegocioId(nombreCtrl.text);

              final model = TipoNegocioJson(
                activo: true,
                actualizadoEn: now,
                actualizadoPor: 'admin',
                creadoEn: isEditing ? tipo.creadoEn : now,
                creadoPor: isEditing ? tipo.creadoPor : 'admin',
                descripcion: descripcionCtrl.text,
                id: docId,
                nombre: nombreCtrl.text,
                municipalidadId: isEditing
                    ? tipo.municipalidadId
                    : currentAdmin?.municipalidadId,
              );

              if (isEditing) {
                await ds.actualizar(docId, model.toJson());
              } else {
                await ds.crear(docId, model.toJson());
              }
              ref.invalidate(tiposNegocioProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Actualizar' : 'Crear'),
          ),
        ],
      ),
    );
  }
}

class _TiposHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final String selectedColumn;
  final ValueChanged<String?> onColumnChanged;

  const _TiposHeader({
    required this.onSearch,
    required this.onAdd,
    required this.selectedColumn,
    required this.onColumnChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipos de Negocio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Categorías dinámicas de negocios para locales',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              ),
            ],
          ),
        ),
        Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedColumn,
              icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              isDense: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              items: ['Nombre', 'Descripción'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
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
  }
}

class _TiposTable extends StatelessWidget {
  final List<TipoNegocio> tipos;
  final ValueChanged<TipoNegocio> onEdit;

  const _TiposTable({required this.tipos, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Descripción')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: tipos.map((t) {
              return DataRow(
                cells: [
                  DataCell(Text(t.nombre ?? '-')),
                  DataCell(Text(t.descripcion ?? '-')),
                  DataCell(_ActiveChip(active: t.activo ?? false)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      onPressed: () => onEdit(t),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
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
        color: (active ? const Color(0xFF00D9A6) : Colors.grey).withValues(
          alpha: 0.15,
        ),
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