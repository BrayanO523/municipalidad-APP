import 'dart:async';
import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';

import '../../../../core/utils/qr_pdf_generator.dart';
import '../../../../core/widgets/scrollable_table.dart';
import '../../../../core/widgets/usuario_filter.dart';
import '../../../../core/platform/web_downloader/web_downloader.dart';

import '../../domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';

import '../viewmodels/locales_paginados_notifier.dart';
import '../widgets/local_form_dialog.dart';

const bool _kShowDevTools =
    kDebugMode || bool.fromEnvironment('DEV_TOOLS', defaultValue: false);

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
  Local? _localSeleccionado;
  bool _isExportingCsv = false;
  bool _isMigratingCodigo = false;

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

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moverSeleccion(1, paginacion.locales);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moverSeleccion(-1, paginacion.locales);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, outerConstraints) {
            final isMobilePadding = outerConstraints.maxWidth <= 700;
            return Padding(
              padding: isMobilePadding
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
                  : const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFiltros(context),
                  const SizedBox(height: 16),
                  Expanded(child: _buildContenido(context, paginacion)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _moverSeleccion(int delta, List<Local> localesActuales) {
    if (localesActuales.isEmpty) return;

    // Si no hay nada seleccionado y presionas una flecha, selecciona el primero
    if (_localSeleccionado == null) {
      if (delta > 0) {
        setState(() => _localSeleccionado = localesActuales.first);
      }
      return;
    }

    final currentIndex = localesActuales.indexWhere(
      (l) => l.id == _localSeleccionado!.id,
    );

    // Si por alguna razón el local seleccionado no está en la página actual o falla, seleccionamos el 0
    if (currentIndex == -1) {
      setState(() => _localSeleccionado = localesActuales.first);
      return;
    }

    final int nextIndex = currentIndex + delta;

    // Limitar al rango de la lista
    if (nextIndex >= 0 && nextIndex < localesActuales.length) {
      setState(() {
        _localSeleccionado = localesActuales[nextIndex];
      });
    }
  }

  Widget _buildFiltros(BuildContext context) {
    final user = ref.watch(currentUsuarioProvider).value;
    final municipalidadId = user?.municipalidadId;
    final state = ref.watch(localesPaginadosProvider);
    final notifier = ref.read(localesPaginadosProvider.notifier);

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet =
                constraints.maxWidth >= 650 && constraints.maxWidth < 1100;
            final isDesktop = constraints.maxWidth >= 1100;

            final bool showUsuario = !(user?.esCobrador ?? true);

            Widget infoPill(String text, {Color? color}) {
              final theme = Theme.of(context);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (color ?? theme.colorScheme.primaryContainer)
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              );
            }

            final header = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.store_mall_directory_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Locales comerciales',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                      ),
                      Text(
                        state.mercadoSeleccionadoId != null
                            ? 'Página ${state.paginaActual} · ${state.locales.length} locales'
                            : 'Selecciona un mercado para iniciar',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (state.locales.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: infoPill(
                      '${state.locales.length} locales',
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                  ),
                IconButton(
                  tooltip: 'Recargar',
                  iconSize: 20,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => notifier.recargar(),
                ),
                IconButton(
                  tooltip: 'Limpiar filtros',
                  iconSize: 20,
                  icon: const Icon(Icons.filter_list_off_rounded),
                  onPressed: () {
                    setState(() {
                      _mercadoSeleccionado = null;
                      _localSeleccionado = null;
                      _searchKey = UniqueKey();
                    });
                    _debounce?.cancel();
                    notifier.recargar();
                  },
                ),
              ],
            );

            final buttonsRow = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kIsWeb) ...[
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _isExportingCsv
                          ? null
                          : () => _exportarCsvWeb(context),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _isExportingCsv ? 'Exportando...' : 'Exportar CSV',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (_kShowDevTools && showUsuario) ...[
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _isMigratingCodigo
                          ? null
                          : () => _migrarCodigoLower(context),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        _isMigratingCodigo ? 'Migrando...' : 'Migrar',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: () => _showFormDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar'),
                  ),
                ),
              ],
            );

            Widget filterContent;

            if (isDesktop) {
              filterContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildMercadoDropdown(context, municipalidadId),
                      ),
                      const SizedBox(width: 8),
                      if (showUsuario) ...[
                        Expanded(
                          flex: 2,
                          child: _buildUsuarioFilter(context, state),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        flex: 3,
                        child: _buildLocalSearch(context, municipalidadId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildFiltroEstado(context, state), buttonsRow],
                  ),
                ],
              );
            } else if (isTablet) {
              filterContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildMercadoDropdown(context, municipalidadId),
                      ),
                      if (showUsuario) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _buildUsuarioFilter(context, state),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildLocalSearch(context, municipalidadId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [_buildFiltroEstado(context, state), buttonsRow],
                  ),
                ],
              );
            } else {
              // isMobile
              filterContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMercadoDropdown(context, municipalidadId),
                  const SizedBox(height: 8),
                  if (showUsuario) ...[
                    _buildUsuarioFilter(context, state),
                    const SizedBox(height: 8),
                  ],
                  _buildLocalSearch(context, municipalidadId),
                  const SizedBox(height: 8),
                  _buildFiltroEstado(context, state),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: buttonsRow,
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [header, const SizedBox(height: 12), filterContent],
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportarCsvWeb(BuildContext context) async {
    final semantic = context.semanticColors;
    if (!kIsWeb || _isExportingCsv) return;

    setState(() => _isExportingCsv = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando CSV de locales...')),
    );

    try {
      final locales = await ref
          .read(localesPaginadosProvider.notifier)
          .exportarLocalesFiltrados();

      final csv = _buildLocalesCsv(locales);
      final bytes = utf8.encode(csv);
      final now = DateTime.now();
      final y = now.year.toString();
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final filename = 'Locales_$y$m$d.csv';

      await descargarCsvWeb(bytes, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exportado: ${locales.length} locales'),
            backgroundColor: semantic.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar CSV: $e'),
            backgroundColor: semantic.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _migrarCodigoLower(BuildContext context) async {
    final semantic = context.semanticColors;
    if (_isMigratingCodigo) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrar códigos'),
        content: const Text(
          'Esto completará codigoLower para que el buscador por código funcione. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Migrar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isMigratingCodigo = true);
    try {
      final usuario = ref.read(currentUsuarioProvider).value;
      final municipalidadId = usuario?.municipalidadId;
      final ds = ref.read(localDatasourceProvider);
      final updated = await ds.migrarCodigoLower(
        municipalidadId: municipalidadId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migración completa: $updated locales actualizados'),
            backgroundColor: semantic.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al migrar códigos: '),
            backgroundColor: semantic.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMigratingCodigo = false);
    }
  }

  String _buildLocalesCsv(List<Local> locales) {
    final headers = [
      'id',
      'nombreSocial',
      'representante',
      'telefonoRepresentante',
      'mercadoId',
      'municipalidadId',
      'codigo',
      'clave',
      'codigoCatastral',
      'tipoNegocioId',
      'cuotaDiaria',
      'deudaAcumulada',
      'saldoAFavor',
      'frecuenciaCobro',
      'activo',
      'espacioM2',
      'latitud',
      'longitud',
      'creadoEn',
      'actualizadoEn',
      'perimetro',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final l in locales) {
      final values = [
        l.id,
        l.nombreSocial,
        l.representante,
        l.telefonoRepresentante,
        l.mercadoId,
        l.municipalidadId,
        l.codigo,
        l.clave,
        l.codigoCatastral,
        l.tipoNegocioId,
        l.cuotaDiaria,
        l.deudaAcumulada,
        l.saldoAFavor,
        l.frecuenciaCobro,
        l.activo,
        l.espacioM2,
        l.latitud,
        l.longitud,
        l.creadoEn?.toIso8601String(),
        l.actualizadoEn?.toIso8601String(),
        l.perimetro == null ? null : jsonEncode(l.perimetro),
      ];

      buffer.writeln(values.map(_csvEscape).join(','));
    }

    return buffer.toString();
  }

  String _csvEscape(Object? value) {
    if (value == null) return '';
    var text = value.toString();
    final needsQuotes =
        text.contains(',') || text.contains('\n') || text.contains('"');
    if (text.contains('"')) {
      text = text.replaceAll('"', '""');
    }
    return needsQuotes ? '"$text"' : text;
  }

  Widget _buildUsuarioFilter(
    BuildContext context,
    LocalesPaginadosState state,
  ) {
    return UsuarioFilter(
      selectedUsuarioId: state.usuarioFiltradoId,
      label: 'Cobrador',
      onUsuarioChanged: (u) {
        ref.read(localesPaginadosProvider.notifier).seleccionarUsuario(u?.id);
      },
    );
  }

  Widget _buildMercadoDropdown(BuildContext context, String? municipalidadId) {
    return DropdownSearch<Mercado>(
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
          debugPrint(
            '\n=== ERROR EN FIRESTORE ===\n$text\n==========================\n',
          );
          throw Exception(text);
        }
      },
      itemAsString: (m) => m.nombre ?? m.id ?? '-',
      compareFn: (a, b) => a.id == b.id,
      selectedItem: _mercadoSeleccionado,
      onChanged: (mercado) {
        setState(() => _mercadoSeleccionado = mercado);
        ref.read(localesPaginadosProvider.notifier).seleccionarMercado(mercado);
      },
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: const TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Buscar...',
            prefixIcon: Icon(Icons.search_rounded, size: 14),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
        menuProps: MenuProps(
          backgroundColor: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          elevation: 4,
        ),
        fit: FlexFit.loose,
        emptyBuilder: (ctx, text) => Padding(
          padding: const EdgeInsets.all(8),
          child: const Text('No encontrado', style: TextStyle(fontSize: 11)),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'Mercado',
          hintText: 'Todos',
          prefixIcon: const Icon(Icons.store_rounded, size: 16),
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        baseStyle: const TextStyle(fontSize: 13),
      ),
      clearButtonProps: const ClearButtonProps(isVisible: true),
    );
  }

  Widget _buildLocalSearch(BuildContext context, String? municipalidadId) {
    return Autocomplete<Local>(
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
      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
        // Escuchar cambios para filtrar la lista principal (DataTable)
        controller.addListener(() {
          // Sincronizamos con el buscador del provider
          _onSearchChanged(controller.text);
        });
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Buscar Local',
                hintText: 'Nombre, código o respresentante...',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          controller.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                    title: Text(
                      local.nombreSocial ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      local.representante ?? local.mercadoId ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
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
    );
  }

  Widget _buildFiltroEstado(BuildContext context, LocalesPaginadosState state) {
    return SegmentedButton<LocalFiltroDeuda>(
      segments: const [
        ButtonSegment(
          value: LocalFiltroDeuda.todos,
          label: Text('Todos'),
          icon: Icon(Icons.list_rounded, size: 16),
        ),
        ButtonSegment(
          value: LocalFiltroDeuda.soloDeudores,
          label: Text('Deudores'),
          icon: Icon(Icons.trending_down_rounded, size: 16),
        ),
        ButtonSegment(
          value: LocalFiltroDeuda.soloSaldosAFavor,
          label: Text('Saldos +'),
          icon: Icon(Icons.trending_up_rounded, size: 16),
        ),
      ],
      selected: {state.filtroDeuda},
      onSelectionChanged: (newSelection) {
        ref
            .read(localesPaginadosProvider.notifier)
            .cambiarFiltroDeuda(newSelection.first);
      },
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildContenido(BuildContext context, LocalesPaginadosState state) {
    if (state.errorMsg != null && state.locales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: context.semanticColors.danger,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              state.errorMsg!,
              style: TextStyle(color: context.semanticColors.danger),
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

    final Widget mainList = _LocalesListView(
      locales: state.locales,
      selectedLocalId: _localSeleccionado?.id,
      scrollController: _scrollCtrl,
      onSelect: (l) {
        final isWide = MediaQuery.of(context).size.width > 800;
        if (isWide) {
          setState(() {
            if (_localSeleccionado?.id == l.id) {
              _localSeleccionado = null;
            } else {
              _localSeleccionado = l;
            }
          });
        } else {
          // Móvil: mostrar detalle como bottom sheet
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollCtrl) => SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                child: _buildPanelDetalleContent(ctx, l),
              ),
            ),
          );
        }
      },
      onEdit: (l) => _showFormDialog(context, local: l),
      onViewQr: (l) => _showQrDialog(context, l),
      onDelete: (l) => _confirmDelete(context, l),
    );

    final Widget panelPaginacion = state.locales.isEmpty
        ? const SizedBox.shrink()
        : Padding(
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
                      ? () {
                          setState(() => _localSeleccionado = null);
                          ref
                              .read(localesPaginadosProvider.notifier)
                              .irAPaginaAnterior();
                        }
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
                      ? () {
                          setState(() => _localSeleccionado = null);
                          ref
                              .read(localesPaginadosProvider.notifier)
                              .irAPaginaSiguiente();
                        }
                      : null,
                  tooltip: 'Página siguiente',
                ),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 13, child: mainList),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  flex: 9,
                  child: Column(
                    children: [
                      Expanded(
                        child: _localSeleccionado != null
                            ? _buildPanelDetalle(context, _localSeleccionado!)
                            : const _PanelDetalleVacio(),
                      ),
                      panelPaginacion,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: mainList,
              ),
            ),
            panelPaginacion,
          ],
        );
      },
    );
  }

  Widget _buildPanelDetalle(BuildContext context, Local local) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final tipos = ref.watch(tiposNegocioProvider).value ?? [];

    final enRuta = usuarios.where(
      (u) => u.esCobrador && (u.rutaAsignada?.contains(local.id) ?? false),
    );

    String? cobradorNombre;
    if (enRuta.isNotEmpty) {
      cobradorNombre = enRuta.map((u) => u.nombre).join(', ');
    } else {
      final enMercado = usuarios
          .where((u) => u.esCobrador && u.mercadoId == local.mercadoId)
          .toList();
      if (enMercado.length == 1) {
        cobradorNombre = enMercado.first.nombre;
      }
    }

    final tipoIndex = tipos.indexWhere((t) => t.id == local.tipoNegocioId);
    final strTipo = tipoIndex >= 0
        ? (tipos[tipoIndex].nombre ?? local.tipoNegocioId ?? '-')
        : (local.tipoNegocioId ?? '-');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 200;
        final pd = compact ? 12.0 : 24.0;
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(pd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        local.nombreSocial ?? 'Detalles del Local',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_kShowDevTools)
                      IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: () =>
                            _showDebugDebtSaldoDialog(context, local),
                        tooltip: 'Debug: editar deuda y saldo',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          setState(() => _localSeleccionado = null),
                      tooltip: 'Cerrar detalle',
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          icon: Icons.person_rounded,
                          label: 'Representante',
                          value: local.representante ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.phone_rounded,
                          label: 'Teléfono',
                          value: local.telefonoRepresentante ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.badge_rounded,
                          label: 'Cobrador Asignado',
                          value: cobradorNombre ?? 'Sin asignar',
                        ),
                        _DetailRow(
                          icon: Icons.category_rounded,
                          label: 'Tipo de Negocio',
                          value: strTipo,
                        ),
                        _DetailRow(
                          icon: Icons.square_foot_rounded,
                          label: 'Espacio (m²)',
                          value: '${local.espacioM2 ?? 0}',
                        ),
                        _DetailRow(
                          icon: Icons.event_repeat_rounded,
                          label: 'Frecuencia de Cobro',
                          value: local.frecuenciaCobro ?? 'Diaria',
                        ),
                        if ((local.frecuenciaCobro ?? '').toLowerCase() ==
                            'mensual')
                          _DetailRow(
                            icon: Icons.calendar_month_rounded,
                            label: 'Día de Cobro Mensual',
                            value:
                                local.diaCobroMensual?.toString() ??
                                'No definido',
                          ),
                        _DetailRow(
                          icon: Icons.vpn_key_rounded,
                          label: 'Clave',
                          value: local.clave ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.map_rounded,
                          label: 'Código Local',
                          value: local.codigo ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Creado En',
                          value: local.creadoEn != null
                              ? DateFormatter.formatDate(local.creadoEn!)
                              : '-',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Versión "flat" del panel de detalle (sin Expanded) — para bottom sheet en móvil.
  Widget _buildPanelDetalleContent(BuildContext context, Local local) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final tipos = ref.watch(tiposNegocioProvider).value ?? [];

    final enRuta = usuarios.where(
      (u) => u.esCobrador && (u.rutaAsignada?.contains(local.id) ?? false),
    );

    String? cobradorNombre;
    if (enRuta.isNotEmpty) {
      cobradorNombre = enRuta.map((u) => u.nombre).join(', ');
    } else {
      final enMercado = usuarios
          .where((u) => u.esCobrador && u.mercadoId == local.mercadoId)
          .toList();
      if (enMercado.length == 1) {
        cobradorNombre = enMercado.first.nombre;
      }
    }

    final tipoIndex = tipos.indexWhere((t) => t.id == local.tipoNegocioId);
    final strTipo = tipoIndex >= 0
        ? (tipos[tipoIndex].nombre ?? local.tipoNegocioId ?? '-')
        : (local.tipoNegocioId ?? '-');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          local.nombreSocial ?? 'Detalles del Local',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Divider(height: 24),
        if (_kShowDevTools) ...[
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showDebugDebtSaldoDialog(context, local),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Debug: editar deuda/saldo'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _DetailRow(
          icon: Icons.person_rounded,
          label: 'Representante',
          value: local.representante ?? '-',
        ),
        _DetailRow(
          icon: Icons.phone_rounded,
          label: 'Teléfono',
          value: local.telefonoRepresentante ?? '-',
        ),
        _DetailRow(
          icon: Icons.badge_rounded,
          label: 'Cobrador Asignado',
          value: cobradorNombre ?? 'Sin asignar',
        ),
        _DetailRow(
          icon: Icons.category_rounded,
          label: 'Tipo de Negocio',
          value: strTipo,
        ),
        _DetailRow(
          icon: Icons.square_foot_rounded,
          label: 'Espacio (m²)',
          value: '${local.espacioM2 ?? 0}',
        ),
        _DetailRow(
          icon: Icons.event_repeat_rounded,
          label: 'Frecuencia de Cobro',
          value: local.frecuenciaCobro ?? 'Diaria',
        ),
        if ((local.frecuenciaCobro ?? '').toLowerCase() == 'mensual')
          _DetailRow(
            icon: Icons.calendar_month_rounded,
            label: 'Día de Cobro Mensual',
            value: local.diaCobroMensual?.toString() ?? 'No definido',
          ),
        _DetailRow(
          icon: Icons.vpn_key_rounded,
          label: 'Clave',
          value: local.clave ?? '-',
        ),
        _DetailRow(
          icon: Icons.map_rounded,
          label: 'Código Local',
          value: local.codigo ?? '-',
        ),
        _DetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Creado En',
          value: local.creadoEn != null
              ? DateFormatter.formatDate(local.creadoEn!)
              : '-',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: context.semanticColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final usuario = ref.read(currentUsuarioProvider).value;
      final ds = ref.read(localDatasourceProvider);
      await ds.eliminar(local.id!, municipalidadId: usuario?.municipalidadId);
      ref.read(localesPaginadosProvider.notifier).recargar();
    }
  }

  void _showFormDialog(BuildContext context, {Local? local}) {
    showLocalFormDialog(
      context,
      local: local,
      initialMercadoId: _mercadoSeleccionado?.id,
      onSuccess: () {
        ref.read(localesPaginadosProvider.notifier).recargar();
      },
    );
  }

  Future<void> _showDebugDebtSaldoDialog(
    BuildContext context,
    Local local,
  ) async {
    if (!_kShowDevTools || local.id == null) return;

    final deudaActual = (local.deudaAcumulada ?? 0).toDouble();
    final saldoActual = (local.saldoAFavor ?? 0).toDouble();
    final deudaCtrl = TextEditingController(
      text: deudaActual.toStringAsFixed(2),
    );
    final saldoCtrl = TextEditingController(
      text: saldoActual.toStringAsFixed(2),
    );

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Debug: editar deuda y saldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deudaCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Deuda acumulada',
                prefixIcon: Icon(Icons.trending_down_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: saldoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Saldo a favor',
                prefixIcon: Icon(Icons.trending_up_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final nuevaDeuda = _parseDecimalInput(deudaCtrl.text);
    final nuevoSaldo = _parseDecimalInput(saldoCtrl.text);

    if (nuevaDeuda == null ||
        nuevoSaldo == null ||
        nuevaDeuda < 0 ||
        nuevoSaldo < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Valores invalidos: usa numeros >= 0.'),
            backgroundColor: context.semanticColors.danger,
          ),
        );
      }
      return;
    }

    final deltaDeuda = nuevaDeuda - deudaActual;
    final deltaSaldo = nuevoSaldo - saldoActual;
    final ds = ref.read(localDatasourceProvider);

    try {
      await ds.actualizarConStats(
        localId: local.id!,
        data: {
          'deudaAcumulada': nuevaDeuda,
          'saldoAFavor': nuevoSaldo,
          if (local.municipalidadId != null)
            'municipalidadId': local.municipalidadId,
          if (local.mercadoId != null) 'mercadoId': local.mercadoId,
          'ajusteDebugManual': true,
        },
        deltaDeuda: deltaDeuda,
        deltaSaldo: deltaSaldo,
      );

      ref.read(localesPaginadosProvider.notifier).recargar();
      if (_localSeleccionado?.id == local.id) {
        setState(() {
          _localSeleccionado = _localSeleccionado?.copyWith(
            deudaAcumulada: nuevaDeuda,
            saldoAFavor: nuevoSaldo,
          );
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deuda y saldo actualizados (debug).'),
            backgroundColor: context.semanticColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: context.semanticColors.danger,
          ),
        );
      }
    }
  }

  double? _parseDecimalInput(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}

/// Vista de la lista de locales con scroll infinito.
class _LocalesListView extends ConsumerWidget {
  final List<Local> locales;
  final String? selectedLocalId;
  final ScrollController scrollController;
  final ValueChanged<Local> onSelect;
  final ValueChanged<Local> onEdit;
  final ValueChanged<Local> onViewQr;
  final ValueChanged<Local> onDelete;

  const _LocalesListView({
    required this.locales,
    this.selectedLocalId,
    required this.scrollController,
    required this.onSelect,
    required this.onEdit,
    required this.onViewQr,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagadosHoy = ref.watch(localesPaginadosProvider).localesPagadosHoy;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ScrollableTable(
        verticalController: scrollController,
        child: DataTable(
          showCheckboxColumn:
              false, // Desactiva la columna de checkboxes por defecto
          horizontalMargin: 16,
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          ),
          columns: const [
            DataColumn(label: Text('Local')),
            DataColumn(label: Text('Cuota')),
            DataColumn(label: Text('Deuda')),
            DataColumn(label: Text('Saldo')),
            DataColumn(label: Text('QR')),
            DataColumn(label: Text('Hist.')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: locales.map((l) {
            final isSelected = selectedLocalId == l.id;

            return DataRow(
              selected: isSelected,
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15);
                }
                return null;
              }),
              onSelectChanged: (selected) {
                onSelect(l);
              },
              cells: [
                DataCell(
                  Text(
                    l.nombreSocial ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(Text(DateFormatter.formatCurrency(l.cuotaDiaria))),
                DataCell(
                  Builder(
                    builder: (context) {
                      final pagadoHoy = pagadosHoy[l.id] ?? false;
                      final tieneSaldo =
                          (l.saldoAFavor ?? 0) >= (l.cuotaDiaria ?? 0);
                      final num deudaVisual =
                          (l.deudaAcumulada ?? 0) +
                          (!pagadoHoy && !tieneSaldo
                              ? (l.cuotaDiaria ?? 0)
                              : 0);

                      return Text(
                        DateFormatter.formatCurrency(deudaVisual),
                        style: TextStyle(
                          color: deudaVisual > 0
                              ? context.semanticColors.danger
                              : null,
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
                          ? context.semanticColors.success
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () {
                          if (!isSelected) onSelect(l);
                          onEdit(l);
                        },
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_rounded,
                          size: 18,
                          color: context.semanticColors.danger,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
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

class _PanelDetalleVacio extends StatelessWidget {
  const _PanelDetalleVacio();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona un local de la tabla\npara ver su información completa.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
