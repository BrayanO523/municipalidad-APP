import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../../core/widgets/scrollable_table.dart';
import '../../data/models/municipalidad_model.dart';
import '../../domain/entities/municipalidad.dart';
import '../viewmodels/municipalidades_paginas_notifier.dart';

class MunicipalidadesScreen extends ConsumerStatefulWidget {
  const MunicipalidadesScreen({super.key});

  @override
  ConsumerState<MunicipalidadesScreen> createState() =>
      _MunicipalidadesScreenState();
}

class _MunicipalidadesScreenState extends ConsumerState<MunicipalidadesScreen> {
  String _searchColumn = 'Nombre';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(municipalidadesPaginadasProvider.notifier).cargarPagina();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(municipalidadesPaginadasProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScreenHeader(
              onSearch: (q) => ref.read(municipalidadesPaginadasProvider.notifier).buscar(q),
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
              child: state.cargando && state.municipalidades.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.errorMsg != null
                      ? Center(
                          child: Text(
                            state.errorMsg!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        )
                      : state.municipalidades.isEmpty
                          ? Center(
                              child: Text(
                                'No se encontraron municipalidades',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54)),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: _MunicipalidadesTable(
                                    municipalidades: state.municipalidades,
                                    onEdit: (m) => _showFormDialog(context, municipalidad: m),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _PaginationBar(
                                  currentPage: state.paginaActual - 1,
                                  onPrev: state.paginaActual > 1
                                      ? () => ref
                                          .read(municipalidadesPaginadasProvider.notifier)
                                          .irAPaginaAnterior()
                                      : null,
                                  onNext: state.hayMas
                                      ? () => ref
                                          .read(municipalidadesPaginadasProvider.notifier)
                                          .irAPaginaSiguiente()
                                      : null,
                                  isCargando: state.cargando,
                                ),
                              ],
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
              ref.read(municipalidadesPaginadasProvider.notifier).recargar();
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
  final String selectedColumn;
  final ValueChanged<String?> onColumnChanged;

  const _ScreenHeader({
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
                'Municipalidades',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'GestiÃ³n de municipalidades registradas',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54)),
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
              icon: Icon(Icons.arrow_drop_down,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54)),
              isDense: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              items: ['Nombre', 'Municipio', 'Departamento'].map((
                String value,
              ) {
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
      child: ScrollableTable(
        child: DataTable(
          columns: const [
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
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.24),
          tooltip: 'PÃ¡gina anterior',
        ),
        const SizedBox(width: 8),
        Text(
          'PÃ¡gina ${currentPage + 1}',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.54),
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
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.24),
          tooltip: 'PÃ¡gina siguiente',
        ),
      ],
    );
  }
}
