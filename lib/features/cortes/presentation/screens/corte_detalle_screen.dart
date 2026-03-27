import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/corte.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

import 'package:go_router/go_router.dart';
import '../viewmodels/cortes_paginados_notifier.dart';

// Definicion de tipo para mayor claridad
typedef CobroConDetalle = ({
  Cobro cobro,
  String localNombre,
  String? localCodigo,
  String? localClave,
  num? cuotaDiaria,
  String? ruta,
  String? frecuenciaCobro,
  num? saldoAFavor,
  num? deudaAcumulada,
  String? representante,
  String? telefono,
});

final cobrosPorCorteProvider =
    FutureProvider.family<List<CobroConDetalle>, List<String>>((
      ref,
      ids,
    ) async {
      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);

      final cobros = await cobroDs.listarPorIds(ids);
      if (cobros.isEmpty) return [];

      final uniqueLocalIds = cobros
          .map((c) => c.localId)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final locales = await localDs.listarPorIds(uniqueLocalIds);
      final Map<String, Local> localMap = {for (var l in locales) l.id!: l};

      return cobros.map((c) {
        final loc = c.localId != null ? localMap[c.localId] : null;
        return (
          cobro: c,
          localNombre: loc?.nombreSocial ?? (c.localId ?? 'ID Desconocido'),
          localCodigo: loc?.codigo,
          localClave: loc?.clave ?? loc?.codigoCatastral,
          cuotaDiaria: loc?.cuotaDiaria,
          ruta: loc?.ruta,
          frecuenciaCobro: loc?.frecuenciaCobro,
          saldoAFavor: loc?.saldoAFavor,
          deudaAcumulada: loc?.deudaAcumulada,
          representante: loc?.representante,
          telefono: loc?.telefonoRepresentante,
        );
      }).toList();
    });

class CorteDetalleScreen extends ConsumerWidget {
  final Corte corte;

  const CorteDetalleScreen({super.key, required this.corte});

  static bool _esMovimiento(Cobro cobro) {
    final estado = (cobro.estado ?? '').toLowerCase();
    return (cobro.monto ?? 0) > 0 ||
        (cobro.pagoACuota ?? 0) > 0 ||
        (cobro.montoAbonadoDeuda ?? 0) > 0 ||
        estado == 'cobrado_saldo';
  }

  Future<void> _confirmarEliminacion(
    BuildContext context,
    WidgetRef ref,
    Corte corte,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Corte'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este registro de corte? Esta acción no afectará los cobros individuales registrados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.semanticColors.danger,
              foregroundColor: context.semanticColors.onDanger,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final repo = ref.read(corteRepositoryProvider);
      final result = await repo.eliminarCorte(corte.id);

      if (context.mounted) {
        Navigator.of(context).pop(); // Quitar loading
      }

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${failure.message}')),
            );
          }
        },
        (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Corte eliminado correctamente.')),
            );
            ref.invalidate(cortesAdminPaginadosProvider);
            ref.invalidate(cortesCobradorPaginadosProvider);
            context.pop();
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosAsync = ref.watch(cobrosPorCorteProvider(corte.cobrosIds));
    final DateFormat formatter = DateFormat(
      'EEEE, d MMMM yyyy, hh:mm a',
      'es_ES',
    );
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isWide = viewportWidth > 800;
    final horizontalPadding = viewportWidth >= 1200 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Detalle de Corte'),
        centerTitle: true,
        elevation: 0,
        actions: [
          cobrosAsync.when(
            data: (items) => IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => PdfGenerator.printCorte(
                corte,
                items.map((item) => item.cobro).toList(),
                localInfo: {
                  for (var item in items)
                    if (item.cobro.localId != null)
                      item.cobro.localId!: {
                        'nombre': item.localNombre,
                        if (item.localCodigo != null)
                          'codigo': item.localCodigo!,
                        if (item.localClave != null) 'clave': item.localClave!,
                      },
                },
              ),
              tooltip: 'Exportar PDF',
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          if (kIsWeb)
            IconButton(
              icon: Icon(Icons.delete_outline, color: semantic.danger),
              tooltip: 'Eliminar Corte',
              onPressed: () => _confirmarEliminacion(context, ref, corte),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header Card
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            sliver: SliverToBoxAdapter(
              child: _HeaderCard(
                corte: corte,
                formatter: formatter,
                isWide: isWide,
              ),
            ),
          ),

          // Contenido de boletas
          cobrosAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('No hay detalles de cobros.'),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final cobrados = items
                  .where((i) => _esMovimiento(i.cobro))
                  .toList();

              final totalCobrados = cobrados.fold<double>(
                0,
                (s, i) => s + (i.cobro.monto ?? 0).toDouble(),
              );

              return SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Titulo seccion
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Desglose de Boletas',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cobrados (estilo similar a pendientes)
                    if (cobrados.isNotEmpty) ...[
                      _CobradosInfoSection(
                        cobrados: cobrados,
                        subtotal: totalCobrados,
                        color: AppColors.success,
                        icon: Icons.check_circle,
                        gestionesInfo: corte.gestionesInfo ?? const [],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Gestiones/Incidencias (desde gestionesInfo del corte)
                    if (corte.gestionesInfo != null &&
                        corte.gestionesInfo!.isNotEmpty) ...[
                      _GestionesInfoSection(
                        gestionesInfo: corte.gestionesInfo!,
                        color: semantic.warning,
                        icon: Icons.assignment_late_rounded,
                        isWide: isWide,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Pendientes (desde pendientesInfo del corte)
                    if (corte.pendientesInfo != null &&
                        corte.pendientesInfo!.isNotEmpty) ...[
                      _PendientesInfoSection(
                        pendientesInfo: corte.pendientesInfo!,
                        gestionesInfo: corte.gestionesInfo ?? const [],
                        color: AppColors.warning,
                        icon: Icons.schedule,
                        isWide: isWide,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Total general
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.6,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.summarize_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'TOTAL GENERAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(corte.totalCobrado),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error al cargar cobros: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

// Header Card con gradiente
class _HeaderCard extends StatelessWidget {
  final Corte corte;
  final DateFormat formatter;
  final bool isWide;

  const _HeaderCard({
    required this.corte,
    required this.formatter,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final semantic = context.semanticColors;
    final totalPendiente =
        (corte.pendientesInfo ?? const <Map<String, dynamic>>[]).fold<double>(
          0,
          (sum, info) =>
              sum + ((info['montoPendiente'] as num?)?.toDouble() ?? 0),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar + nombre
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  corte.esCorteMercado
                      ? Icons.store_mall_directory_rounded
                      : Icons.person_rounded,
                  color: onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      corte.esCorteMercado
                          ? (corte.mercadoNombre ?? 'Corte de Mercado')
                          : corte.cobradorNombre,
                      style: TextStyle(
                        color: onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      corte.esCorteMercado
                          ? 'Consolidado por ${corte.cobradorNombre}'
                          : (corte.mercadoNombre != null
                                ? 'Mercado: ${corte.mercadoNombre}'
                                : 'Cobrador Responsable'),
                      style: TextStyle(
                        color: onPrimary.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Estadisticas principales
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: onPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Total Recaudado',
                            style: TextStyle(
                              color: onPrimary.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(corte.totalCobrado),
                            style: TextStyle(
                              color: onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 46,
                      color: onPrimary.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Total Pendiente',
                            style: TextStyle(
                              color: onPrimary.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(totalPendiente),
                            style: TextStyle(
                              color: onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _MiniStat(
                      icon: Icons.check_circle,
                      value: '${corte.cantidadCobrados ?? '-'}',
                      label: 'Cobrados',
                      color: semantic.success,
                    ),
                    _MiniStat(
                      icon: Icons.schedule,
                      value: '${corte.cantidadPendientes ?? '-'}',
                      label: 'Pendientes',
                      color: semantic.warning,
                    ),
                    if (corte.gestionesInfo != null &&
                        corte.gestionesInfo!.isNotEmpty)
                      _MiniStat(
                        icon: Icons.assignment_late_rounded,
                        value: '${corte.gestionesInfo!.length}',
                        label: 'Incidencias',
                        color: semantic.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Desglose Mora / Corriente
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: semantic.success.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.trending_up,
                          color: onPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Corriente',
                            style: TextStyle(
                              color: onPrimary.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(corte.totalCorriente ?? 0),
                            style: TextStyle(
                              color: onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: semantic.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.warning_amber,
                          color: onPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mora',
                            style: TextStyle(
                              color: onPrimary.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(corte.totalMora ?? 0),
                            style: TextStyle(
                              color: onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: onPrimary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                formatter.format(corte.fechaCorte),
                style: TextStyle(
                  color: onPrimary.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: onPrimary.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// Seccion de boletas: elige automaticamente entre tabla (desktop)
// y cards compactos (movil).
//
//
// ignore: unused_element
class _BoletasSection extends StatelessWidget {
  final String titulo;
  final Color color;
  final List<CobroConDetalle> items;
  final double subtotal;
  final IconData icon;
  final bool isWide;

  const _BoletasSection({
    required this.titulo,
    required this.color,
    required this.items,
    required this.subtotal,
    required this.icon,
    required this.isWide,
  });

  static bool _esCobrado(Cobro cobro) {
    final estado = (cobro.estado ?? '').toLowerCase();
    return estado == 'cobrado' || estado == 'cobrado_saldo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header de seccion
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // Contenido adaptativo: tabla en desktop, cards en movil
          if (isWide) _buildDesktopTable(theme) else _buildMobileCards(theme),

          // Subtotal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SUBTOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(subtotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vista desktop: DataTable completa
  Widget _buildDesktopTable(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 14,
        headingRowHeight: 40,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 46,
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('BOLETA')),
          DataColumn(label: Text('LOCAL')),
          DataColumn(label: Text('MONTO'), numeric: true),
          DataColumn(label: Text('ESTADO')),
        ],
        rows: List.generate(items.length, (i) {
          final item = items[i];
          final cobro = item.cobro;
          final estado = (cobro.estado ?? '').toLowerCase();
          final esCobrado = _esCobrado(cobro);
          final esAbonoParcial = estado == 'abono_parcial';
          final statusColor = esCobrado
              ? AppColors.success
              : esAbonoParcial
              ? AppColors.warning
              : AppColors.warning;
          final monto = (cobro.monto ?? 0).toDouble();

          return DataRow(
            cells: [
              DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              DataCell(
                Text(
                  cobro.numeroBoletaFmt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    item.localNombre,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Text(
                  CurrencyFormatter.format(monto),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    esCobrado
                        ? 'COBRADO'
                        : esAbonoParcial
                        ? 'ABONO'
                        : (cobro.estado ?? 'PENDIENTE').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // Vista movil: cards compactos tipo ListTile
  Widget _buildMobileCards(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 14,
        endIndent: 14,
        color: theme.dividerColor.withValues(alpha: 0.15),
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        final cobro = item.cobro;
        final estado = (cobro.estado ?? '').toLowerCase();
        final esCobrado = _esCobrado(cobro);
        final esAbonoParcial = estado == 'abono_parcial';
        final statusColor = esCobrado
            ? AppColors.success
            : esAbonoParcial
            ? AppColors.warning
            : AppColors.warning;
        final monto = (cobro.monto ?? 0).toDouble();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Icono de estado
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esCobrado
                      ? Icons.check_circle
                      : esAbonoParcial
                      ? Icons.paid_rounded
                      : Icons.schedule,
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              // Info del local + boleta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.localNombre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Boleta: ${cobro.numeroBoletaFmt}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Monto
              Text(
                CurrencyFormatter.format(monto),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Seccion de pendientes leida de corte.pendientesInfo
class _PendientesInfoSection extends StatelessWidget {
  final List<Map<String, dynamic>> pendientesInfo;
  final List<Map<String, dynamic>> gestionesInfo;
  final Color color;
  final IconData icon;
  final bool isWide;

  const _PendientesInfoSection({
    required this.pendientesInfo,
    required this.gestionesInfo,
    required this.color,
    required this.icon,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = pendientesInfo.fold<double>(
      0,
      (s, i) => s + ((i['montoPendiente'] as num?)?.toDouble() ?? 0),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Pendientes (${pendientesInfo.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(subtotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...pendientesInfo.map((info) {
            final nombre = info['nombreSocial'] as String? ?? 'S/N';
            final clave = info['clave'] as String? ?? '';
            final codigo = info['codigo'] as String? ?? '';
            final monto = (info['montoPendiente'] as num?)?.toDouble() ?? 0;
            final saldoAFavor = (info['saldoAFavor'] as num?)?.toDouble() ?? 0;
            final tieneSaldoAFavor = info['tieneSaldoAFavor'] == true;
            final saldoCubreCuota = info['saldoCubreCuota'] == true;
            final localId = info['localId'] ?? info['local_id'];
            final incidenciasLocal = gestionesInfo
                .where((g) => (g['localId'] ?? g['local_id']) == localId)
                .toList();

            return InkWell(
              onTap: () => _showPendienteBottomSheet(
                context,
                nombre,
                codigo,
                clave,
                monto,
                saldoAFavor,
                tieneSaldoAFavor,
                saldoCubreCuota,
                incidenciasLocal,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.schedule, size: 14, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (codigo.isNotEmpty || clave.isNotEmpty)
                            Text(
                              [
                                if (codigo.isNotEmpty) 'Código: $codigo',
                                if (clave.isNotEmpty) 'Clave: $clave',
                              ].join(' | '),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (tieneSaldoAFavor)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                saldoCubreCuota
                                    ? 'Tiene saldo a favor suficiente; falta registrar el cobro con saldo.'
                                    : 'Saldo a favor disponible: ${CurrencyFormatter.format(saldoAFavor)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.semanticColors.success,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(monto),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showPendienteBottomSheet(
    BuildContext context,
    String nombre,
    String codigo,
    String clave,
    double monto,
    double saldoAFavor,
    bool tieneSaldoAFavor,
    bool saldoCubreCuota,
    List<Map<String, dynamic>> incidencias,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (codigo.isNotEmpty || clave.isNotEmpty)
                          Text(
                            [
                              if (codigo.isNotEmpty) 'Código: $codigo',
                              if (clave.isNotEmpty) 'Clave: $clave',
                            ].join(' | '),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(monto),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _chip('Monto pendiente: ${CurrencyFormatter.format(monto)}'),
                  if (tieneSaldoAFavor)
                    _chip(
                      saldoCubreCuota
                          ? 'Saldo a favor cubre cuota'
                          : 'Saldo a favor: ${CurrencyFormatter.format(saldoAFavor)}',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Incidencias del día (${incidencias.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (incidencias.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Sin incidencias registradas.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: incidencias.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 8,
                      endIndent: 8,
                      color: theme.dividerColor.withValues(alpha: 0.15),
                    ),
                    itemBuilder: (ctx, idx) {
                      final inc = incidencias[idx];
                      final titulo =
                          inc['titulo'] as String? ??
                          inc['motivo'] as String? ??
                          'Incidencia';
                      final desc =
                          inc['descripcion'] as String? ??
                          inc['detalle'] as String? ??
                          inc['comentario'] as String? ??
                          '';
                      final hora = inc['fecha'] ?? inc['hora'];

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.report_problem,
                              color: theme.colorScheme.error,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        titulo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hora != null)
                                      Text(
                                        '$hora',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CobradosInfoSection extends StatelessWidget {
  final List<CobroConDetalle> cobrados;
  final double subtotal;
  final Color color;
  final IconData icon;
  final List<Map<String, dynamic>> gestionesInfo;

  const _CobradosInfoSection({
    required this.cobrados,
    required this.subtotal,
    required this.color,
    required this.icon,
    required this.gestionesInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  'Cobrados / Abonos (${cobrados.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(subtotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...cobrados.map((item) {
            final cobro = item.cobro;
            final incidenciasLocal = gestionesInfo.where((g) {
              final gid = g['localId'] as String?;
              return gid != null && gid == cobro.localId;
            }).toList();
            return Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.confirmation_number,
                    color: color,
                    size: 18,
                  ),
                  title: Text(
                    item.localNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cobro.numeroBoletaFmt,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 12,
                        ),
                      ),
                      if ((item.localCodigo ?? '').isNotEmpty ||
                          (item.localClave ?? '').isNotEmpty ||
                          incidenciasLocal.isNotEmpty)
                        Text(
                          [
                            if ((item.localCodigo ?? '').isNotEmpty)
                              'Cód: ${item.localCodigo}',
                            if ((item.localClave ?? '').isNotEmpty)
                              'Clave: ${item.localClave}',
                            if (incidenciasLocal.isNotEmpty)
                              'Incidencias: ${incidenciasLocal.length}',
                          ].join(' | '),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format((cobro.monto ?? 0).toDouble()),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        (cobro.estado ?? '').toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showLocalBottomSheet(
                    context,
                    theme,
                    item,
                    incidenciasLocal,
                  ),
                ),
                Divider(
                  height: 0,
                  thickness: 0.6,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showLocalBottomSheet(
    BuildContext context,
    ThemeData theme,
    CobroConDetalle item,
    List<Map<String, dynamic>> incidenciasLocal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final cobro = item.cobro;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.store_mall_directory,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.localNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Boleta: ${cobro.numeroBoletaFmt}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format((cobro.monto ?? 0).toDouble()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        (cobro.estado ?? '').toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Informacion adicional del local
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if ((item.localCodigo ?? '').isNotEmpty)
                    _infoChip(context, 'Código: ${item.localCodigo}'),
                  if ((item.localClave ?? '').isNotEmpty)
                    _infoChip(context, 'Clave: ${item.localClave}'),
                  if ((item.ruta ?? '').isNotEmpty)
                    _infoChip(context, 'Ruta: ${item.ruta}'),
                  if ((item.frecuenciaCobro ?? '').isNotEmpty)
                    _infoChip(context, 'Frecuencia: ${item.frecuenciaCobro}'),
                  if (item.cuotaDiaria != null)
                    _infoChip(
                      context,
                      'Cuota: ${CurrencyFormatter.format(item.cuotaDiaria!.toDouble())}',
                    ),
                  if (item.saldoAFavor != null)
                    _infoChip(
                      context,
                      'Saldo a favor: ${CurrencyFormatter.format(item.saldoAFavor!.toDouble())}',
                    ),
                  if (item.deudaAcumulada != null)
                    _infoChip(
                      context,
                      'Deuda: ${CurrencyFormatter.format(item.deudaAcumulada!.toDouble())}',
                    ),
                  if ((item.representante ?? '').isNotEmpty)
                    _infoChip(context, 'Rep.: ${item.representante}'),
                  if ((item.telefono ?? '').isNotEmpty)
                    _infoChip(context, 'Tel: ${item.telefono}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Incidencias del día (${incidenciasLocal.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (incidenciasLocal.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Sin incidencias registradas para este local.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: incidenciasLocal.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 8,
                      endIndent: 8,
                      color: theme.dividerColor.withValues(alpha: 0.15),
                    ),
                    itemBuilder: (ctx, idx) {
                      final inc = incidenciasLocal[idx];
                      final titulo =
                          inc['titulo'] as String? ??
                          inc['motivo'] as String? ??
                          'Incidencia';
                      final desc =
                          inc['descripcion'] as String? ??
                          inc['detalle'] as String? ??
                          inc['comentario'] as String? ??
                          '';
                      final hora = inc['fecha'] ?? inc['hora'];

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.report_problem,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        titulo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hora != null)
                                      Text(
                                        '$hora',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Seccion de gestiones/incidencias leida de corte.gestionesInfo
class _GestionesInfoSection extends StatelessWidget {
  final List<Map<String, dynamic>> gestionesInfo;
  final Color color;
  final IconData icon;
  final bool isWide;

  const _GestionesInfoSection({
    required this.gestionesInfo,
    required this.color,
    required this.icon,
    required this.isWide,
  });

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'CERRADO':
        return 'Local Cerrado';
      case 'AUSENTE':
        return 'Encargado Ausente';
      case 'SIN_EFECTIVO':
        return 'Sin Efectivo';
      case 'NEGADO':
        return 'Se niega a pagar';
      case 'VOLVER_TARDE':
        return 'Volver más tarde';
      default:
        return 'Otro motivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Incidencias (${gestionesInfo.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...gestionesInfo.map((info) {
            final nombre = info['nombreSocial'] as String? ?? 'S/N';
            final clave = info['clave'] as String? ?? '';
            final codigo = info['codigo'] as String? ?? '';
            final tipo = info['tipoIncidencia'] as String? ?? 'OTRO';
            final comentario = info['comentario'] as String? ?? '';
            final tsRaw = info['timestamp'] as String? ?? '';
            String horaStr = '';
            if (tsRaw.isNotEmpty) {
              try {
                final dt = DateTime.parse(tsRaw);
                horaStr =
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              } catch (_) {}
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment_late_rounded,
                      size: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            if (codigo.isNotEmpty) 'Código: $codigo',
                            if (clave.isNotEmpty) 'Clave: $clave',
                            comentario.isNotEmpty
                                ? '${_labelTipo(tipo)} - $comentario'
                                : _labelTipo(tipo),
                          ].join(' | '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (horaStr.isNotEmpty)
                    Text(
                      horaStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
