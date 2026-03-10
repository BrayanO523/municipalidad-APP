import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../viewmodels/corte_activo_notifier.dart';

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
                      const Text(
                        'Total Recaudado',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'L. ${state.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${state.cantidad} cobros registrados',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              
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

