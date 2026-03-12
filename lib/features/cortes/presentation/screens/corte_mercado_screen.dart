import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Corte de Mercado'),
        centerTitle: true,
        actions: [
          if (state.mercadoSeleccionado != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => notifier.recargar(),
              tooltip: 'Recargar',
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Selector de Mercado ───
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
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
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined, size: 72, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Selecciona un mercado para ver\nlos cortes del día disponibles',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            // ─── Tarjeta resumen ───
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(
                child: _ResumenCard(state: state),
              ),
            ),

            // ─── Error ───
            if (state.error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    color: Colors.red.shade900.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),

            // ─── Título lista ───
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'Cortes de Cobradores del Día',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${state.cortesDelDia.length} corte(s)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Lista de cortes ───
            if (state.cortesDelDia.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No hay cortes de cobradores registrados hoy\npara este mercado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _CorteCobradorTile(
                      corte: state.cortesDelDia[i],
                      index: i,
                      onTap: () => context.push('/corte-detalle', extra: state.cortesDelDia[i]),
                    ),
                    childCount: state.cortesDelDia.length,
                  ),
                ),
              ),

            // ─── Botón confirmar ───
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: _BotonCorteMercado(state: state, notifier: notifier),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ──────────────────────────────────────────────────────────────────────────────

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seleccionar Mercado',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Mercado>(
        initialValue: seleccionado,
          hint: const Text('Selecciona un mercado'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.storefront_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: mercados
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.nombre ?? 'Sin nombre'),
                  ))
              .toList(),
          onChanged: (m) {
            if (m != null) onSeleccionado(m);
          },
        ),
      ],
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final CorteMercadoState state;

  const _ResumenCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              state.mercadoSeleccionado?.nombre ?? '',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now()),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  label: 'Total Consolidado',
                  value:
                      'L. ${state.totalConsolidado.toStringAsFixed(2)}',
                  valueStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                _StatColumn(
                  label: 'Cobros',
                  value: '${state.cantidadCobros}',
                  valueStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _StatColumn(
                  label: 'Cobradores',
                  value: '${state.cortesDelDia.length}',
                  valueStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _StatColumn({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: valueStyle),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
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
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          corte.cobradorNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${corte.cantidadRegistros} cobros • '
          'Hora: ${DateFormat('hh:mm a').format(corte.fechaCorte)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'L. ${corte.totalCobrado.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.primary,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BotonCorteMercado extends StatelessWidget {
  final CorteMercadoState state;
  final CorteMercadoNotifier notifier;

  const _BotonCorteMercado({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.yaRealizadoHoy) {
      return const Card(
        color: Colors.green,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '✅ Corte de mercado realizado hoy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final puedeRealizar =
        state.cortesDelDia.isNotEmpty && !state.isLoading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: state.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.store_rounded),
        label: Text(
          puedeRealizar
              ? 'Realizar Corte de Mercado'
              : 'No hay cortes disponibles',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: puedeRealizar
            ? () => _confirmar(context)
            : null,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _confirmar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await notifier.realizarCorteMercado();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Corte de mercado realizado con éxito'),
                    backgroundColor: Colors.green,
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
