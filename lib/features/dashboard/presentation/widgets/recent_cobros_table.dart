import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/scrollable_table.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';

class RecentCobrosTable extends ConsumerWidget {
  const RecentCobrosTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosRecientes = ref.watch(cobrosHoyProvider);
    // Solo locales y mercados con autoDispose ya aplicado en providers.dart.
    // Usuarios eliminado: no se requiere descargar la lista completa de usuarios
    // solo para mostrar el nombre del cobrador en 5 filas de tabla.
    final localesState = ref.watch(localesProvider);
    final mercadosState = ref.watch(mercadosProvider);

    final locales = localesState.value ?? [];
    final mercados = mercadosState.value ?? [];

    return Card(
      child: cobrosRecientes.when(
        data: (cobros) {
          if (cobros.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Builder(
                  builder: (context) => Text(
                    'No hay cobros registrados aún',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }
          return _CobrosDataTable(
            cobros: cobros,
            locales: locales,
            mercados: mercados,
          );
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

class _CobrosDataTable extends StatefulWidget {
  final List<Cobro> cobros;
  final List<Local> locales;
  final List<Mercado> mercados;

  const _CobrosDataTable({
    required this.cobros,
    required this.locales,
    required this.mercados,
  });

  @override
  State<_CobrosDataTable> createState() => _CobrosDataTableState();
}

class _CobrosDataTableState extends State<_CobrosDataTable> {
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    final totalItems = widget.cobros.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < totalItems)
        ? startIndex + _itemsPerPage
        : totalItems;
    final displayedCobros = widget.cobros.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScrollableTable(
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columns: [
              DataColumn(label: _buildHeaderCell('Fecha')),
              DataColumn(label: _buildHeaderCell('Local')),
              DataColumn(label: _buildHeaderCell('Mercado')),
              DataColumn(label: _buildHeaderCell('Representante')),
              DataColumn(label: _buildHeaderCell('Teléfono')),
              DataColumn(label: _buildHeaderCell('Monto'), numeric: true),
              DataColumn(label: _buildHeaderCell('Estado')),
            ],

            rows: displayedCobros.map((cobro) {
              final localMatches = widget.locales.where(
                (l) => l.id == cobro.localId,
              );
              final local = localMatches.isNotEmpty ? localMatches.first : null;

              final mercadoName =
                  widget.mercados
                      .cast<Mercado>()
                      .firstWhere(
                        (m) => m.id == cobro.mercadoId,
                        orElse: () => const Mercado(nombre: '-'),
                      )
                      .nombre ??
                  '-';

              return DataRow(
                cells: [
                  DataCell(Text(DateFormatter.formatDateTime(cobro.fecha))),
                  DataCell(
                    Text(
                      local?.nombreSocial ?? cobro.localId ?? '-',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      mercadoName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(178),
                      ),
                    ),
                  ),
                  DataCell(Text(local?.representante ?? '-')),
                  DataCell(Text(local?.telefonoRepresentante ?? '-')),
                  DataCell(Text(DateFormatter.formatCurrency(cobro.monto))),
                  DataCell(_EstadoChip(estado: cobro.estado)),
                ],
              );
            }).toList(),
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text('Página ${_currentPage + 1} de $totalPages'),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _currentPage < totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderCell(String label) {
    return Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.bold),
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
        color: chipColor.withAlpha(38),
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
