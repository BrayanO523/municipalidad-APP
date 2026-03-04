import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../cobros/domain/entities/cobro.dart';

class RecentCobrosTable extends ConsumerWidget {
  const RecentCobrosTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosRecientes = ref.watch(cobrosRecientesProvider);

    return Card(
      child: cobrosRecientes.when(
        data: (cobros) {
          if (cobros.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No hay cobros registrados aún',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }
          return _CobrosDataTable(cobros: cobros);
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class _CobrosDataTable extends StatelessWidget {
  final List<Cobro> cobros;

  const _CobrosDataTable({required this.cobros});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Local')),
          DataColumn(label: Text('Monto')),
          DataColumn(label: Text('Estado')),
        ],
        rows: cobros.map((cobro) {
          return DataRow(
            cells: [
              DataCell(Text(DateFormatter.formatDate(cobro.fecha))),
              DataCell(Text(cobro.localId ?? '-')),
              DataCell(Text(DateFormatter.formatCurrency(cobro.monto))),
              DataCell(_EstadoChip(estado: cobro.estado)),
            ],
          );
        }).toList(),
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
