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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd/MM/yyyy - hh:mm a').format(state.fecha),
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Tarjeta principal del total
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
                          // Chips de desglose
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
                              label:
                                  '${state.gestionesInfo.length} Incidencias',
                              color: AppColors.warning,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Titulo de desglose
                  const Text(
                    'Desglose de Cobros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (state.yaRealizadoHoy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Ya se ha realizado un corte en el día de hoy.',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (state.isLoading ||
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
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          state.yaRealizadoHoy
                              ? 'Corte completado'
                              : 'Confirmar Corte Diario',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialogo de confirmacion
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
                    content: const Text('Corte diario realizado con éxito'),
                    backgroundColor: AppColors.success,
                  ),
                );
                // Ofrecer compartir PDF automaticamente
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
        title: const Text('Compartir reporte?'),
        content: const Text(
          'El corte se realizo correctamente. Deseas generar y compartir el PDF del cierre diario?',
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
                        // No tenemos codigo/clave aqui, se conserva el nombre
                      },
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

// Chip de estado reutilizable
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

// Sliver con la lista de cobros, incidencias y pendientes
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
    // Seccion de cobros reales
    final cobrosAsync = cobrosIds.isNotEmpty
        ? ref.watch(cobrosPorCorteProvider(cobrosIds))
        : null;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // COBRADOS
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
                  final Map<String, List<Map<String, dynamic>>>
                  incidenciasPorLocal = {};
                  for (final incidencia in gestionesInfo) {
                    final localId = (incidencia['localId'] as String?) ?? '';
                    if (localId.isEmpty) continue;
                    incidenciasPorLocal
                        .putIfAbsent(localId, () => [])
                        .add(incidencia);
                  }
                  return Column(
                    children: items
                        .map(
                          (item) => _CobroTile(
                            item: item,
                            incidenciasLocal:
                                incidenciasPorLocal[item.cobro.localId] ??
                                const [],
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
              ),
          ],
          // INCIDENCIAS
          if (gestionesInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'Incidencias (${gestionesInfo.length})',
              color: AppColors.warning,
            ),
            ...gestionesInfo.map((info) => _GestionTile(info: info)),
          ],
          // PENDIENTES
          if (pendientesInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'Pendientes (${pendientesInfo.length})',
              color: AppColors.warning,
            ),
            ...pendientesInfo.map((info) => _PendienteTile(info: info)),
          ],
          // Estado vacio
          if (cobrosIds.isEmpty &&
              pendientesInfo.isEmpty &&
              gestionesInfo.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No hay datos para realizar el corte.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// Header de seccion
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

// Tile individual de cada cobro
class _CobroTile extends StatelessWidget {
  final CobroConDetalle item;
  final List<Map<String, dynamic>> incidenciasLocal;
  const _CobroTile({required this.item, this.incidenciasLocal = const []});

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
        ? AppColors.warning
        : AppColors.warning;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _showCobroBottomSheet(
          context,
          item,
          incidenciasLocal: incidenciasLocal,
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recibo: ${cobro.numeroBoletaFmt}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              if (incidenciasLocal.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    incidenciasLocal.length == 1
                        ? '1 incidencia registrada'
                        : '${incidenciasLocal.length} incidencias registradas',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cobro.monto != null
                        ? CurrencyFormatter.format(cobro.monto!.toDouble())
                        : 'L. 0.00',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    cobro.estado?.toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: statusColor),
            ],
          ),
        ),
      ),
    );
  }
}

// Tile individual de cada local pendiente
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
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _showPendienteBottomSheet(context, info),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.warning.withValues(alpha: 0.12),
            child: const Icon(
              Icons.schedule,
              size: 20,
              color: AppColors.warning,
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
              'Cuota pendiente',
              if (tieneSaldoAFavor)
                saldoCubreCuota
                    ? 'Saldo a favor cubre la cuota'
                    : 'Saldo a favor: ${CurrencyFormatter.format(saldoAFavor)}',
            ].join(' | '),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(montoPendiente),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  const Text(
                    'PENDIENTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tile individual de cada gestion/incidencia
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
    const color = AppColors.warning;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _showGestionBottomSheet(context, info),
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
              comentario.isNotEmpty
                  ? '${_labelTipo(tipo)} - $comentario'
                  : _labelTipo(tipo),
            ].join(' | '),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'INCIDENCIA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPendienteBottomSheet(
  BuildContext context,
  Map<String, dynamic> info,
) {
  final theme = Theme.of(context);
  final nombre = info['nombreSocial'] as String? ?? 'S/N';
  final clave = info['clave'] as String? ?? '';
  final codigo = info['codigo'] as String? ?? '';
  final montoPendiente = (info['montoPendiente'] as num?)?.toDouble() ?? 0;
  final saldoAFavor = (info['saldoAFavor'] as num?)?.toDouble() ?? 0;
  final tieneSaldoAFavor = info['tieneSaldoAFavor'] == true;
  final saldoCubreCuota = info['saldoCubreCuota'] == true;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (codigo.isNotEmpty) 'Cód: $codigo',
                          if (clave.isNotEmpty) 'Clave: $clave',
                        ].join(' | '),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BottomInfoChip(
              label:
                  'Monto pendiente: ${CurrencyFormatter.format(montoPendiente)}',
              color: AppColors.warning,
            ),
            if (tieneSaldoAFavor) ...[
              const SizedBox(height: 8),
              _BottomInfoChip(
                label: saldoCubreCuota
                    ? 'Saldo a favor cubre la cuota'
                    : 'Saldo a favor: ${CurrencyFormatter.format(saldoAFavor)}',
                color: AppColors.success,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Este local quedo pendiente en el corte diario.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showCobroBottomSheet(
  BuildContext context,
  CobroConDetalle item, {
  List<Map<String, dynamic>> incidenciasLocal = const [],
}) {
  final theme = Theme.of(context);
  final cobro = item.cobro;
  final fecha = cobro.fecha ?? cobro.creadoEn ?? cobro.actualizadoEn;
  final fechasSaldadas = cobro.fechasDeudasSaldadas ?? const <DateTime>[];
  final rangoDeuda = fechasSaldadas.isNotEmpty
      ? _formatDebtRange(fechasSaldadas)
      : null;
  final estado = (cobro.estado ?? '').toLowerCase();
  final esCobrado = estado == 'cobrado' || estado == 'cobrado_saldo';
  final esAbonoParcial = estado == 'abono_parcial';
  final color = esCobrado
      ? AppColors.success
      : esAbonoParcial
      ? AppColors.warning
      : AppColors.warning;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    esCobrado
                        ? Icons.check_circle
                        : esAbonoParcial
                        ? Icons.paid_rounded
                        : Icons.schedule,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.localNombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((item.localCodigo ?? '').isNotEmpty)
                            'Cód: ${item.localCodigo}',
                          if ((item.localClave ?? '').isNotEmpty)
                            'Clave: ${item.localClave}',
                        ].join(' | '),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            _DetailRow(label: 'Recibo', value: cobro.numeroBoletaFmt),
            _DetailRow(
              label: 'Estado',
              value: (cobro.estado ?? 'N/D').toUpperCase(),
            ),
            if (fecha != null)
              _DetailRow(
                label: 'Fecha del recibo',
                value: _formatDateTime(fecha),
              ),
            if (rangoDeuda != null) ...[
              _DetailRow(
                label: fechasSaldadas.length > 1
                    ? 'Fechas saldadas'
                    : 'Fecha saldada',
                value: rangoDeuda,
              ),
            ],
            if ((cobro.observaciones ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Observaciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cobro.observaciones!.trim(),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (incidenciasLocal.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Incidencias del día (${incidenciasLocal.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...incidenciasLocal.map((incidencia) {
                final tipo =
                    (incidencia['tipoIncidencia'] as String?) ?? 'OTRO';
                final comentario = (incidencia['comentario'] as String?) ?? '';
                final ts = _parseDate(incidencia['timestamp']);
                final detalle = comentario.trim().isEmpty
                    ? _labelTipoIncidencia(tipo)
                    : '${_labelTipoIncidencia(tipo)} - ${comentario.trim()}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _BottomInfoChip(
                    label: ts == null
                        ? detalle
                        : '${_formatDateTime(ts)} - $detalle',
                    color: AppColors.warning,
                  ),
                );
              }),
            ],
          ],
        ),
      );
    },
  );
}

void _showGestionBottomSheet(BuildContext context, Map<String, dynamic> info) {
  final theme = Theme.of(context);
  final nombre = info['nombreSocial'] as String? ?? 'S/N';
  final clave = info['clave'] as String? ?? '';
  final codigo = info['codigo'] as String? ?? '';
  final tipo = info['tipoIncidencia'] as String? ?? 'OTRO';
  final comentario = info['comentario'] as String? ?? '';
  final timestamp = _parseDate(info['timestamp']);

  String labelTipo() {
    switch (tipo) {
      case 'CERRADO':
        return 'Local cerrado';
      case 'AUSENTE':
        return 'Encargado ausente';
      case 'SIN_EFECTIVO':
        return 'Sin efectivo';
      case 'NEGADO':
        return 'Se niega a pagar';
      case 'VOLVER_TARDE':
        return 'Volver más tarde';
      default:
        return 'Otro motivo';
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_late_rounded,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (codigo.isNotEmpty) 'Cód: $codigo',
                          if (clave.isNotEmpty) 'Clave: $clave',
                        ].join(' | '),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BottomInfoChip(
              label: 'Incidencia: ${labelTipo()}',
              color: AppColors.warning,
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 8),
              _BottomInfoChip(
                label: 'Registrada: ${_formatDateTime(timestamp)}',
                color: theme.colorScheme.primary,
              ),
            ],
            if (comentario.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Comentario',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                comentario,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}

String _labelTipoIncidencia(String tipo) {
  switch (tipo) {
    case 'CERRADO':
      return 'Local cerrado';
    case 'AUSENTE':
      return 'Encargado ausente';
    case 'SIN_EFECTIVO':
      return 'Sin efectivo';
    case 'NEGADO':
      return 'Se niega a pagar';
    case 'VOLVER_TARDE':
      return 'Volver más tarde';
    default:
      return 'Otro motivo';
  }
}

String _formatDateTime(DateTime date) {
  return DateFormat('dd/MM/yyyy - hh:mm:ss a').format(date);
}

String? _formatDebtRange(List<DateTime> fechas) {
  if (fechas.isEmpty) return null;
  final sorted = List<DateTime>.from(fechas)..sort();
  if (sorted.length == 1) {
    return DateFormat('dd/MM/yyyy').format(sorted.first);
  }
  return '${DateFormat('dd/MM/yyyy').format(sorted.first)} al ${DateFormat('dd/MM/yyyy').format(sorted.last)}';
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomInfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BottomInfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
