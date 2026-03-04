import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../data/models/local_model.dart';
import '../../domain/entities/local.dart';

class LocalesScreen extends ConsumerStatefulWidget {
  const LocalesScreen({super.key});

  @override
  ConsumerState<LocalesScreen> createState() => _LocalesScreenState();
}

class _LocalesScreenState extends ConsumerState<LocalesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final locales = ref.watch(localesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LocalesHeader(
              onSearch: (q) => setState(() => _searchQuery = q),
              onAdd: () => _showFormDialog(context),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: locales.when(
                data: (list) {
                  final filtered = list
                      .where(
                        (l) =>
                            (l.nombreSocial ?? '').toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            (l.representante ?? '').toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron locales',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return _LocalesTable(
                    locales: filtered,
                    onEdit: (l) => _showFormDialog(context, local: l),
                    onViewQr: (l) => _showQrDialog(context, l),
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

  void _showQrDialog(BuildContext context, Local local) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(local.nombreSocial ?? 'QR del Local'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: local.id ?? 'sin-id',
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.Q,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ID: ${local.id}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cuota diaria: ${DateFormatter.formatCurrency(local.cuotaDiaria)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Representante: ${local.representante ?? '-'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showFormDialog(BuildContext context, {Local? local}) {
    final isEditing = local != null;
    final nombreCtrl = TextEditingController(text: local?.nombreSocial);
    final representanteCtrl = TextEditingController(text: local?.representante);
    final espacioCtrl = TextEditingController(
      text: local?.espacioM2?.toString() ?? '',
    );
    final cuotaCtrl = TextEditingController(
      text: local?.cuotaDiaria?.toString() ?? '',
    );

    final mercados = ref.read(mercadosProvider).value ?? [];
    final tiposNegocio = ref.read(tiposNegocioProvider).value ?? [];
    String? selectedMercadoId = local?.mercadoId;
    String? selectedTipoNegocioId = local?.tipoNegocioId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Local' : 'Nuevo Local'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Social',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: representanteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Representante',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMercadoId,
                    decoration: const InputDecoration(labelText: 'Mercado'),
                    items: mercados
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.nombre ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedMercadoId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTipoNegocioId,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Negocio',
                    ),
                    items: tiposNegocio
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.nombre ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedTipoNegocioId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: espacioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Espacio (m²)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cuotaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Cuota Diaria (L)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
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
                if (selectedMercadoId == null) return;
                final ds = ref.read(localDatasourceProvider);
                final now = DateTime.now();
                final docId = isEditing
                    ? local.id!
                    : IdNormalizer.localId(selectedMercadoId!, nombreCtrl.text);

                final model = LocalJson(
                  activo: true,
                  actualizadoEn: now,
                  actualizadoPor: 'admin',
                  creadoEn: isEditing ? local.creadoEn : now,
                  creadoPor: isEditing ? local.creadoPor : 'admin',
                  cuotaDiaria: num.tryParse(cuotaCtrl.text),
                  espacioM2: num.tryParse(espacioCtrl.text),
                  id: docId,
                  mercadoId: selectedMercadoId,
                  municipalidadId: mercados
                      .firstWhere((m) => m.id == selectedMercadoId)
                      .municipalidadId,
                  nombreSocial: nombreCtrl.text,
                  qrData: docId,
                  representante: representanteCtrl.text,
                  tipoNegocioId: selectedTipoNegocioId,
                );

                if (isEditing) {
                  await ds.actualizar(docId, model.toJson());
                } else {
                  await ds.crear(docId, model.toJson());
                }
                ref.invalidate(localesProvider);
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

class _LocalesHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _LocalesHeader({required this.onSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Locales',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestión de locales comerciales y generación de QR',
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

class _LocalesTable extends StatelessWidget {
  final List<Local> locales;
  final ValueChanged<Local> onEdit;
  final ValueChanged<Local> onViewQr;

  const _LocalesTable({
    required this.locales,
    required this.onEdit,
    required this.onViewQr,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Nombre Social')),
            DataColumn(label: Text('Representante')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('m²')),
            DataColumn(label: Text('Cuota Diaria')),
            DataColumn(label: Text('QR')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: locales.map((l) {
            return DataRow(
              cells: [
                DataCell(
                  Text(l.id ?? '-', style: const TextStyle(fontSize: 11)),
                ),
                DataCell(Text(l.nombreSocial ?? '-')),
                DataCell(Text(l.representante ?? '-')),
                DataCell(
                  Text(
                    l.tipoNegocioId ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(Text('${l.espacioM2 ?? 0}')),
                DataCell(Text(DateFormatter.formatCurrency(l.cuotaDiaria))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.qr_code_rounded, size: 20),
                    onPressed: () => onViewQr(l),
                    tooltip: 'Ver QR',
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => onEdit(l),
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
