import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodels/corte_activo_notifier.dart';
import 'corte_detalle_screen.dart'; // Importante para reutilizar cobrosPorCorteProvider

class CorteNuevoScreen extends ConsumerWidget {
  const CorteNuevoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(corteActivoProvider);
    final notifier = ref.read(corteActivoProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Corte Diario'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Resumen de Hoy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy - hh:mm a').format(state.fecha),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Tarjeta principal del total
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Total Recaudado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'L. ${state.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${state.cantidad} cobros registrados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Desglose de cobros
              const Text(
                'Desglose de Cobros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: _buildDesglose(context, ref, state.cobrosIds),
              ),
              
              const SizedBox(height: 16),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                
              if (state.yaRealizadoHoy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    '✅ Ya se ha realizado un corte en el día de hoy.',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Botón de acción
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (state.isLoading || state.yaRealizadoHoy || state.cantidad == 0)
                      ? null
                      : () => _confirmarCorte(context, notifier),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          state.yaRealizadoHoy ? 'Corte de hoy completado' : 'Confirmar Corte Diario',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesglose(BuildContext context, WidgetRef ref, List<String> cobrosIds) {
    if (cobrosIds.isEmpty) {
      return const Center(
        child: Text(
          'No hay cobros para realizar el corte.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    final cobrosAsync = ref.watch(cobrosPorCorteProvider(cobrosIds));
    
    return cobrosAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No hay detalles de cobros disponibles.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            final cobro = item.cobro;
            // Para poder dar un contraste dinámico correcto 
            final theme = Theme.of(context);
            // Usando TextStyle con that color o default
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.localNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                cobro.numeroBoleta ?? 'Sin número de boleta',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'L. ${cobro.monto?.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    cobro.estado?.toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: cobro.estado == 'cobrado' 
                          ? Colors.green 
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error al cargar cobros: $err')),
    );
  }

  void _confirmarCorte(BuildContext context, CorteActivoNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Corte Diario'),
        content: const Text(
          '¿Estás seguro de que deseas realizar el corte? '
          'Esto consolidará los cobros realizados hasta este momento como tu cierre oficial del día.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await notifier.realizarCorte();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Corte diario realizado con éxito!'),
                    backgroundColor: Colors.green,
                  )
                );
                // Optionally route them to the history or dashboard
                // context.go('/cobrador/resumen'); 
              }
            },
            child: const Text('Realizar Corte'),
          ),
        ],
      ),
    );
  }
}

