import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../mercados/presentation/widgets/map_picker_modal.dart';
import '../../data/models/local_model.dart';
import '../../domain/entities/local.dart';

Future<void> showLocalFormDialog(
  BuildContext context, {
  Local? local,
  String? initialMercadoId,
  VoidCallback? onSuccess,
}) async {
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
  final claveCtrl = TextEditingController(text: local?.clave ?? '');
  final codigoCatastralCtrl =
      TextEditingController(text: local?.codigoCatastral ?? '');

  String? selectedMercadoId = local?.mercadoId ?? initialMercadoId;
  String? selectedTipoNegocioId = local?.tipoNegocioId;
  String selectedFrecuenciaCobro = local?.frecuenciaCobro ?? 'diaria';

  await showDialog(
    context: context,
    builder: (ctx) {
      List<Map<String, double>>? temporalPerimetro = local?.perimetro;

      return Consumer(
        builder: (context, ref, child) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final currentMercs = ref.watch(mercadosProvider).value ?? [];
              List<Local> currentLocs = []; // Carga bajo demanda

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
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: representanteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Representante',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: codigoCatastralCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Código Local',
                                  helperText: 'Opcional, Búsqueda libre',
                                  helperStyle: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: claveCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Clave (Ej. 22-37-01-01)',
                                  helperText: 'Autogenerado si vacío',
                                  helperStyle: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                maxLength: 20,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ),
                          ],
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
                          items: ref
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
                        DropdownButtonFormField<String>(
                          initialValue: selectedFrecuenciaCobro,
                          decoration: const InputDecoration(
                            labelText: 'Preferencia de Pago / Frecuencia',
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'diaria', child: Text('Diaria')),
                            DropdownMenuItem(
                                value: 'semanal', child: Text('Semanal')),
                            DropdownMenuItem(
                                value: 'quincenal', child: Text('Quincenal')),
                            DropdownMenuItem(
                                value: 'mensual', child: Text('Mensual')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(
                                  () => selectedFrecuenciaCobro = v);
                            }
                          },
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
                          title: Text(
                            'Ubicar en Mapa / Perímetro',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            temporalPerimetro != null &&
                                    temporalPerimetro!.isNotEmpty
                                ? 'Vértices definidos: ${temporalPerimetro!.length}'
                                : 'Sin área definida en el mapa',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Icon(
                            Icons.map_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.24),
                          ),
                          onTap: () async {
                            // Cargar locales del mercado bajo demanda para el mapa
                            if (selectedMercadoId != null &&
                                currentLocs.isEmpty) {
                              setDialogState(() => currentLocs = []); 
                              final repo = ref.read(localRepositoryProvider);
                              final lits = await repo
                                  .obtenerPorMercado(selectedMercadoId!);
                              setDialogState(() => currentLocs = lits);
                            }

                            if (!context.mounted) return;

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

                            final List<LatLng>? result =
                                await showDialog<List<LatLng>>(
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
                                            (p) => LatLng(
                                                p['lat']!, p['lng']!),
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
                                      (l) =>
                                          LatLng(l.latitud!, l.longitud!),
                                    )
                                    .toList(),
                                initialCenter: temporalPerimetro != null &&
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
                                latitudCtrl.text =
                                    result.first.latitude.toString();
                                longitudCtrl.text =
                                    result.first.longitude.toString();
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
                      
                      // Para el cobrador usamos localApiProvider que es mas directo (o el mismo localDatasourceProvider de firebase)
                      // _showFormDialog usaba localDatasourceProvider que está en data, es lo mismo 
                      final ds = ref.read(localDatasourceProvider);
                      final now = DateTime.now();
                      
                      // Determinar usuario logueado en base al scope global
                      final currentUsuario = ref.read(currentUsuarioProvider).value;
                      final modificadoPor = currentUsuario?.id ?? 'admin';

                      final docId = isEditing
                          ? local.id!
                          : IdNormalizer.localId(
                              selectedMercadoId!,
                              nombreCtrl.text,
                            );

                      final selectedMerc = currentMercs.firstWhere(
                        (m) => m.id == selectedMercadoId,
                        orElse: () => currentMercs.first,
                      );

                      String generadaClave =
                          claveCtrl.text.trim().toUpperCase();
                      if (generadaClave.isEmpty &&
                          nombreCtrl.text.trim().isNotEmpty) {
                        // Tomar las primeras 3-4 letras
                        final cleanName =
                            nombreCtrl.text.trim().replaceAll(' ', '');
                        generadaClave = cleanName.length >= 4
                            ? cleanName.substring(0, 4).toUpperCase()
                            : cleanName.toUpperCase();
                      }

                      final model = LocalJson(
                        activo: isEditing ? (local.activo ?? true) : true,
                        actualizadoEn: now,
                        actualizadoPor: modificadoPor,
                        creadoEn: isEditing ? local.creadoEn : now,
                        creadoPor: isEditing ? local.creadoPor : modificadoPor,
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
                        clave: generadaClave.isNotEmpty ? generadaClave : null,
                        codigoCatastral: codigoCatastralCtrl.text.isNotEmpty
                            ? codigoCatastralCtrl.text
                            : null,
                        codigoCatastralLower:
                            codigoCatastralCtrl.text.isNotEmpty
                                ? codigoCatastralCtrl.text.toLowerCase()
                                : null,
                        frecuenciaCobro: selectedFrecuenciaCobro,
                        deudaAcumulada: isEditing ? local.deudaAcumulada : 0,
                        saldoAFavor: isEditing ? local.saldoAFavor : 0,
                      );

                      final jsonData = model.toJson();
                      jsonData['nombreSocialLower'] =
                          (nombreCtrl.text).toLowerCase();

                      if (isEditing) {
                        await ds.actualizar(docId, jsonData);
                      } else {
                        await ds.crear(docId, jsonData);
                      }

                      if (onSuccess != null) {
                        onSuccess();
                      }
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
