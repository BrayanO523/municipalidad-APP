import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../domain/entities/corte.dart';
import '../../../cobros/domain/entities/cobro.dart';

// Definición de tipo para mayor claridad
typedef CobroConDetalle = ({Cobro cobro, String localNombre});

final cobrosPorCorteProvider = FutureProvider.family<List<CobroConDetalle>, List<String>>((ref, ids) async {
  final cobroDs = ref.watch(cobroDatasourceProvider);
  final localDs = ref.watch(localDatasourceProvider);
  
  // 1. Obtener los cobros por sus IDs
  final cobros = await cobroDs.listarPorIds(ids);
  if (cobros.isEmpty) return [];
  
  // 2. Extraer IDs de locales únicos para optimizar la carga
  final uniqueLocalIds = cobros
      .map((c) => c.localId)
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
      
  // 3. Obtener nombres de locales
  final locales = await localDs.listarPorIds(uniqueLocalIds);
  final Map<String, String> localNamesMap = {
    for (var l in locales) l.id!: l.nombreSocial ?? 'S/N'
  };
  
  // 4. Mapear cobros con sus detalles
  return cobros.map((c) => (
    cobro: c, 
    localNombre: localNamesMap[c.localId] ?? (c.localId ?? 'ID Desconocido')
  )).toList();
});

class CorteDetalleScreen extends ConsumerWidget {
  final Corte corte;

  const CorteDetalleScreen({super.key, required this.corte});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosAsync = ref.watch(cobrosPorCorteProvider(corte.cobrosIds));
    final DateFormat formatter = DateFormat('EEEE, d MMMM yyyy, hh:mm a', 'es_ES');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Corte'),
        actions: [
          cobrosAsync.when(
            data: (items) => IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => PdfGenerator.printCorte(
                corte, 
                items.map((item) => item.cobro).toList(),
                localNames: { for (var item in items) item.cobro.localId!: item.localNombre },
              ),
              tooltip: 'Exportar PDF',
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Recaudado', style: TextStyle(fontSize: 14)),
                              Text(
                                'L. ${corte.totalCobrado.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(corte.cobradorNombre),
                            subtitle: const Text('Cobrador Responsable'),
                            trailing: Text(
                              '${corte.cantidadRegistros} cobros',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatter.format(corte.fechaCorte),
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Desglose de Cobros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          cobrosAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('No hay detalles de cobros disponibles.')),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      final cobro = item.cobro;
                      final theme = Theme.of(context);
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.localNombre,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
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
                                    color: theme.colorScheme.onSurface,
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
                          ),
                          if (index < items.length - 1) const Divider(),
                        ],
                      );
                    },
                    childCount: items.length,
                  ),
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
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Espacio para el FAB
        ],
      ),
      floatingActionButton: cobrosAsync.when(
        data: (items) => FloatingActionButton.extended(
          onPressed: () => PdfGenerator.printCorte(
            corte, 
            items.map((item) => item.cobro).toList(),
            localNames: { for (var item in items) item.cobro.localId!: item.localNombre },
          ),
          label: const Text('Imprimir Reporte'),
          icon: const Icon(Icons.print),
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}
