import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      if (!mounted) return;
      ref.read(municipalidadesPaginadasProvider.notifier).cargarPagina();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(municipalidadesPaginadasProvider);

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
          );
        },
      ),
    );
  }

  void _showFormDialog(BuildContext context, {Municipalidad? municipalidad}) {
    showDialog(
      context: context,
      builder: (ctx) => _MunicipalidadFormDialog(
        municipalidad: municipalidad,
        onSave: (model, docId, isEditing) async {
          final ds = ref.read(municipalidadDatasourceProvider);
          if (isEditing) {
            await ds.actualizar(docId, model.toJson());
          } else {
            await ds.crear(docId, model.toJson());
          }
          ref.read(municipalidadesPaginadasProvider.notifier).recargar();
          if (ctx.mounted) Navigator.pop(ctx);
        },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Municipalidades',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestión de municipalidades',
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
                        icon: Icon(Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                        isDense: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                        items: ['Nombre', 'Municipio', 'Departamento'].map((String value) {
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
      },
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
          tooltip: 'Página anterior',
        ),
        const SizedBox(width: 8),
        Text(
          'Página ${currentPage + 1}',
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
          tooltip: 'Página siguiente',
        ),
      ],
    );
  }
}

// ============================================================
// Diálogo de creación/edición de Municipalidad con selector de
// fecha de referencia de mora.
// ============================================================
class _MunicipalidadFormDialog extends StatefulWidget {
  final Municipalidad? municipalidad;
  final Future<void> Function(
    MunicipalidadJson model,
    String docId,
    bool isEditing,
  ) onSave;

  const _MunicipalidadFormDialog({
    required this.municipalidad,
    required this.onSave,
  });

  @override
  State<_MunicipalidadFormDialog> createState() =>
      _MunicipalidadFormDialogState();
}

class _MunicipalidadFormDialogState
    extends State<_MunicipalidadFormDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _municipioCtrl;
  late final TextEditingController _departamentoCtrl;
  late final TextEditingController _porcentajeCtrl;
  late final TextEditingController _sloganCtrl;
  DateTime? _fechaReferenciaMora;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.municipalidad;
    _nombreCtrl = TextEditingController(text: m?.nombre);
    _municipioCtrl = TextEditingController(text: m?.municipio);
    _departamentoCtrl = TextEditingController(text: m?.departamento);
    _porcentajeCtrl =
        TextEditingController(text: m?.porcentaje?.toString() ?? '');
    _sloganCtrl = TextEditingController(text: m?.slogan);
    _fechaReferenciaMora = m?.fechaReferenciaMora;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _municipioCtrl.dispose();
    _departamentoCtrl.dispose();
    _porcentajeCtrl.dispose();
    _sloganCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFechaReferencia() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaReferenciaMora ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: 'Fecha límite: deudas ANTERIORES a esta fecha se consideran mora',
    );
    if (picked != null) {
      setState(() => _fechaReferenciaMora = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.municipalidad != null;
    final fmtFecha = _fechaReferenciaMora != null
        ? DateFormat('dd/MM/yyyy').format(_fechaReferenciaMora!)
        : 'Sin configurar (usa el 1ro del mes actual)';

    return AlertDialog(
      title: Text(isEditing ? 'Editar Municipalidad' : 'Nueva Municipalidad'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _municipioCtrl,
                decoration: const InputDecoration(labelText: 'Municipio'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _departamentoCtrl,
                decoration: const InputDecoration(labelText: 'Departamento'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _porcentajeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Porcentaje (%)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sloganCtrl,
                decoration:
                    const InputDecoration(labelText: 'Slogan (opcional)'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // --- Fecha de referencia de mora ---
              Text(
                'Recaudación de Mora',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Las deudas con fecha ANTERIOR a esta se clasifican como mora.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickFechaReferencia,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fmtFecha,
                          style: TextStyle(
                            color: _fechaReferenciaMora != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      if (_fechaReferenciaMora != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setState(() => _fechaReferenciaMora = null),
                          tooltip: 'Quitar fecha (usa el mes actual)',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  try {
                    final now = DateTime.now();
                    final m = widget.municipalidad;
                    final isEd = m != null;
                    final docId = isEd
                        ? m.id!
                        : IdNormalizer.municipalidadId(_nombreCtrl.text);

                    final model = MunicipalidadJson(
                      activa: isEd ? (m.activa ?? true) : true,
                      actualizadoEn: now,
                      actualizadoPor: 'admin',
                      creadoEn: isEd ? m.creadoEn : now,
                      creadoPor: isEd ? m.creadoPor : 'admin',
                      departamento: _departamentoCtrl.text,
                      id: docId,
                      municipio: _municipioCtrl.text,
                      nombre: _nombreCtrl.text,
                      porcentaje: num.tryParse(_porcentajeCtrl.text),
                      slogan: _sloganCtrl.text.isNotEmpty
                          ? _sloganCtrl.text
                          : null,
                      fechaReferenciaMora: _fechaReferenciaMora,
                    );

                    await widget.onSave(model, docId, isEd);
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Actualizar' : 'Crear'),
        ),
      ],
    );
  }
}
