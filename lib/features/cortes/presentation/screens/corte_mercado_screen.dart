import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../domain/entities/corte.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../viewmodels/corte_mercado_notifier.dart' as cmn;

class CortesMercadoScreen extends ConsumerWidget {
  const CortesMercadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mercadosAsync = ref.watch(mercadosProvider);
    final state = ref.watch(corteMercadoProvider);
    final notifier = ref.read(corteMercadoProvider.notifier);
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Corte de Mercado'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (state.mercadoSeleccionado != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => notifier.recargar(),
              tooltip: 'Recargar',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
          child: CustomScrollView(
            slivers: [
              // ─── Selector de Mercado ───
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 16,
                ),
                sliver: SliverToBoxAdapter(
                  child: mercadosAsync.when(
                    data: (mercados) => _SelectorMercado(
                      mercados: mercados,
                      seleccionado: state.mercadoSeleccionado,
                      onSeleccionado: notifier.seleccionarMercado,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error cargando mercados: $e'),
                  ),
                ),
              ),

              // ─── Selector de Fecha ───
              if (state.mercadoSeleccionado != null)
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _SelectorFecha(
                      fechaDesde: state.fechaDesde,
                      fechaHasta: state.fechaHasta,
                      onCambiarDesde: notifier.seleccionarDesde,
                      onCambiarHasta: notifier.seleccionarHasta,
                      onSeleccionRapida: notifier.seleccionarFechaUnica,
                    ),
                  ),
                ),

              // ─── Contenido dinámico ───
              if (state.mercadoSeleccionado == null)
                SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Selecciona un Mercado',
                    subtitle:
                        'Elige un mercado del desplegable para ver\nlos cortes del día disponibles.',
                  ),
                )
              else if (state.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // ─── Resumen ───
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
                  sliver: SliverToBoxAdapter(
                    child: _ResumenCard(state: state, isWide: isWide),
                  ),
                ),

                // ─── Error ───
                if (state.error != null)
                  SliverPadding(
                    padding: EdgeInsets.all(isWide ? 32 : 16),
                    sliver: SliverToBoxAdapter(
                      child: _ErrorBanner(message: state.error!),
                    ),
                  ),

                // ─── Título lista ───
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16,
                    24,
                    isWide ? 32 : 16,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cortes de Cobradores del Día',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${state.cortesDelDia.length} corte(s)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Lista de cortes ───
                if (state.cortesDelDia.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: _EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Sin Cortes',
                        subtitle:
                            'No hay cortes de cobradores\nregistrados para esta fecha.',
                        compact: true,
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CorteCobradorTile(
                          corte: state.cortesDelDia[i],
                          index: i,
                          onTap: () => context.push(
                            '/corte-detalle',
                            extra: state.cortesDelDia[i],
                          ),
                        ),
                        childCount: state.cortesDelDia.length,
                      ),
                    ),
                  ),

                  // ─── Botones de Impresión ───
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 16,
                      vertical: 16,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _BotonesImpresion(
                        state: state,
                        onImprimirTodos: () => _imprimirTodos(context, state),
                      ),
                    ),
                  ),
                ],

                // ─── Botón confirmar ───
                SliverPadding(
                  padding: EdgeInsets.all(isWide ? 32 : 16),
                  sliver: SliverToBoxAdapter(
                    child: _BotonCorteMercado(state: state, notifier: notifier),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _imprimirTodos(
    BuildContext context,
    cmn.CorteMercadoState state,
  ) async {
    try {
      await PdfGenerator.printCorteMercado(
        state.cortesDelDia,
        state.mercadoSeleccionado?.nombre ?? 'Mercado',
        state.fechaHasta,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF de corte de mercado generado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error al generar PDF: $e')));
      }
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ──────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 16 : 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 40 : 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorMercado extends StatelessWidget {
  final List<Mercado> mercados;
  final Mercado? seleccionado;
  final ValueChanged<Mercado> onSeleccionado;

  const _SelectorMercado({
    required this.mercados,
    required this.seleccionado,
    required this.onSeleccionado,
  });

  @override
  Widget build(BuildContext context) {
    if (mercados.isEmpty) {
      return const Center(child: Text('No hay mercados disponibles.'));
    }

    final selectedId = seleccionado?.id;
    final idValido = mercados.any((m) => m.id == selectedId)
        ? selectedId
        : null;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Seleccionar Mercado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: idValido,
            hint: const Text('Elige un mercado'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
            ),
            items: mercados
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m.id,
                    child: Text(m.nombre ?? 'Sin nombre'),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) {
                final m = mercados.firstWhere((element) => element.id == id);
                onSeleccionado(m);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final cmn.CorteMercadoState state;
  final bool isWide;

  const _ResumenCard({required this.state, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

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
          Text(
            state.mercadoSeleccionado?.nombre ?? '',
            style: TextStyle(
              color: onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now()),
            style: TextStyle(
              color: onPrimary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // ── Estadísticas ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.payments_rounded,
                value: CurrencyFormatter.format(state.totalConsolidado),
                label: 'Total',
                large: true,
              ),
              Container(
                width: 1,
                height: 40,
                color: onPrimary.withValues(alpha: 0.2),
              ),
              _StatItem(
                icon: Icons.receipt_outlined,
                value: '${state.cantidadCobros}',
                label: 'Cobros',
              ),
              Container(
                width: 1,
                height: 40,
                color: onPrimary.withValues(alpha: 0.2),
              ),
              _StatItem(
                icon: Icons.people_outline_rounded,
                value: '${state.cortesDelDia.length}',
                label: 'Cobradores',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool large;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Column(
      children: [
        Icon(icon, color: onPrimary.withValues(alpha: 0.8), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: large ? 20 : 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: onPrimary.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CorteCobradorTile extends StatelessWidget {
  final Corte corte;
  final int index;
  final VoidCallback onTap;

  const _CorteCobradorTile({
    required this.corte,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incidencias = corte.gestionesInfo ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        corte.cobradorNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${corte.cantidadRegistros} cobros • '
                        '${DateFormat('hh:mm a').format(corte.fechaCorte)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      if (corte.primerBoleta != null &&
                          corte.ultimaBoleta != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 12,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              corte.primerBoleta == corte.ultimaBoleta
                                  ? corte.primerBoleta!
                                  : '${corte.primerBoleta} - ${corte.ultimaBoleta}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(corte.totalCobrado),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (incidencias.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(
                      Icons.report,
                      color: context.semanticColors.warning,
                    ),
                    tooltip: 'Ver incidencias',
                    onPressed: () =>
                        _showIncidenciasSheet(context, theme, incidencias),
                  ),
                  const SizedBox(width: 4),
                ],
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showIncidenciasSheet(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> incidencias,
  ) {
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
                  Icon(Icons.report, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  const Text(
                    'Incidencias del día',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (incidencias.isEmpty)
                Text(
                  'Sin incidencias registradas.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: incidencias.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                  itemBuilder: (ctx, i) {
                    final inc = incidencias[i];
                    final nombre = inc['nombreSocial'] as String? ?? 'S/N';
                    final codigo = inc['codigo'] as String? ?? '';
                    final clave = inc['clave'] as String? ?? '';
                    final tipo = inc['tipoIncidencia'] as String? ?? 'OTRO';
                    final comentario = inc['comentario'] as String? ?? '';
                    final tsRaw = inc['timestamp'] as String? ?? '';
                    String horaStr = '';
                    if (tsRaw.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(tsRaw);
                        horaStr =
                            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }
                    final detalles = [
                      if (codigo.isNotEmpty) 'Cód: $codigo',
                      if (clave.isNotEmpty) 'Clave: $clave',
                    ].join(' • ');

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.report_problem,
                        color: context.semanticColors.warning,
                      ),
                      title: Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tipo,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (comentario.isNotEmpty)
                            Text(
                              comentario,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          if (detalles.isNotEmpty)
                            Text(
                              detalles,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      trailing: horaStr.isNotEmpty
                          ? Text(
                              horaStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            )
                          : null,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BotonCorteMercado extends StatelessWidget {
  final cmn.CorteMercadoState state;
  final cmn.CorteMercadoNotifier notifier;

  const _BotonCorteMercado({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.yaRealizadoHoy) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 24),
            SizedBox(width: 10),
            Text(
              'Corte de mercado realizado hoy',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final puedeRealizar = state.cortesDelDia.isNotEmpty && !state.isLoading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        icon: state.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.store_rounded),
        label: Text(
          puedeRealizar
              ? 'Realizar Corte de Mercado'
              : 'No hay cortes disponibles',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: puedeRealizar ? () => _confirmar(context) : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _confirmar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Corte de Mercado'),
        content: Text(
          '¿Deseas consolidar los ${state.cortesDelDia.length} cortes del día '
          'del mercado "${state.mercadoSeleccionado?.nombre}" por un total de '
          '${CurrencyFormatter.format(state.totalConsolidado)}?\n\n'
          'Esta acción registrará el cierre oficial del mercado para hoy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await notifier.realizarCorteMercado();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Corte de mercado realizado con éxito'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _SelectorFecha extends StatelessWidget {
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final Function(DateTime) onCambiarDesde;
  final Function(DateTime) onCambiarHasta;
  final Function(DateTime) onSeleccionRapida;

  const _SelectorFecha({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.onCambiarDesde,
    required this.onCambiarHasta,
    required this.onSeleccionRapida,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    void seleccionarDiaRapido(DateTime fecha) {
      onSeleccionRapida(fecha);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de Cortes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _FechaButton(
              label: 'Ayer',
              fecha: now.subtract(const Duration(days: 1)),
              seleccionada:
                  _isSameDate(
                    fechaDesde,
                    now.subtract(const Duration(days: 1)),
                  ) &&
                  _isSameDate(
                    fechaHasta,
                    now.subtract(const Duration(days: 1)),
                  ),
              onTap: () =>
                  seleccionarDiaRapido(now.subtract(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),
            _FechaButton(
              label: 'Hoy',
              fecha: now,
              seleccionada:
                  _isSameDate(fechaDesde, now) && _isSameDate(fechaHasta, now),
              onTap: () => seleccionarDiaRapido(now),
            ),
            const SizedBox(width: 8),
            _FechaButton(
              label: 'Mañana',
              fecha: now.add(const Duration(days: 1)),
              seleccionada:
                  _isSameDate(fechaDesde, now.add(const Duration(days: 1))) &&
                  _isSameDate(fechaHasta, now.add(const Duration(days: 1))),
              onTap: () =>
                  seleccionarDiaRapido(now.add(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  'Desde: ${DateFormat('dd/MM/yyyy').format(fechaDesde)}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: fechaDesde,
                    firstDate: now.subtract(const Duration(days: 60)),
                    lastDate: now.add(const Duration(days: 60)),
                  );
                  if (picked != null) onCambiarDesde(picked);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  'Hasta: ${DateFormat('dd/MM/yyyy').format(fechaHasta)}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: fechaHasta,
                    firstDate: now.subtract(const Duration(days: 60)),
                    lastDate: now.add(const Duration(days: 60)),
                  );
                  if (picked != null) onCambiarHasta(picked);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _FechaButton extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final bool seleccionada;
  final VoidCallback onTap;

  const _FechaButton({
    required this.label,
    required this.fecha,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: seleccionada
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: seleccionada
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _BotonesImpresion extends StatelessWidget {
  final cmn.CorteMercadoState state;
  final VoidCallback onImprimirTodos;

  const _BotonesImpresion({required this.state, required this.onImprimirTodos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imprimir Cortes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Imprimir Todos'),
                onPressed: state.cortesDelDia.isNotEmpty
                    ? onImprimirTodos
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
