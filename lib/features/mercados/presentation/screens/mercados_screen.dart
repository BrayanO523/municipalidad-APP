import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../data/models/mercado_model.dart';
import '../../domain/entities/mercado.dart';

class MercadosScreen extends ConsumerStatefulWidget {
  const MercadosScreen({super.key});

  @override
  ConsumerState<MercadosScreen> createState() => _MercadosScreenState();
}

class _MercadosScreenState extends ConsumerState<MercadosScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final mercados = ref.watch(mercadosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MercadosHeader(
              onSearch: (q) => setState(() => _searchQuery = q),
              onAdd: () => _showFormDialog(context),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: mercados.when(
                data: (list) {
                  final filtered = list
                      .where(
                        (m) => (m.nombre ?? '').toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron mercados',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return _MercadosTable(
                    mercados: filtered,
                    onEdit: (m) => _showFormDialog(context, mercado: m),
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

  void _showFormDialog(BuildContext context, {Mercado? mercado}) {
    final isEditing = mercado != null;
    final nombreCtrl = TextEditingController(text: mercado?.nombre);
    final ubicacionCtrl = TextEditingController(text: mercado?.ubicacion);
    final municipalidades = ref.read(municipalidadesProvider).value ?? [];
    String? selectedMunicipalidadId = mercado?.municipalidadId;

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
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMunicipalidadId,
                  decoration: const InputDecoration(labelText: 'Municipalidad'),
                  items: municipalidades
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.nombre ?? '-'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedMunicipalidadId = v),
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
                if (selectedMunicipalidadId == null) return;
                final ds = ref.read(mercadoDatasourceProvider);
                final now = DateTime.now();
                final munNombre =
                    municipalidades
                        .firstWhere((m) => m.id == selectedMunicipalidadId)
                        .nombre ??
                    '';
                final docId = isEditing
                    ? mercado.id!
                    : IdNormalizer.mercadoId(munNombre, nombreCtrl.text);

                final model = MercadoJson(
                  activo: true,
                  actualizadoEn: now,
                  actualizadoPor: 'admin',
                  creadoEn: isEditing ? mercado.creadoEn : now,
                  creadoPor: isEditing ? mercado.creadoPor : 'admin',
                  id: docId,
                  municipalidadId: selectedMunicipalidadId,
                  nombre: nombreCtrl.text,
                  ubicacion: ubicacionCtrl.text,
                );

                if (isEditing) {
                  await ds.actualizar(docId, model.toJson());
                } else {
                  await ds.crear(docId, model.toJson());
                }
                ref.invalidate(mercadosProvider);
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

  const _MercadosHeader({required this.onSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
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
                'Gestión de mercados municipales',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
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

class _MercadosTable extends StatelessWidget {
  final List<Mercado> mercados;
  final ValueChanged<Mercado> onEdit;

  const _MercadosTable({required this.mercados, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Ubicación')),
            DataColumn(label: Text('Municipalidad')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: mercados.map((m) {
            return DataRow(
              cells: [
                DataCell(
                  Text(m.id ?? '-', style: const TextStyle(fontSize: 12)),
                ),
                DataCell(Text(m.nombre ?? '-')),
                DataCell(Text(m.ubicacion ?? '-')),
                DataCell(
                  Text(
                    m.municipalidadId ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(_ActiveChip(active: m.activo ?? false)),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => onEdit(m),
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
