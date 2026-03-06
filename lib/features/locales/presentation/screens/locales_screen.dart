import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/id_normalizer.dart';
import '../../../../core/utils/qr_pdf_generator.dart';
import '../../data/models/local_model.dart';
import '../../domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../mercados/presentation/widgets/map_picker_modal.dart';
import '../viewmodels/locales_paginados_notifier.dart';

class LocalesScreen extends ConsumerStatefulWidget {
  const LocalesScreen({super.key});

  @override
  ConsumerState<LocalesScreen> createState() => _LocalesScreenState();
}

class _LocalesScreenState extends ConsumerState<LocalesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;
  Mercado? _mercadoSeleccionado;

  @override
  void initState() {
    super.initState();
    // Escucha el scroll para cargar la siguiente página.
    _scrollCtrl.addListener(_onScroll);
    // Carga inicial con municipalidad.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localesPaginadosProvider.notifier).recargar();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(localesPaginadosProvider.notifier).cargarSiguientePagina();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(localesPaginadosProvider.notifier).aplicarBusqueda(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paginacion = ref.watch(localesPaginadosProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildFiltros(context),
            const SizedBox(height: 16),
            Expanded(child: _buildContenido(context, paginacion)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final localesState = ref.watch(localesPaginadosProvider);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Locales Comerciales',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localesState.mercadoSeleccionadoId != null
                    ? '${localesState.locales.length} locales cargados · ${_mercadoSeleccionado?.nombre ?? "Mercado seleccionado"}'
                    : 'Selecciona un mercado para ver sus locales',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showFormDialog(context),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Agregar Local'),
        ),
      ],
    );
  }

  Widget _buildFiltros(BuildContext context) {
    final user = ref.watch(currentUsuarioProvider).value;
    final municipalidadId = user?.municipalidadId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Filtro Jerárquico: selector de mercado con búsqueda integrada.
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrar por Mercado',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownSearch<Mercado>(
                    asyncItems: (filter) async {
                      try {
                        final ds = ref.read(mercadoDatasourceProvider);
                        if (filter.isEmpty) {
                          // Sin texto: carga los primeros 30 del municipio.
                          final result = await ds.listarPagina(
                            municipalidadId: municipalidadId,
                            limit: 30,
                          );
                          return result.items
                              .map(
                                (m) => Mercado(
                                  id: m.id,
                                  nombre: m.nombre,
                                  ubicacion: m.ubicacion,
                                  latitud: m.latitud,
                                  longitud: m.longitud,
                                  perimetro: m.perimetro,
                                  activo: m.activo,
                                ),
                              )
                              .toList();
                        }
                        // Con texto: búsqueda por prefijo.
                        final resultados = await ds.buscarPorPrefijo(
                          prefijo: filter,
                          municipalidadId: municipalidadId,
                          limit: 15,
                        );
                        return resultados
                            .map(
                              (m) => Mercado(
                                id: m.id,
                                nombre: m.nombre,
                                ubicacion: m.ubicacion,
                                latitud: m.latitud,
                                longitud: m.longitud,
                                perimetro: m.perimetro,
                                activo: m.activo,
                              ),
                            )
                            .toList();
                      } catch (e) {
                        final text = e.toString();
                        final match = RegExp(
                          r'https://console\.firebase\.google\.com[^\s]+',
                        ).firstMatch(text);
                        if (match != null) {
                          print(
                            '\n\n🚨 FALTAN ÍNDICES EN FIRESTORE (MERCADOS) 🚨',
                          );
                          print(
                            '👇 ENLACE PARA CREARLOS 👇\n\n${match.group(0)}\n\n',
                          );
                        } else {
                          print(
                            '\n=== ERROR EN FIRESTORE ===\n$text\n==========================\n',
                          );
                        }
                        throw Exception(text);
                      }
                    },
                    itemAsString: (m) => m.nombre ?? m.id ?? '-',
                    compareFn: (a, b) => a.id == b.id,
                    selectedItem: _mercadoSeleccionado,
                    onChanged: (mercado) {
                      setState(() => _mercadoSeleccionado = mercado);
                      ref
                          .read(localesPaginadosProvider.notifier)
                          .seleccionarMercado(mercado);
                    },
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Buscar mercado...',
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                      menuProps: MenuProps(
                        backgroundColor:
                            Theme.of(context).cardTheme.color ??
                            const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 8,
                      ),
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
                      emptyBuilder: (ctx, text) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No se encontraron mercados',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        hintText: 'Todos los mercados',
                        prefixIcon: Icon(Icons.store_rounded, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Buscador por nombre de local (Autocomplete nativo - compatible con Web).
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buscar Local',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Autocomplete<Local>(
                    optionsBuilder: (textEditingValue) async {
                      final patron = textEditingValue.text;
                      if (patron.length < 2) return [];
                      final ds = ref.read(localDatasourceProvider);
                      final results = await ds.buscarPorPrefijo(
                        prefijo: patron,
                        mercadoId: _mercadoSeleccionado?.id,
                        municipalidadId: municipalidadId,
                        limit: 8,
                      );
                      return results.cast<Local>();
                    },
                    displayStringForOption: (local) => local.nombreSocial ?? '',
                    fieldViewBuilder:
                        (ctx, controller, focusNode, onFieldSubmitted) {
                          // Sincroniza controlador externo con el generado por Autocomplete
                          controller.addListener(() {
                            if (controller.text != _searchCtrl.text) {
                              _onSearchChanged(controller.text);
                            }
                          });
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Nombre del local...',
                              prefixIcon: Icon(Icons.search_rounded, size: 18),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          );
                        },
                    optionsViewBuilder: (ctx, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF1E2235),
                          child: SizedBox(
                            width: 350,
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (ctx, index) {
                                final local = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.storefront_rounded,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                  title: Text(
                                    local.nombreSocial ?? '-',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    local.representante ??
                                        local.mercadoId ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  onTap: () => onSelected(local),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (local) {
                      _debounce?.cancel();
                      ref
                          .read(localesPaginadosProvider.notifier)
                          .aplicarBusqueda(local.nombreSocial ?? '');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Botón de limpiar filtros.
            IconButton(
              onPressed: () {
                setState(() => _mercadoSeleccionado = null);
                _searchCtrl.clear();
                _debounce?.cancel();
                ref.read(localesPaginadosProvider.notifier).recargar();
              },
              icon: const Icon(Icons.filter_list_off_rounded),
              tooltip: 'Limpiar filtros',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido(BuildContext context, LocalesPaginadosState state) {
    if (state.errorMsg != null && state.locales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              state.errorMsg!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(localesPaginadosProvider.notifier).recargar(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.cargando && state.locales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.cargando &&
        state.locales.isEmpty &&
        state.mercadoSeleccionadoId == null) {
      return const _EmptyStateWidget(
        icon: Icons.store_mall_directory_rounded,
        mensaje:
            'Selecciona un mercado en el filtro superior\npara ver sus locales comerciales.',
      );
    }

    if (!state.cargando && state.locales.isEmpty) {
      return const _EmptyStateWidget(
        icon: Icons.search_off_rounded,
        mensaje: 'No se encontraron locales con esos filtros.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: _LocalesListView(
            locales: state.locales,
            scrollController: _scrollCtrl,
            onEdit: (l) => _showFormDialog(context, local: l),
            onViewQr: (l) => _showQrDialog(context, l),
          ),
        ),
        if (state.cargando && state.locales.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Cargando más...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        if (!state.hayMas && state.locales.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '✓ ${state.locales.length} locales cargados',
              style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ),
      ],
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
              final bytes = await QrPdfGenerator.generateLocalQrDocument(
                nombreLocal: local.nombreSocial ?? 'Local Comercial',
                qrData: local.id ?? '',
              );
              if (kIsWeb) {
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: 'QR_${local.nombreSocial ?? 'Local'}.pdf',
                );
              } else {
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name: 'QR_${local.nombreSocial ?? 'Local'}',
                );
              }
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

    String? selectedMercadoId = local?.mercadoId ?? _mercadoSeleccionado?.id;
    String? selectedTipoNegocioId = local?.tipoNegocioId;

    showDialog(
      context: context,
      builder: (ctx) {
        List<Map<String, double>>? temporalPerimetro = local?.perimetro;

        return Consumer(
          builder: (context, ref, child) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
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
                            value: selectedMercadoId,
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
                            value: selectedTipoNegocioId,
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

                        final jsonData = model.toJson();
                        // Añadir campo de búsqueda por prefijo al guardar.
                        jsonData['nombreSocialLower'] = (nombreCtrl.text)
                            .toLowerCase();

                        if (isEditing) {
                          await ds.actualizar(docId, jsonData);
                        } else {
                          await ds.crear(docId, jsonData);
                        }

                        ref.read(localesPaginadosProvider.notifier).recargar();
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

/// Vista de la lista de locales con scroll infinito.
class _LocalesListView extends ConsumerWidget {
  final List<Local> locales;
  final ScrollController scrollController;
  final ValueChanged<Local> onEdit;
  final ValueChanged<Local> onViewQr;

  const _LocalesListView({
    required this.locales,
    required this.scrollController,
    required this.onEdit,
    required this.onViewQr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final tipos = ref.watch(tiposNegocioProvider).value ?? [];

    return Card(
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 16,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(
              Colors.white.withOpacity(0.05),
            ),
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
                  DataCell(
                    Text(
                      l.nombreSocial ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
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

/// Widget de estado vacío reutilizable.
class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String mensaje;

  const _EmptyStateWidget({required this.icon, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: const TextStyle(color: Colors.white38, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
