import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/pdf_generator.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/corte.dart';
import '../viewmodels/corte_activo_notifier.dart';
import 'corte_detalle_screen.dart'; // cobrosPorCorteProvider

class CorteNuevoScreen extends ConsumerWidget {
  const CorteNuevoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(corteActivoProvider);
    final notifier = ref.read(corteActivoProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Corte Diario'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
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
                    style: TextStyle(fontSize: 16, color: cs.onSurface.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Tarjeta principal del total ──
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            CurrencyFormatter.format(state.total),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${state.cobrosIds.length} movimientos registrados',
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ── Chips de desglose ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatusChip(
                                icon: Icons.check_circle,
                                label: '${state.cantidadCobrados} Cobrados',
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 12),
                              _StatusChip(
                                icon: Icons.schedule,
                                label: '${state.cantidadPendientes} Pendientes',
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                          if (state.gestionesInfo.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _StatusChip(
                              icon: Icons.assignment_late_rounded,
                              label: '${state.gestionesInfo.length} Incidencias',
                              color: const Color(0xFFE67E22),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Título desglose ──
                  const Text(
                    'Desglose de Cobros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          _SliverDesglose(
            cobrosIds: state.cobrosIds,
            pendientesInfo: state.pendientesInfo,
            gestionesInfo: state.gestionesInfo,
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16).copyWith(top: 8),
        color: theme.colorScheme.surfaceContainerLowest,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (state.yaRealizadoHoy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    '✅ Ya se ha realizado un corte en el día de hoy.',
                    style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (state.isLoading ||
                          state.yaRealizadoHoy ||
                          state.cantidad == 0)
                      ? null
                      : () => _confirmarCorte(context, ref, notifier, state),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.onPrimary),
                        )
                      : Text(
                          state.yaRealizadoHoy
                              ? 'Corte completado'
                              : 'Confirmar Corte Diario',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimary),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Diálogo de confirmación ──
  void _confirmarCorte(
    BuildContext context,
    WidgetRef ref,
    CorteActivoNotifier notifier,
    CorteActivoState state,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Corte Diario'),
        content: const Text(
          '¿Estás seguro de que deseas realizar el corte? '
          'Esto consolidará los cobros realizados hasta este momento como tu cierre oficial del día.',
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
                  SnackBar(
                    content: const Text('¡Corte diario realizado con éxito!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                // Ofrecer compartir PDF automáticamente
                _ofrecerCompartirPdf(context, ref, state);
              }
            },
            child: const Text('Realizar Corte'),
          ),
        ],
      ),
    );
  }

  /// Ofrece al usuario compartir el PDF tras realizar el corte.
  void _ofrecerCompartirPdf(
    BuildContext context,
    WidgetRef ref,
    CorteActivoState state,
  ) async {
    final cobrosAsync = state.cobrosIds.isNotEmpty
        ? ref.read(cobrosPorCorteProvider(state.cobrosIds))
        : null;
    final items = cobrosAsync?.value ?? [];

    // Permitir generar PDF aunque no haya cobros (solo pendientes)
    if (items.isEmpty && state.pendientesInfo.isEmpty) return;

    final now = DateTime.now();
    final inicio = DateTime(now.year, now.month, now.day);
    final fin = inicio
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final corteParaPdf = Corte(
      id: '',
      cobradorId: '',
      cobradorNombre: '',
      municipalidadId: '',
      fechaCorte: now,
      totalCobrado: state.total,
      cantidadRegistros: state.cantidad,
      cantidadCobrados: state.cantidadCobrados,
      cantidadPendientes: state.cantidadPendientes,
      cobrosIds: state.cobrosIds,
      fechaInicioRango: inicio,
      fechaFinRango: fin,
      pendientesInfo: state.pendientesInfo,
      gestionesInfo: state.gestionesInfo,
    );

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Compartir reporte?'),
        content: const Text(
          'El corte se realizó correctamente. ¿Deseas generar y compartir el PDF del cierre diario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No, gracias'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              PdfGenerator.printCorte(
                corteParaPdf,
                items.map((i) => i.cobro).toList(),
                localInfo: {
                  for (var i in items)
                    if (i.cobro.localId != null)
                      i.cobro.localId!: {
                        'nombre': i.localNombre,
                        // No tenemos código/clave aquí, se conservan nombre
                      }
                },
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Compartir PDF'),
          ),
        ],
      ),
    );
  }
}

// ── Chip de estado reutilizable ──
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sliver con la lista de cobros (cobrados) + pendientes del state ──
class _SliverDesglose extends ConsumerWidget {
  final List<String> cobrosIds;
  final List<Map<String, dynamic>> pendientesInfo;
  final List<Map<String, dynamic>> gestionesInfo;
  const _SliverDesglose({
    required this.cobrosIds,
    required this.pendientesInfo,
    required this.gestionesInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sección de cobros reales
    final cobrosAsync = cobrosIds.isNotEmpty
        ? ref.watch(cobrosPorCorteProvider(cobrosIds))
        : null;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── COBRADOS ──
          if (cobrosIds.isNotEmpty) ...[
            _SectionHeader(
              title: 'Cobros y Abonos (${cobrosAsync?.value?.length ?? 0})',
              color: AppColors.success,
            ),
            if (cobrosAsync != null)
              cobrosAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay cobros registrados.'),
                    );
                  }
                  return Column(
                    children: items.map((item) => _CobroTile(item: item)).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
              ),
          ],
          // ── INCIDENCIAS (GESTIONES) ──
          if (gestionesInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'Incidencias (${gestionesInfo.length})',
              color: const Color(0xFFE67E22),
            ),
            ...gestionesInfo.map((info) => _GestionTile(info: info)),
          ],
          // ── PENDIENTES ──
          if (pendientesInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'Pendientes (${pendientesInfo.length})',
              color: AppColors.warning,
            ),
            ...pendientesInfo.map((info) => _PendienteTile(info: info)),
          ],
          // Estado vacío
          if (cobrosIds.isEmpty && pendientesInfo.isEmpty && gestionesInfo.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No hay datos para realizar el corte.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Header de sección (Cobrados / Pendientes) ──
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile individual de cada cobro ──
class _CobroTile extends StatelessWidget {
  final CobroConDetalle item;
  const _CobroTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cobro = item.cobro;
    final theme = Theme.of(context);
    final estado = (cobro.estado ?? '').toLowerCase();
    final esCobrado = estado == 'cobrado' || estado == 'cobrado_saldo';
    final esAbonoParcial = estado == 'abono_parcial';
    final statusColor = esCobrado
        ? AppColors.success
        : esAbonoParcial
        ? const Color(0xFFE67E22)
        : AppColors.warning;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(
            esCobrado
                ? Icons.check_circle
                : esAbonoParcial
                ? Icons.paid_rounded
                : Icons.schedule,
            size: 20,
            color: statusColor,
          ),
        ),
        title: Text(
          item.localNombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Recibo: ${cobro.numeroBoletaFmt}',
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
              cobro.monto != null ? CurrencyFormatter.format(cobro.monto!.toDouble()) : 'L. 0.00',
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
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile individual de cada local pendiente ──
class _PendienteTile extends StatelessWidget {
  final Map<String, dynamic> info;
  const _PendienteTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final nombre = info['nombreSocial'] as String? ?? 'S/N';
    final clave = info['clave'] as String? ?? '';
    final codigo = info['codigo'] as String? ?? '';
    final montoPendiente = (info['montoPendiente'] as num?)?.toDouble() ?? 0;
    final saldoAFavor = (info['saldoAFavor'] as num?)?.toDouble() ?? 0;
    final tieneSaldoAFavor = info['tieneSaldoAFavor'] == true;
    final saldoCubreCuota = info['saldoCubreCuota'] == true;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.warning.withValues(alpha: 0.12),
          child: const Icon(Icons.schedule, size: 20, color: AppColors.warning),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (codigo.isNotEmpty) 'Cód: $codigo',
            if (clave.isNotEmpty) 'Clave: $clave',
            'Cuota pendiente',
            if (tieneSaldoAFavor)
              saldoCubreCuota
                  ? 'Saldo a favor cubre la cuota'
                  : 'Saldo a favor: ${CurrencyFormatter.format(saldoAFavor)}',
          ].join(' • '),
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
              CurrencyFormatter.format(montoPendiente),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
            const Text(
              'PENDIENTE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile individual de cada gestión/incidencia ──
class _GestionTile extends StatelessWidget {
  final Map<String, dynamic> info;
  const _GestionTile({required this.info});

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'CERRADO':
        return 'Local Cerrado';
      case 'AUSENTE':
        return 'Encargado Ausente';
      case 'SIN_EFECTIVO':
        return 'Sin Efectivo';
      case 'NEGADO':
        return 'Se niega a pagar';
      case 'VOLVER_TARDE':
        return 'Volver más tarde';
      default:
        return 'Otro motivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = info['nombreSocial'] as String? ?? 'S/N';
    final clave = info['clave'] as String? ?? '';
    final codigo = info['codigo'] as String? ?? '';
    final tipo = info['tipoIncidencia'] as String? ?? 'OTRO';
    final comentario = info['comentario'] as String? ?? '';
    final theme = Theme.of(context);
    const color = Color(0xFFE67E22);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: const Icon(
            Icons.assignment_late_rounded,
            size: 20,
            color: color,
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (codigo.isNotEmpty) 'Cód: $codigo',
            if (clave.isNotEmpty) 'Clave: $clave',
            comentario.isNotEmpty ? '${_labelTipo(tipo)} · $comentario' : _labelTipo(tipo),
          ].join(' • '),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Text(
          'INCIDENCIA',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
