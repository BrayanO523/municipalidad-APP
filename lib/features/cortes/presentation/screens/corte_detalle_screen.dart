import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/corte.dart';
import '../../../cobros/domain/entities/cobro.dart';

// Definición de tipo para mayor claridad
typedef CobroConDetalle = ({Cobro cobro, String localNombre});

final cobrosPorCorteProvider =
    FutureProvider.family<List<CobroConDetalle>, List<String>>((ref, ids) async {
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
  final Map<String, String> localNamesMap = {
    for (var l in locales) l.id!: l.nombreSocial ?? 'S/N'
  };

  return cobros
      .map((c) => (
            cobro: c,
            localNombre:
                localNamesMap[c.localId] ?? (c.localId ?? 'ID Desconocido')
          ))
      .toList();
});

class CorteDetalleScreen extends ConsumerWidget {
  final Corte corte;

  const CorteDetalleScreen({super.key, required this.corte});

  static bool _esCobrado(String? estado) =>
      estado == 'cobrado' || estado == 'cobrado_saldo';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosAsync = ref.watch(cobrosPorCorteProvider(corte.cobrosIds));
    final DateFormat formatter =
        DateFormat('EEEE, d MMMM yyyy, hh:mm a', 'es_ES');
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 800;

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
                localNames: {
                  for (var item in items) item.cobro.localId!: item.localNombre
                },
              ),
              tooltip: 'Exportar PDF',
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 950 : double.infinity),
          child: CustomScrollView(
            slivers: [
              // ── Header Card ──
              SliverPadding(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(
                    corte: corte,
                    formatter: formatter,
                    isWide: isWide,
                  ),
                ),
              ),

              // ── Contenido de Boletas ──
              cobrosAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              const Text('No hay detalles de cobros.'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Solo cobrados (pendientes vienen de corte.pendientesInfo)
                  final cobrados = items
                      .where((i) => _esCobrado(i.cobro.estado))
                      .toList();

                  final totalCobrados = cobrados.fold<double>(
                      0, (s, i) => s + (i.cobro.monto ?? 0).toDouble());

                  return SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Título sección
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.receipt_long_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Desglose de Boletas',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Cobrados ──
                        if (cobrados.isNotEmpty) ...[
                          _BoletasSection(
                            titulo: 'Cobradas (${cobrados.length})',
                            color: AppColors.success,
                            items: cobrados,
                            subtotal: totalCobrados,
                            icon: Icons.check_circle,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Pendientes (desde pendientesInfo del corte) ──
                        if (corte.pendientesInfo != null &&
                            corte.pendientesInfo!.isNotEmpty) ...[
                          _PendientesInfoSection(
                            pendientesInfo: corte.pendientesInfo!,
                            color: AppColors.warning,
                            icon: Icons.schedule,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Total general ──
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.summarize_rounded,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'TOTAL GENERAL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'L. ${corte.totalCobrado.toStringAsFixed(2)}',
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
        ),
      ),
      floatingActionButton: cobrosAsync.when(
        data: (items) => FloatingActionButton.extended(
          onPressed: () => PdfGenerator.printCorte(
            corte,
            items.map((item) => item.cobro).toList(),
            localNames: {
              for (var item in items) item.cobro.localId!: item.localNombre
            },
          ),
          label: const Text('Compartir Reporte'),
          icon: const Icon(Icons.share),
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

// ── Header Card con gradiente ──
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  corte.esCorteMercado
                      ? Icons.store_mall_directory_rounded
                      : Icons.person_rounded,
                  color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Estadísticas principales
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total Recaudado',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      'L. ${corte.totalCobrado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.2)),
                _MiniStat(
                  icon: Icons.check_circle,
                  value: '${corte.cantidadCobrados ?? '–'}',
                  label: 'Cobrados',
                  color: Colors.greenAccent,
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.2)),
                _MiniStat(
                  icon: Icons.schedule,
                  value: '${corte.cantidadPendientes ?? '–'}',
                  label: 'Pendientes',
                  color: Colors.orangeAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today,
                  size: 14, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                formatter.format(corte.fechaCorte),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
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
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Sección de boletas — elige automáticamente entre tabla (desktop) y
// cards compactos (móvil).
// ══════════════════════════════════════════════════════════════════════════
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

  static bool _esCobrado(String? estado) =>
      estado == 'cobrado' || estado == 'cobrado_saldo';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header de sección
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              border: Border(
                  bottom: BorderSide(color: color.withValues(alpha: 0.15))),
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

          // Contenido adaptativo: tabla en desktop, cards en móvil
          if (isWide)
            _buildDesktopTable(theme)
          else
            _buildMobileCards(theme),

          // Subtotal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3)),
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
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  'L. ${subtotal.toStringAsFixed(2)}',
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

  // ── Vista Desktop: DataTable completa ──
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
          final esCobrado = _esCobrado(cobro.estado);
          final statusColor =
              esCobrado ? AppColors.success : AppColors.warning;
          final monto = esCobrado
              ? (cobro.monto ?? 0).toDouble()
              : (cobro.cuotaDiaria ?? cobro.monto ?? 0).toDouble();

          return DataRow(cells: [
            DataCell(Text('${i + 1}',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(
              cobro.numeroBoletaFmt,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            )),
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
            DataCell(Text(
              'L. ${monto.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary),
            )),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  esCobrado ? 'COBRADO' : 'PENDIENTE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  // ── Vista Móvil: Cards compactos tipo ListTile ──
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
        final esCobrado = _esCobrado(cobro.estado);
        final statusColor =
            esCobrado ? AppColors.success : AppColors.warning;
        final monto = esCobrado
            ? (cobro.monto ?? 0).toDouble()
            : (cobro.cuotaDiaria ?? cobro.monto ?? 0).toDouble();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Ícono de estado
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esCobrado ? Icons.check_circle : Icons.schedule,
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
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Boleta: ${cobro.numeroBoletaFmt}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Monto
              Text(
                'L. ${monto.toStringAsFixed(2)}',
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

// ── Sección de pendientes leída de corte.pendientesInfo ──
class _PendientesInfoSection extends StatelessWidget {
  final List<Map<String, dynamic>> pendientesInfo;
  final Color color;
  final IconData icon;
  final bool isWide;

  const _PendientesInfoSection({
    required this.pendientesInfo,
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
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
                  'L. ${subtotal.toStringAsFixed(2)}',
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
            final monto =
                (info['montoPendiente'] as num?)?.toDouble() ?? 0;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    child: Text(
                      nombre,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'L. ${monto.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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
