import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../domain/entities/corte.dart';
import '../viewmodels/corte_mercado_notifier.dart';

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
                      isWide ? 32 : 16, 24, isWide ? 32 : 16, 8),
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
                          child: Icon(Icons.receipt_long_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cortes de Cobradores del Día',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${state.cortesDelDia.length} corte(s)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
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
                        title: 'Sin Cortes Hoy',
                        subtitle:
                            'Aún no hay cortes de cobradores\nregistrados para este mercado.',
                        compact: true,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CorteCobradorTile(
                          corte: state.cortesDelDia[i],
                          index: i,
                          onTap: () => context.push('/corte-detalle',
                              extra: state.cortesDelDia[i]),
                        ),
                        childCount: state.cortesDelDia.length,
                      ),
                    ),
                  ),

                // ─── Botón confirmar ───
                /*
                SliverPadding(
                  padding: EdgeInsets.all(isWide ? 32 : 16),
                  sliver: SliverToBoxAdapter(
                    child: _BotonCorteMercado(state: state, notifier: notifier),
                  ),
                ),
                */

                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ],
          ),
        ),
      ),
    );
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
            child: Icon(icon,
                size: compact ? 40 : 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
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
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
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
    final idValido =
        mercados.any((m) => m.id == selectedId) ? selectedId : null;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Seleccionar Mercado',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: idValido,
            hint: const Text('Elige un mercado'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
            ),
            items: mercados
                .map((m) => DropdownMenuItem<String>(
                      value: m.id,
                      child: Text(m.nombre ?? 'Sin nombre'),
                    ))
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
  final CorteMercadoState state;
  final bool isWide;

  const _ResumenCard({required this.state, required this.isWide});

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
          Text(
            state.mercadoSeleccionado?.nombre ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now()),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // ── Estadísticas ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                icon: Icons.attach_money_rounded,
                value: 'L. ${state.totalConsolidado.toStringAsFixed(2)}',
                label: 'Total',
                large: true,
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
              _StatItem(
                icon: Icons.receipt_outlined,
                value: '${state.cantidadCobros}',
                label: 'Cobros',
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
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
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: large ? 20 : 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
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
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${corte.cantidadRegistros} cobros • '
                        '${DateFormat('hh:mm a').format(corte.fechaCorte)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'L. ${corte.totalCobrado.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
class _BotonCorteMercado extends StatelessWidget {
  final CorteMercadoState state;
  final CorteMercadoNotifier notifier;

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
                    color: Theme.of(context).colorScheme.onPrimary),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          'L. ${state.totalConsolidado.toStringAsFixed(2)}?\n\n'
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
*/
