import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/cobro.dart';

class CobrosScreen extends ConsumerWidget {
  const CobrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosRecientes = ref.watch(cobrosRecientesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CobrosHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: cobrosRecientes.when(
                data: (cobros) {
                  if (cobros.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay cobros registrados aún',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return _CobrosFullTable(cobros: cobros);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CobrosHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cobros',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Consulta de cobros y recaudación diaria',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

class _CobrosFullTable extends StatelessWidget {
  final List<Cobro> cobros;

  const _CobrosFullTable({required this.cobros});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Local')),
            DataColumn(label: Text('Monto')),
            DataColumn(label: Text('Cuota Diaria')),
            DataColumn(label: Text('Saldo Pendiente')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Cobrador')),
            DataColumn(label: Text('Observaciones')),
          ],
          rows: cobros.map((c) {
            return DataRow(
              cells: [
                DataCell(
                  Text(c.id ?? '-', style: const TextStyle(fontSize: 11)),
                ),
                DataCell(Text(DateFormatter.formatDateTime(c.fecha))),
                DataCell(
                  Text(c.localId ?? '-', style: const TextStyle(fontSize: 12)),
                ),
                DataCell(Text(DateFormatter.formatCurrency(c.monto))),
                DataCell(Text(DateFormatter.formatCurrency(c.cuotaDiaria))),
                DataCell(Text(DateFormatter.formatCurrency(c.saldoPendiente))),
                DataCell(_EstadoChip(estado: c.estado)),
                DataCell(
                  Text(
                    c.cobradorId ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(Text(c.observaciones ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String? estado;

  const _EstadoChip({this.estado});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (estado) {
      case 'cobrado':
        chipColor = const Color(0xFF00D9A6);
        break;
      case 'abono_parcial':
        chipColor = const Color(0xFFFF9F43);
        break;
      default:
        chipColor = const Color(0xFFEE5A6F);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado ?? 'pendiente',
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
