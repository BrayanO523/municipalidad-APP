import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../domain/entities/corte.dart';

class CortesHistorialScreen extends ConsumerWidget {
  final bool isAdmin;

  const CortesHistorialScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = isAdmin 
      ? cortesHistorialAdminProvider 
      : cortesHistorialCobradorProvider;

    final cortesAsyncValue = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Cortes Globales (Admin)' : 'Mi Historial de Cortes'),
        centerTitle: true,
      ),
      body: cortesAsyncValue.when(
        data: (cortes) {
          if (cortes.isEmpty) {
            return const Center(child: Text('No hay cortes registrados aún.'));
          }

          // Agrupación de Cortes
          final groupedCortes = <String, List<Corte>>{};
          for (var corte in cortes) {
            final dateKey = DateFormat('yyyy-MM-dd').format(corte.fechaCorte);
            groupedCortes.putIfAbsent(dateKey, () => []).add(corte);
          }

          final sortedKeys = groupedCortes.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final dayCortes = groupedCortes[dateKey]!;
              

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.parse(dateKey)).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  ...dayCortes.map((corte) => Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        child: Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                      ),
                      title: Text(
                        'L. ${corte.totalCobrado.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Hora: ${DateFormat('hh:mm a').format(corte.fechaCorte)} • '
                        '${corte.cantidadRegistros} cobros'
                        '${isAdmin ? '\nCobrador: ${corte.cobradorNombre}' : ''}'
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        context.push(
                          isAdmin ? '/corte-detalle' : '/cobrador/corte-detalle',
                          extra: corte,
                        );
                      },
                    ),
                  )).toList(),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
