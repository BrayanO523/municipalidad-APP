import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../data/models/municipalidad_model.dart';
import '../../domain/entities/municipalidad.dart';

class MunicipalidadesScreen extends ConsumerStatefulWidget {
  const MunicipalidadesScreen({super.key});

  @override
  ConsumerState<MunicipalidadesScreen> createState() =>
      _MunicipalidadesScreenState();
}

class _MunicipalidadesScreenState extends ConsumerState<MunicipalidadesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final municipalidades = ref.watch(municipalidadesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScreenHeader(
              onSearch: (q) => setState(() => _searchQuery = q),
              onAdd: () => _showFormDialog(context),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: municipalidades.when(
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
                        'No se encontraron municipalidades',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return _MunicipalidadesTable(
                    municipalidades: filtered,
                    onEdit: (m) => _showFormDialog(context, municipalidad: m),
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

  void _showFormDialog(BuildContext context, {Municipalidad? municipalidad}) {
    final isEditing = municipalidad != null;
    final nombreCtrl = TextEditingController(text: municipalidad?.nombre);
    final municipioCtrl = TextEditingController(text: municipalidad?.municipio);
    final departamentoCtrl = TextEditingController(
      text: municipalidad?.departamento,
    );
    final porcentajeCtrl = TextEditingController(
      text: municipalidad?.porcentaje?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Municipalidad' : 'Nueva Municipalidad'),
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
                controller: municipioCtrl,
                decoration: const InputDecoration(labelText: 'Municipio'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departamentoCtrl,
                decoration: const InputDecoration(labelText: 'Departamento'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: porcentajeCtrl,
                decoration: const InputDecoration(labelText: 'Porcentaje'),
                keyboardType: TextInputType.number,
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
              final ds = ref.read(municipalidadDatasourceProvider);
              final now = DateTime.now();
              final docId = isEditing
                  ? municipalidad.id!
                  : IdNormalizer.municipalidadId(nombreCtrl.text);

              final model = MunicipalidadJson(
                activa: true,
                actualizadoEn: now,
                actualizadoPor: 'admin',
                creadoEn: isEditing ? municipalidad.creadoEn : now,
                creadoPor: isEditing ? municipalidad.creadoPor : 'admin',
                departamento: departamentoCtrl.text,
                id: docId,
                municipio: municipioCtrl.text,
                nombre: nombreCtrl.text,
                porcentaje: num.tryParse(porcentajeCtrl.text),
              );

              if (isEditing) {
                await ds.actualizar(docId, model.toJson());
              } else {
                await ds.crear(docId, model.toJson());
              }
              ref.invalidate(municipalidadesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Actualizar' : 'Crear'),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _ScreenHeader({required this.onSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Municipalidades',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestión de municipalidades registradas',
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

class _MunicipalidadesTable extends StatelessWidget {
  final List<Municipalidad> municipalidades;
  final ValueChanged<Municipalidad> onEdit;

  const _MunicipalidadesTable({
    required this.municipalidades,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Municipio')),
            DataColumn(label: Text('Departamento')),
            DataColumn(label: Text('Porcentaje')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: municipalidades.map((m) {
            return DataRow(
              cells: [
                DataCell(
                  Text(m.id ?? '-', style: const TextStyle(fontSize: 12)),
                ),
                DataCell(Text(m.nombre ?? '-')),
                DataCell(Text(m.municipio ?? '-')),
                DataCell(Text(m.departamento ?? '-')),
                DataCell(Text('${m.porcentaje ?? 0}%')),
                DataCell(_ActiveChip(active: m.activa ?? false)),
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
        active ? 'Activa' : 'Inactiva',
        style: TextStyle(
          color: active ? const Color(0xFF00D9A6) : Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
