import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../mercados/data/models/mercado_model.dart';
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
  final codigoCtrl = TextEditingController(text: local?.codigo ?? '');
  final codigoCatastralCtrl = TextEditingController(
    text: local?.codigoCatastral ?? '',
  );
  final diaCobroMensualCtrl = TextEditingController(
    text: local?.diaCobroMensual?.toString() ?? '',
  );

  String? selectedMercadoId = local?.mercadoId ?? initialMercadoId;
  String? selectedTipoNegocioId = local?.tipoNegocioId;
  final frecuenciaInicialRaw = (local?.frecuenciaCobro ?? 'diaria')
      .toLowerCase()
      .trim();
  String selectedFrecuenciaCobro = frecuenciaInicialRaw == 'mensual'
      ? 'mensual'
      : 'diaria';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (ctx) {
      List<Map<String, double>>? temporalPerimetro = local?.perimetro;

      return Consumer(
        builder: (context, ref, child) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final currentMercs = ref.watch(mercadosProvider).value ?? [];
              List<Local> currentLocs = []; // Carga bajo demanda

              final cs = Theme.of(context).colorScheme;

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: Column(
                  children: [
                    // Encabezado Fijo
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEditing
                                ? Icons.edit_rounded
                                : Icons.add_business_rounded,
                            size: 24,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing ? 'Editar Local' : 'Nuevo Local',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: cs.onSurface.withValues(alpha: 0.1),
                    ),
                    // Contenido Scroleable
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 20,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                controller: codigoCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Código Local',
                                  helperText: 'Opcional, Código interno',
                                  helperStyle: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
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
                                isExpanded: true,
                                initialValue: selectedMercadoId,
                                decoration: const InputDecoration(
                                  labelText: 'Mercado',
                                ),
                                items: currentMercs
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text(
                                          m.nombre ?? '-',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => selectedMercadoId = v),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
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
                                            child: Text(
                                              t.nombre ?? '-',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList() ??
                                    [],
                                onChanged: (v) => setDialogState(
                                  () => selectedTipoNegocioId = v,
                                ),
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
                                isExpanded: true,
                                initialValue: selectedFrecuenciaCobro,
                                decoration: const InputDecoration(
                                  labelText: 'Preferencia de Pago / Frecuencia',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'diaria',
                                    child: Text(
                                      'Diaria',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mensual',
                                    child: Text(
                                      'Mensual',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(
                                      () => selectedFrecuenciaCobro = v,
                                    );
                                  }
                                },
                              ),
                              if (selectedFrecuenciaCobro == 'mensual') ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: diaCobroMensualCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Día de cobro mensual (1-31)',
                                    helperText:
                                        'Se usa solo para referencia visual en la app del cobrador',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.24),
                                ),
                                onTap: () async {
                                  // Cargar locales del mercado bajo demanda para el mapa
                                  if (selectedMercadoId != null &&
                                      currentLocs.isEmpty) {
                                    setDialogState(() => currentLocs = []);
                                    final repo = ref.read(
                                      localRepositoryProvider,
                                    );
                                    final lits = await repo.obtenerPorMercado(
                                      selectedMercadoId!,
                                    );
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

                                  final List<LatLng>?
                                  result = await showDialog<List<LatLng>>(
                                    context: context,
                                    builder: (ctx) => MapPickerModal(
                                      mode: MapPickerMode.polygon,
                                      initialPoints: temporalPerimetro
                                          ?.map(
                                            (p) => LatLng(p['lat']!, p['lng']!),
                                          )
                                          .toList(),
                                      marketPerimeter: mercado.perimetro
                                          ?.map(
                                            (p) => LatLng(p['lat']!, p['lng']!),
                                          )
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
                                                    p['lat']!,
                                                    p['lng']!,
                                                  ),
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
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancelar'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () async {
                                        if (selectedMercadoId == null) return;

                                        // Para el cobrador usamos localApiProvider que es mas directo (o el mismo localDatasourceProvider de firebase)
                                        // _showFormDialog usaba localDatasourceProvider que está en data, es lo mismo
                                        final ds = ref.read(
                                          localDatasourceProvider,
                                        );
                                        final now = DateTime.now();

                                        // Determinar usuario logueado en base al scope global
                                        final currentUsuario = ref
                                            .read(currentUsuarioProvider)
                                            .value;
                                        final modificadoPor =
                                            currentUsuario?.id ?? 'admin';

                                        final docId = isEditing
                                            ? local.id!
                                            : IdNormalizer.localId(
                                                selectedMercadoId!,
                                                nombreCtrl.text,
                                              );

                                        final mercs = currentMercs
                                            .cast<MercadoJson>();
                                        final selectedMerc = mercs.firstWhere(
                                          (m) => m.id == selectedMercadoId,
                                          orElse: () => mercs.first,
                                        );

                                        String generadaClave = claveCtrl.text
                                            .trim()
                                            .toUpperCase();

                                        final model = LocalJson(
                                          activo: isEditing
                                              ? (local.activo ?? true)
                                              : true,
                                          actualizadoEn: now,
                                          actualizadoPor: modificadoPor,
                                          creadoEn: isEditing
                                              ? local.creadoEn
                                              : now,
                                          creadoPor: isEditing
                                              ? local.creadoPor
                                              : modificadoPor,
                                          cuotaDiaria: num.tryParse(
                                            cuotaCtrl.text,
                                          ),
                                          espacioM2: num.tryParse(
                                            espacioCtrl.text,
                                          ),
                                          id: docId,
                                          mercadoId: selectedMercadoId,
                                          municipalidadId:
                                              selectedMerc.municipalidadId,
                                          nombreSocial: nombreCtrl.text,
                                          qrData: docId,
                                          representante: representanteCtrl.text,
                                          telefonoRepresentante:
                                              telefonoCtrl.text,
                                          tipoNegocioId: selectedTipoNegocioId,
                                          latitud: double.tryParse(
                                            latitudCtrl.text,
                                          ),
                                          longitud: double.tryParse(
                                            longitudCtrl.text,
                                          ),
                                          perimetro: temporalPerimetro,
                                          clave: generadaClave.isNotEmpty
                                              ? generadaClave
                                              : null,
                                          codigoCatastral:
                                              codigoCatastralCtrl
                                                  .text
                                                  .isNotEmpty
                                              ? codigoCatastralCtrl.text
                                              : null,
                                          codigoCatastralLower:
                                              codigoCatastralCtrl
                                                  .text
                                                  .isNotEmpty
                                              ? codigoCatastralCtrl.text
                                                    .toLowerCase()
                                              : null,
                                          codigo: codigoCtrl.text.isNotEmpty
                                              ? codigoCtrl.text
                                              : null,
                                          codigoLower:
                                              codigoCtrl.text.isNotEmpty
                                              ? codigoCtrl.text.toLowerCase()
                                              : null,
                                          frecuenciaCobro:
                                              selectedFrecuenciaCobro,
                                          diaCobroMensual:
                                              selectedFrecuenciaCobro ==
                                                  'mensual'
                                              ? int.tryParse(
                                                  diaCobroMensualCtrl.text,
                                                )
                                              : null,
                                          deudaAcumulada: isEditing
                                              ? local.deudaAcumulada
                                              : 0,
                                          saldoAFavor: isEditing
                                              ? local.saldoAFavor
                                              : 0,
                                        );

                                        final jsonData = model.toJson();
                                        final diaMensual = int.tryParse(
                                          diaCobroMensualCtrl.text.trim(),
                                        );
                                        if (selectedFrecuenciaCobro ==
                                            'mensual') {
                                          if (diaMensual == null ||
                                              diaMensual < 1 ||
                                              diaMensual > 31) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Ingrese un día de cobro mensual válido (1-31).',
                                                  ),
                                                ),
                                              );
                                            }
                                            return;
                                          }
                                          jsonData['diaCobroMensual'] =
                                              diaMensual;
                                        } else {
                                          // Si cambia a frecuencia no mensual, limpiar dato anterior.
                                          jsonData['diaCobroMensual'] = null;
                                        }
                                        jsonData['nombreSocialLower'] =
                                            (nombreCtrl.text).toLowerCase();

                                        if (isEditing) {
                                          final deltaCuota =
                                              (model.cuotaDiaria ?? 0) -
                                              (local.cuotaDiaria ?? 0);
                                          await ds.actualizarConStats(
                                            localId: docId,
                                            data: jsonData,
                                            deltaCuota: deltaCuota,
                                          );
                                        } else {
                                          await ds.crear(docId, jsonData);
                                        }

                                        if (onSuccess != null) {
                                          onSuccess();
                                        }
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                      icon: const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        isEditing ? 'Actualizar' : 'Crear',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
