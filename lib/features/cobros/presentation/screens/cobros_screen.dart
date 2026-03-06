import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/platform/printer_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/cobro.dart';

class CobrosScreen extends ConsumerWidget {
  const CobrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cobrosRecientes = ref.watch(cobrosFiltradosProvider);

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

class _CobrosHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rango = ref.watch(fechaFiltroCobrosProvider);
    final theme = Theme.of(context);

    // Format string nicely
    String dateText = 'Consulta de cobros y recaudación diaria';
    if (rango != null) {
      dateText =
          'Del ${DateFormatter.formatDate(rango.start)} al ${DateFormatter.formatDate(rango.end)}';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cobros',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (rango != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                tooltip: 'Limpiar filtro',
                onPressed: () {
                  ref.read(fechaFiltroCobrosProvider.notifier).setRango(null);
                },
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Filtrar'),
              onPressed: () async {
                final result = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange: rango,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF00D9A6),
                          surface: Color(0xFF1E1E2D),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (result != null) {
                  ref.read(fechaFiltroCobrosProvider.notifier).setRango(result);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _CobrosFullTable extends ConsumerStatefulWidget {
  final List<Cobro> cobros;

  const _CobrosFullTable({required this.cobros});

  @override
  ConsumerState<_CobrosFullTable> createState() => _CobrosFullTableState();
}

class _CobrosFullTableState extends ConsumerState<_CobrosFullTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final locales = ref.watch(localesProvider).value ?? [];

    String nombreCobrador(String? id) {
      if (id == null || id.isEmpty) return '-';
      try {
        final u = usuarios.firstWhere((u) => u.id == id);
        return u.nombre ?? id;
      } catch (_) {
        return id; // Fallback al ID si no encuentra el usuario
      }
    }

    String nombreLocal(String? id) {
      if (id == null || id.isEmpty) return '-';
      try {
        final l = locales.firstWhere((l) => l.id == id);
        return l.nombreSocial ?? id;
      } catch (_) {
        return id;
      }
    }

    return Card(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Local')),
                DataColumn(label: Text('Teléfono')),
                DataColumn(label: Text('Monto')),
                DataColumn(label: Text('Pago a Cuota')),
                DataColumn(label: Text('Cuota Diaria')),
                DataColumn(label: Text('Saldo Pendiente')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Cobrador')),
                DataColumn(label: Text('Observaciones')),
                DataColumn(label: Text('Ticket')),
              ],
              rows: widget.cobros.map((c) {
                return DataRow(
                  cells: [
                    DataCell(Text(DateFormatter.formatDateTime(c.fecha))),
                    DataCell(
                      Text(
                        nombreLocal(c.localId),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        c.telefonoRepresentante ?? '-',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    DataCell(Text(DateFormatter.formatCurrency(c.monto))),
                    DataCell(Text(DateFormatter.formatCurrency(c.pagoACuota))),
                    DataCell(Text(DateFormatter.formatCurrency(c.cuotaDiaria))),
                    DataCell(
                      Text(DateFormatter.formatCurrency(c.saldoPendiente)),
                    ),
                    DataCell(_EstadoChip(estado: c.estado)),
                    DataCell(
                      Text(
                        nombreCobrador(c.cobradorId),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(Text(c.observaciones ?? '-')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.white70),
                        tooltip: 'Reimprimir boleta',
                        onPressed: () async {
                          final printer = ref.read(printerServiceProvider);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Re-imprimiendo ticket N°${c.correlativo ?? "-"}...',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          final double montoSeguro = c.monto?.toDouble() ?? 0.0;
                          final double saldoPendienteRaw =
                              c.saldoPendiente?.toDouble() ?? 0.0;
                          final double saldoPendienteSeguro =
                              saldoPendienteRaw > 0 ? saldoPendienteRaw : 0.0;

                          final impreso = await printer.printReceipt(
                            empresa: 'MUNICIPALIDAD',
                            local: nombreLocal(c.localId),
                            monto: montoSeguro,
                            fecha: c.fecha ?? DateTime.now(),
                            saldoPendiente: saldoPendienteSeguro,
                            saldoAFavor: c.nuevoSaldoFavor?.toDouble(),
                            deudaAnterior: c.deudaAnterior?.toDouble(),
                            montoAbonadoDeuda: c.montoAbonadoDeuda?.toDouble(),
                            cobrador: nombreCobrador(c.cobradorId),
                            correlativo: c.correlativo,
                            anioCorrelativo: c.anioCorrelativo,
                          );

                          if (!impreso && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Comprobante no impreso. Revisa conexión de la impresora.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
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
