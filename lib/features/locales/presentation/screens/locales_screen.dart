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
import '../../../../core/widgets/scrollable_table.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';
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
  Key _searchKey = UniqueKey();
  Timer? _debounce;
  Mercado? _mercadoSeleccionado;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(localesPaginadosProvider.notifier).aplicarBusqueda(value);
    });
  }

  @override
  void initState() {
    super.initState();
    // Carga inicial con municipalidad.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localesPaginadosProvider.notifier).recargar();
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
    final paginacion = ref.watch(localesPaginadosProvider);
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
                paginacion.mercadoSeleccionadoId != null
                    ? 'Página ${paginacion.paginaActual} · ${paginacion.locales.length} locales mostrados'
                    : 'Selecciona un mercado para ver sus locales',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
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
                            Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        elevation: 8,
                      ),
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
                      emptyBuilder: (ctx, text) => Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No se encontraron mercados',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.54),
                          ),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Autocomplete<Local>(
                    key: _searchKey,
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
                          // Escuchar cambios para filtrar la lista principal (DataTable)
                          controller.addListener(() {
                            // Sincronizamos con el buscador del provider
                            _onSearchChanged(controller.text);
                          });
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Nombre o Código local...',
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
                          color: Theme.of(context).colorScheme.surface,
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
                                  leading: Icon(
                                    Icons.storefront_rounded,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54),
                                  ),
                                  title: Text(
                                    local.nombreSocial ?? '-',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    local.representante ??
                                        local.mercadoId ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
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
                setState(() {
                  _mercadoSeleccionado = null;
                  _searchKey = UniqueKey(); // Fuerza reset del Autocomplete UI
                });
                _debounce?.cancel();
                ref.read(localesPaginadosProvider.notifier).recargar();
              },
              icon: const Icon(Icons.filter_list_off_rounded),
              tooltip: 'Limpiar filtros',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
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
            onDelete: (l) => _confirmDelete(context, l),
          ),
        ),
        if (state.locales.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (state.cargando)
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
                  onPressed: (!state.cargando && state.paginaActual > 1)
                      ? () => ref
                          .read(localesPaginadosProvider.notifier)
                          .irAPaginaAnterior()
                      : null,
                  tooltip: 'Página anterior',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Página ${state.paginaActual}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: (!state.cargando && state.hayMas)
                      ? () => ref
                          .read(localesPaginadosProvider.notifier)
                          .irAPaginaSiguiente()
                      : null,
                  tooltip: 'Página siguiente',
                ),
              ],
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
                  color: Theme.of(context).colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: local.id ?? 'sin-id',
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
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
                await descargarPdfWeb(
                  bytes,
                  'QR_${local.nombreSocial ?? 'Local'}.pdf',
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

  void _confirmDelete(BuildContext context, Local local) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Local'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el local "${local.nombreSocial}"?\n\nEsta acción NO se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ds = ref.read(localDatasourceProvider);
      await ds.eliminar(local.id!);
      ref.read(localesPaginadosProvider.notifier).recargar();
    }
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
    final claveCtrl = TextEditingController(text: local?.clave ?? '');
    final codigoCatastralCtrl = TextEditingController(text: local?.codigoCatastral ?? '');

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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
                                fontSize: 11,
                              ),
                            ),
                            trailing: Icon(
                              Icons.map_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.24),
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

                        String generadaClave = claveCtrl.text
                            .trim()
                            .toUpperCase();
                        if (generadaClave.isEmpty &&
                            nombreCtrl.text.trim().isNotEmpty) {
                          // Tomar las primeras 3-4 letras, quitar espacios y hacer mayúscula
                          final cleanName = nombreCtrl.text.trim().replaceAll(
                            ' ',
                            '',
                          );
                          generadaClave = cleanName.length >= 4
                              ? cleanName.substring(0, 4).toUpperCase()
                              : cleanName.toUpperCase();
                        }

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
                          clave: generadaClave.isNotEmpty
                              ? generadaClave
                              : null,
                          codigoCatastral: codigoCatastralCtrl.text.isNotEmpty 
                              ? codigoCatastralCtrl.text 
                              : null,
                          codigoCatastralLower: codigoCatastralCtrl.text.isNotEmpty 
                              ? codigoCatastralCtrl.text.toLowerCase() 
                              : null,
                        );

                        final jsonData = model.toJson();
                        // Añadir campo de búsqueda por prefijo al guardar. (Redundante pero seguro por compatibilidad)
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
  final ValueChanged<Local> onDelete;

  const _LocalesListView({
    required this.locales,
    required this.scrollController,
    required this.onEdit,
    required this.onViewQr,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagadosHoy = ref.watch(localesPaginadosProvider).localesPagadosHoy;
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final tipos = ref.watch(tiposNegocioProvider).value ?? [];

    return Card(
      child: ScrollableTable(
        verticalController: scrollController,
        child: DataTable(
          horizontalMargin: 16,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
          ),
          columns: const [
            DataColumn(label: Text('Local')),
            DataColumn(label: Text('Código Local')),
            DataColumn(label: Text('Clave')),
            DataColumn(label: Text('Representante')),
            DataColumn(label: Text('Teléfono')),
            DataColumn(label: Text('Cobrador')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('m²')),
            DataColumn(label: Text('Cuota')),
            DataColumn(label: Text('Deuda')),
            DataColumn(label: Text('Saldo')),
            DataColumn(label: Text('Creación')),
            DataColumn(label: Text('QR')),
            DataColumn(label: Text('Hist.')),
            DataColumn(label: Text('Acciones')),
          ],
            rows: locales.map((l) {
              // Buscar si hay algún cobrador asignado por Mercado o por Ruta
              // Lógica de asignación: Priorizar Ruta > Mercado (si es único)
              final enRuta = usuarios.where(
                (u) =>
                    u.esCobrador && (u.rutaAsignada?.contains(l.id) ?? false),
              );

              String? cobradorNombre;
              if (enRuta.isNotEmpty) {
                // Si el local está en rutas específicas, mostramos esos nombres
                cobradorNombre = enRuta.map((u) => u.nombre).join(', ');
              } else {
                // Si no hay ruta específica, verificamos los del mercado
                final enMercado = usuarios
                    .where(
                      (u) =>
                          u.esCobrador &&
                          u.mercadoId != null &&
                          u.mercadoId == l.mercadoId,
                    )
                    .toList();

                // REGLA: Solo mostrar si hay EXACTAMENTE UNO asignado al mercado completo.
                // Si hay más de uno, la asignación es ambigua (cada uno tiene su propia ruta).
                if (enMercado.length == 1) {
                  cobradorNombre = enMercado.first.nombre;
                }
              }

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
                  DataCell(
                    Text(
                      l.codigoCatastral ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      l.clave ?? '-',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(Text(l.representante ?? '-')),
                  DataCell(
                    Text(
                      l.telefonoRepresentante ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  DataCell(
                    cobradorNombre != null
                        ? Text(cobradorNombre)
                        : Text(
                            'Sin asignar',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.38),
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  DataCell(Text(strTipo, style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${l.espacioM2 ?? 0}')),
                  DataCell(Text(DateFormatter.formatCurrency(l.cuotaDiaria))),
                  DataCell(
                    Builder(
                      builder: (context) {
                        final pagadoHoy = pagadosHoy[l.id] ?? false;
                        final tieneSaldo = (l.saldoAFavor ?? 0) >= (l.cuotaDiaria ?? 0);
                        final num deudaVisual =
                            (l.deudaAcumulada ?? 0) +
                            (!pagadoHoy && !tieneSaldo ? (l.cuotaDiaria ?? 0) : 0);

                        return Text(
                          DateFormatter.formatCurrency(deudaVisual),
                          style: TextStyle(
                            color: deudaVisual > 0 ? Colors.redAccent : null,
                            fontWeight: deudaVisual > 0 ? FontWeight.bold : null,
                          ),
                        );
                      },
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
                    Text(
                      l.creadoEn != null
                          ? DateFormatter.formatDate(l.creadoEn!)
                          : '-',
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          onPressed: () => onEdit(l),
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => onDelete(l),
                          tooltip: 'Eliminar',
                        ),
                      ],
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
          Icon(
            icon,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
