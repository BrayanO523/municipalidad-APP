import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../../core/utils/qr_pdf_generator.dart';
import '../../data/models/local_model.dart';
import '../../domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../mercados/presentation/widgets/map_picker_modal.dart';

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
          ElevatedButton.icon(
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (format) => QrPdfGenerator.generateLocalQrDocument(
                  nombreLocal: local.nombreSocial ?? 'Local Comercial',
                  qrData: local.id ?? '',
                ),
                name: 'QR_${local.nombreSocial ?? 'Local'}',
              );
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimir QR'),
          ),
        ],
      ),
    );
  }

  void _showFormDialog(BuildContext context, {Local? local}) {
    final isEditing = local != null;
    final nombreCtrl = TextEditingController(text: local?.nombreSocial);
    final representanteCtrl = TextEditingController(text: local?.representante);
    final telefonoCtrl = TextEditingController(
      text: local?.telefonoRepresentante,
    );
    final espacioCtrl = TextEditingController(
      text: local?.espacioM2?.toString() ?? '',
    );
    final cuotaCtrl = TextEditingController(
      text: local?.cuotaDiaria?.toString() ?? '',
    );
    final latitudCtrl = TextEditingController(
      text: local?.latitud?.toString() ?? '',
    );
    final longitudCtrl = TextEditingController(
      text: local?.longitud?.toString() ?? '',
    );

    // No usar ref.read aquí para listas que cambian, se usarán dentro del Consumer
    String? selectedMercadoId = local?.mercadoId;
    String? selectedTipoNegocioId = local?.tipoNegocioId;

    showDialog(
      context: context,
      builder: (ctx) {
        List<Map<String, double>>? temporalPerimetro = local?.perimetro;

        return Consumer(
          builder: (context, ref, child) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Observar mercados y locales de forma reactiva dentro del diálogo
                final currentMercs = ref.watch(mercadosProvider).value ?? [];
                final currentLocs = ref.watch(localesProvider).value ?? [];

                return AlertDialog(
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
                          TextField(
                            controller: telefonoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono Representante',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedMercadoId,
                            decoration: const InputDecoration(
                              labelText: 'Mercado',
                            ),
                            items: currentMercs
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
                            items:
                                ref
                                    .watch(tiposNegocioProvider)
                                    .value
                                    ?.map(
                                      (t) => DropdownMenuItem(
                                        value: t.id,
                                        child: Text(t.nombre ?? '-'),
                                      ),
                                    )
                                    .toList() ??
                                [],
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: latitudCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Latitud',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        signed: true,
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: longitudCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Longitud',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        signed: true,
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            tileColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            leading: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.redAccent,
                            ),
                            title: const Text(
                              'Ubicar en Mapa / Perímetro',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              temporalPerimetro != null &&
                                      temporalPerimetro!.isNotEmpty
                                  ? 'Vértices definidos: ${temporalPerimetro!.length}'
                                  : 'Sin área definida en el mapa',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.map_rounded,
                              color: Colors.white24,
                            ),
                            onTap: () async {
                              if (selectedMercadoId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Seleccione un mercado primero',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final Mercado? mercado = currentMercs
                                  .cast<Mercado?>()
                                  .firstWhere(
                                    (m) => m?.id == selectedMercadoId,
                                    orElse: () => null,
                                  );

                              if (mercado == null) return;

                              final otrosLocales = currentLocs
                                  .where(
                                    (l) =>
                                        l.mercadoId == selectedMercadoId &&
                                        l.id != local?.id,
                                  )
                                  .toList();

                              final List<LatLng>?
                              result = await showDialog<List<LatLng>>(
                                context: context,
                                builder: (ctx) => MapPickerModal(
                                  mode: MapPickerMode.polygon,
                                  initialPoints: temporalPerimetro
                                      ?.map((p) => LatLng(p['lat']!, p['lng']!))
                                      .toList(),
                                  marketPerimeter: mercado.perimetro
                                      ?.map((p) => LatLng(p['lat']!, p['lng']!))
                                      .toList(),
                                  existingPolygons: otrosLocales
                                      .where(
                                        (l) =>
                                            l.perimetro != null &&
                                            l.perimetro!.isNotEmpty,
                                      )
                                      .map(
                                        (l) => l.perimetro!
                                            .map(
                                              (p) =>
                                                  LatLng(p['lat']!, p['lng']!),
                                            )
                                            .toList(),
                                      )
                                      .toList(),
                                  existingPoints: otrosLocales
                                      .where(
                                        (l) =>
                                            l.perimetro == null ||
                                            l.perimetro!.isEmpty,
                                      )
                                      .where(
                                        (l) =>
                                            l.latitud != null &&
                                            l.longitud != null,
                                      )
                                      .map(
                                        (l) => LatLng(l.latitud!, l.longitud!),
                                      )
                                      .toList(),
                                  initialCenter:
                                      temporalPerimetro != null &&
                                          temporalPerimetro!.isNotEmpty
                                      ? LatLng(
                                          temporalPerimetro!.first['lat']!,
                                          temporalPerimetro!.first['lng']!,
                                        )
                                      : (mercado.latitud != null
                                            ? LatLng(
                                                mercado.latitud!,
                                                mercado.longitud!,
                                              )
                                            : null),
                                ),
                              );

                              if (result != null && result.isNotEmpty) {
                                setDialogState(() {
                                  temporalPerimetro = result
                                      .map(
                                        (p) => {
                                          'lat': p.latitude,
                                          'lng': p.longitude,
                                        },
                                      )
                                      .toList();
                                  latitudCtrl.text = result.first.latitude
                                      .toString();
                                  longitudCtrl.text = result.first.longitude
                                      .toString();
                                });
                              }
                            },
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
                            : IdNormalizer.localId(
                                selectedMercadoId!,
                                nombreCtrl.text,
                              );

                        final selectedMerc = currentMercs.firstWhere(
                          (m) => m.id == selectedMercadoId,
                        );

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
                          municipalidadId: selectedMerc.municipalidadId,
                          nombreSocial: nombreCtrl.text,
                          qrData: docId,
                          representante: representanteCtrl.text,
                          telefonoRepresentante: telefonoCtrl.text,
                          tipoNegocioId: selectedTipoNegocioId,
                          latitud: double.tryParse(latitudCtrl.text),
                          longitud: double.tryParse(longitudCtrl.text),
                          perimetro: temporalPerimetro,
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
                );
              },
            );
          },
        );
      },
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

class _LocalesTable extends ConsumerWidget {
  final List<Local> locales;
  final ValueChanged<Local> onEdit;
  final ValueChanged<Local> onViewQr;

  const _LocalesTable({
    required this.locales,
    required this.onEdit,
    required this.onViewQr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final tipos = ref.watch(tiposNegocioProvider).value ?? [];

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Local')),
              DataColumn(label: Text('Representante')),
              DataColumn(label: Text('Teléfono')),
              DataColumn(label: Text('Cobrador')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('m²')),
              DataColumn(label: Text('Cuota')),
              DataColumn(label: Text('Deuda')),
              DataColumn(label: Text('Saldo')),
              DataColumn(label: Text('QR')),
              DataColumn(label: Text('Hist.')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: locales.map((l) {
              final userName =
                  usuarios.any((u) => u.rutaAsignada?.contains(l.id) ?? false)
                  ? usuarios
                        .firstWhere(
                          (u) => u.rutaAsignada?.contains(l.id) ?? false,
                        )
                        .nombre
                  : 'Sin asignar';

              final tipoIndex = tipos.indexWhere(
                (t) => t.id == l.tipoNegocioId,
              );
              final strTipo = tipoIndex >= 0
                  ? (tipos[tipoIndex].nombre ?? l.tipoNegocioId ?? '-')
                  : (l.tipoNegocioId ?? '-');

              return DataRow(
                cells: [
                  DataCell(Text(l.nombreSocial ?? '-')),
                  DataCell(Text(l.representante ?? '-')),
                  DataCell(
                    Text(
                      l.telefonoRepresentante ?? '-',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  DataCell(Text(userName ?? 'Sin asignar')),
                  DataCell(Text(strTipo, style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${l.espacioM2 ?? 0}')),
                  DataCell(Text(DateFormatter.formatCurrency(l.cuotaDiaria))),
                  DataCell(
                    Text(
                      DateFormatter.formatCurrency(l.deudaAcumulada),
                      style: TextStyle(
                        color: (l.deudaAcumulada ?? 0) > 0
                            ? Colors.redAccent
                            : null,
                        fontWeight: (l.deudaAcumulada ?? 0) > 0
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      DateFormatter.formatCurrency(l.saldoAFavor),
                      style: TextStyle(
                        color: (l.saldoAFavor ?? 0) > 0
                            ? Colors.greenAccent
                            : null,
                        fontWeight: (l.saldoAFavor ?? 0) > 0
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.qr_code_rounded, size: 20),
                      onPressed: () => onViewQr(l),
                      tooltip: 'Ver QR',
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 18),
                      onPressed: () =>
                          context.push('/locales/${l.id}/historial', extra: l),
                      tooltip: 'Ver Historial',
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
      ),
    );
  }
}
