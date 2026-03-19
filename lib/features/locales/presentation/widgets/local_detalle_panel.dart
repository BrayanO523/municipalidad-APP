import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/local.dart';
import '../viewmodels/locales_paginados_notifier.dart';

const bool _kShowDevTools = true;

class LocalDetallePanel extends ConsumerWidget {
  final Local local;
  final VoidCallback onClose;

  const LocalDetallePanel({
    super.key,
    required this.local,
    required this.onClose,
  });

  Future<void> _showDebugDebtSaldoDialog(
    BuildContext context,
    WidgetRef ref,
    Local local,
  ) async {
    if (!_kShowDevTools || local.id == null) return;

    final deudaActual = (local.deudaAcumulada ?? 0).toDouble();
    final saldoActual = (local.saldoAFavor ?? 0).toDouble();
    final deudaCtrl = TextEditingController(
      text: deudaActual.toStringAsFixed(2),
    );
    final saldoCtrl = TextEditingController(
      text: saldoActual.toStringAsFixed(2),
    );

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Debug: editar deuda y saldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deudaCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Deuda acumulada',
                prefixIcon: Icon(Icons.trending_down_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: saldoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Saldo a favor',
                prefixIcon: Icon(Icons.trending_up_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final nd = double.tryParse(deudaCtrl.text) ?? deudaActual;
      final ns = double.tryParse(saldoCtrl.text) ?? saldoActual;
      final deltaDeuda = nd - deudaActual;
      final deltaSaldo = ns - saldoActual;

      final ds = ref.read(localDatasourceProvider);
      await ds.actualizarConStats(
        localId: local.id!,
        data: {
          'deudaAcumulada': nd,
          'saldoAFavor': ns,
          if (local.municipalidadId != null)
            'municipalidadId': local.municipalidadId,
          if (local.mercadoId != null) 'mercadoId': local.mercadoId,
          'ajusteDebugManual': true,
        },
        deltaDeuda: deltaDeuda,
        deltaSaldo: deltaSaldo,
      );
      ref.read(localesPaginadosProvider.notifier).recargar();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider).value ?? [];
    final tipos = ref.watch(tiposNegocioProvider).value ?? [];

    final enRuta = usuarios.where(
      (u) => u.esCobrador && (u.rutaAsignada?.contains(local.id) ?? false),
    );

    String? cobradorNombre;
    if (enRuta.isNotEmpty) {
      cobradorNombre = enRuta.map((u) => u.nombre).join(', ');
    } else {
      final enMercado = usuarios
          .where((u) => u.esCobrador && u.mercadoId == local.mercadoId)
          .toList();
      if (enMercado.length == 1) {
        cobradorNombre = enMercado.first.nombre;
      }
    }

    final tipoIndex = tipos.indexWhere((t) => t.id == local.tipoNegocioId);
    final strTipo = tipoIndex >= 0
        ? (tipos[tipoIndex].nombre ?? local.tipoNegocioId ?? '-')
        : (local.tipoNegocioId ?? '-');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 200;
        final pd = compact ? 12.0 : 24.0;
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(pd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        local.nombreSocial ?? 'Detalles del Local',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_kShowDevTools)
                      IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: () =>
                            _showDebugDebtSaldoDialog(context, ref, local),
                        tooltip: 'Debug: editar deuda y saldo',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClose,
                      tooltip: 'Cerrar detalle',
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DetailRow(
                          icon: Icons.person_rounded,
                          label: 'Representante',
                          value: local.representante ?? '-',
                        ),
                        DetailRow(
                          icon: Icons.phone_rounded,
                          label: 'Teléfono',
                          value: local.telefonoRepresentante ?? '-',
                        ),
                        DetailRow(
                          icon: Icons.badge_rounded,
                          label: 'Cobrador Asignado',
                          value: cobradorNombre ?? 'Sin asignar',
                        ),
                        DetailRow(
                          icon: Icons.category_rounded,
                          label: 'Tipo de Negocio',
                          value: strTipo,
                        ),
                        DetailRow(
                          icon: Icons.square_foot_rounded,
                          label: 'Espacio (m²)',
                          value: '${local.espacioM2 ?? 0}',
                        ),
                        DetailRow(
                          icon: Icons.event_repeat_rounded,
                          label: 'Frecuencia de Cobro',
                          value: local.frecuenciaCobro ?? 'Diaria',
                        ),
                        if ((local.frecuenciaCobro ?? '').toLowerCase() ==
                            'mensual')
                          DetailRow(
                            icon: Icons.calendar_month_rounded,
                            label: 'Día de Cobro Mensual',
                            value:
                                local.diaCobroMensual?.toString() ??
                                'No definido',
                          ),
                        DetailRow(
                          icon: Icons.vpn_key_rounded,
                          label: 'Clave',
                          value: local.clave ?? '-',
                        ),
                        DetailRow(
                          icon: Icons.map_rounded,
                          label: 'Código Local',
                          value: local.codigo ?? '-',
                        ),
                        DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Creado En',
                          value: local.creadoEn != null
                              ? DateFormatter.formatDate(local.creadoEn!)
                              : '-',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PanelDetalleVacio extends StatelessWidget {
  const PanelDetalleVacio({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona un local de la tabla\npara ver su información completa.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
