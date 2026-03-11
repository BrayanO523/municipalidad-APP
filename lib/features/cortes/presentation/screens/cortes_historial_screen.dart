import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../viewmodels/cortes_paginados_notifier.dart';
import '../../domain/entities/corte.dart';

class CortesHistorialScreen extends ConsumerWidget {
  final bool isAdmin;

  const CortesHistorialScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = isAdmin ? cortesAdminPaginadosProvider : cortesCobradorPaginadosProvider;
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    // Carga inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.cortes.isEmpty && !state.cargando && state.errorMsg == null) {
        notifier.cargarPagina();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Cortes Globales (Admin)' : 'Mi Historial de Cortes'),
        centerTitle: true,
      ),
      body: state.cargando && state.cortes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.errorMsg != null
              ? Center(child: Text('Error: ${state.errorMsg}'))
              : state.cortes.isEmpty
                  ? const Center(child: Text('No hay cortes registrados aún.'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _getSortedKeys(_groupCortes(state.cortes)).length,
                            itemBuilder: (context, index) {
                              final grouped = _groupCortes(state.cortes);
                              final sortedKeys = _getSortedKeys(grouped);
                              final dateKey = sortedKeys[index];
                              final dayCortes = grouped[dateKey]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                                    child: Text(
                                      DateFormat('EEEE, d MMMM yyyy', 'es_ES')
                                          .format(DateTime.parse(dateKey))
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.8),
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  ...dayCortes.map((corte) => Card(
                                        elevation: 1,
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 8,
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .primaryColor
                                                .withValues(alpha: 0.1),
                                            child: Icon(Icons.receipt_long,
                                                color: Theme.of(context).primaryColor),
                                          ),
                                          title: Text(
                                            'L. ${corte.totalCobrado.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                              'Hora: ${DateFormat('hh:mm a').format(corte.fechaCorte)} • '
                                              '${corte.cantidadRegistros} cobros'
                                              '${isAdmin ? '\nCobrador: ${corte.cobradorNombre}' : ''}'),
                                          trailing: const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 16),
                                          onTap: () {
                                            context.push(
                                              isAdmin
                                                  ? '/corte-detalle'
                                                  : '/cobrador/corte-detalle',
                                              extra: corte,
                                            );
                                          },
                                        ),
                                      )),
                                ],
                              );
                            },
                          ),
                        ),
                        _PaginationBar(state: state, notifier: notifier),
                      ],
                    ),
    );
  }

  Map<String, List<Corte>> _groupCortes(List<Corte> cortes) {
    final grouped = <String, List<Corte>>{};
    for (var corte in cortes) {
      final dateKey = DateFormat('yyyy-MM-dd').format(corte.fechaCorte);
      grouped.putIfAbsent(dateKey, () => []).add(corte);
    }
    return grouped;
  }

  List<String> _getSortedKeys(Map<String, List<Corte>> grouped) {
    return grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  }
}

class _PaginationBar extends StatelessWidget {
  final CortesPaginadosState state;
  final CortesPaginadosNotifier notifier;

  const _PaginationBar({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed:
                  state.paginaActual > 1 ? () => notifier.irAPaginaAnterior() : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Anter.'),
            ),
            Text(
              'Página ${state.paginaActual}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed:
                  state.hayMas ? () => notifier.irAPaginaSiguiente() : null,
              label: const Text('Siguiente'),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
