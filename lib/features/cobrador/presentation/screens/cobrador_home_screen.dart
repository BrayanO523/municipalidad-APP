import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';

class CobradorHomeScreen extends ConsumerStatefulWidget {
  const CobradorHomeScreen({super.key});

  @override
  ConsumerState<CobradorHomeScreen> createState() => _CobradorHomeScreenState();
}

class _CobradorHomeScreenState extends ConsumerState<CobradorHomeScreen> {
  List<Local> _locales = [];
  List<Cobro> _cobrosHoy = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final localDs = ref.read(localDatasourceProvider);
      final cobroDs = ref.read(cobroDatasourceProvider);
      final locales = await localDs.listarTodos();
      final cobrosHoy = await cobroDs.listarPorFecha(DateTime.now());
      setState(() {
        _locales = locales.where((l) => l.activo == true).toList();
        _cobrosHoy = cobrosHoy;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  bool _estaCobrado(String localId) {
    return _cobrosHoy.any((c) => c.localId == localId && c.estado == 'cobrado');
  }

  Cobro? _cobroDelLocal(String localId) {
    try {
      return _cobrosHoy.firstWhere((c) => c.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _registrarCobro(Local local) async {
    final montoCtrl = TextEditingController(
      text: local.cuotaDiaria?.toString() ?? '',
    );
    final obsCtrl = TextEditingController();
    final usuario = ref.read(currentUsuarioProvider).value;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cobrar - ${local.nombreSocial ?? ""}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Cuota diaria',
                value: DateFormatter.formatCurrency(local.cuotaDiaria),
              ),
              _InfoRow(
                label: 'Representante',
                value: local.representante ?? '-',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto a cobrar (L)',
                  prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Registrar Cobro'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final monto = num.tryParse(montoCtrl.text) ?? 0;
    final cuota = local.cuotaDiaria ?? 0;
    final saldo = (cuota - monto).clamp(0, cuota);
    final estado = monto >= cuota
        ? 'cobrado'
        : monto > 0
        ? 'abono_parcial'
        : 'pendiente';

    final now = DateTime.now();
    final docId =
        'COB-${local.id}-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    try {
      final cobroDs = ref.read(cobroDatasourceProvider);
      await cobroDs.crear(docId, {
        'actualizadoEn': Timestamp.fromDate(now),
        'actualizadoPor': usuario?.id ?? 'cobrador',
        'cobradorId': usuario?.id ?? '',
        'creadoEn': Timestamp.fromDate(now),
        'creadoPor': usuario?.id ?? 'cobrador',
        'cuotaDiaria': cuota,
        'estado': estado,
        'fecha': Timestamp.fromDate(now),
        'localId': local.id,
        'mercadoId': local.mercadoId,
        'monto': monto,
        'observaciones': obsCtrl.text,
        'saldoPendiente': saldo,
      });
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Cobro registrado: ${local.nombreSocial}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cobrados = _cobrosHoy.where((c) => c.estado == 'cobrado').length;
    final total = _locales.length;
    final montoHoy = _cobrosHoy.fold<num>(0, (acc, c) => acc + (c.monto ?? 0));

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ruta de Cobro',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormatter.formatDate(DateTime.now()),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                          const SizedBox(height: 20),
                          // Stats row
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.check_circle_rounded,
                                label: '$cobrados / $total cobrados',
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                icon: Icons.attach_money_rounded,
                                label: DateFormatter.formatCurrency(montoHoy),
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                icon: Icons.pending_actions_rounded,
                                label: '${total - cobrados} pendientes',
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Locales list
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final local = _locales[index];
                        final cobrado = _estaCobrado(local.id ?? '');
                        final cobroExistente = _cobroDelLocal(local.id ?? '');
                        return _LocalCard(
                          local: local,
                          cobrado: cobrado,
                          cobroExistente: cobroExistente,
                          onCobrar: () => _registrarCobro(local),
                        );
                      }, childCount: _locales.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalCard extends StatelessWidget {
  final Local local;
  final bool cobrado;
  final Cobro? cobroExistente;
  final VoidCallback onCobrar;

  const _LocalCard({
    required this.local,
    required this.cobrado,
    required this.cobroExistente,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: cobrado ? null : onCobrar,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cobrado
                    ? Colors.green.withValues(alpha: 0.3)
                    : colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cobrado
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    cobrado
                        ? Icons.check_circle_rounded
                        : Icons.storefront_rounded,
                    color: cobrado ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        local.nombreSocial ?? 'Sin nombre',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: cobrado
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${local.representante ?? '-'} • ${local.mercadoId ?? ''}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                // Cuota + action
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormatter.formatCurrency(local.cuotaDiaria),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cobrado ? Colors.green : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (cobrado)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cobrado ✓',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade300,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cobrar →',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
