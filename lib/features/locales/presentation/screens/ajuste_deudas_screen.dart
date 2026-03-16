import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/visual_debt_utils.dart';
import '../../../locales/domain/entities/local.dart';

/// Pantalla para gestionar y ajustar deudas de locales manualmente.
class AjusteDeudasScreen extends ConsumerStatefulWidget {
  const AjusteDeudasScreen({super.key});

  @override
  ConsumerState<AjusteDeudasScreen> createState() =>
      _AjusteDeudasScreenState();
}

class _AjusteDeudasScreenState extends ConsumerState<AjusteDeudasScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos localesProvider en lugar de localesCobradorProvider para administradores
    final localesAsync = ref.watch(localesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor de Deudas'),
        centerTitle: true,
      ),
      body: localesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (locales) {
          // No filtramos por activos, mostramos todos (el usuario quiere ver *cualquier* local)
          final localesParaMostrar = locales;

          // Aplicar búsqueda
          final localesFiltrados = localesParaMostrar.where((l) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return (l.nombreSocial ?? '').toLowerCase().contains(q) ||
                (l.representante ?? '').toLowerCase().contains(q) ||
                (l.codigo ?? '').toLowerCase().contains(q) ||
                (l.clave ?? '').toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Header con búsqueda
              Container(
                padding: const EdgeInsets.all(16),
                color: colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total de locales: ${localesParaMostrar.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, dueño, código o clave...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de locales
              Expanded(
                child: localesFiltrados.isEmpty
                    ? Center(
                        child: Text(
                          'No hay locales que coincidan',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: localesFiltrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final local = localesFiltrados[index];
                          final esInactivo = local.activo == false;

                          // Usamos VisualDebtUtils en lugar de solo deudaAcumulada
                          final cobrosAsync = ref.watch(localCobrosStreamProvider(local.id!));
                          
                          return cobrosAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, __) => Text('Error al cargar cobros: $e'),
                            data: (cobros) {
                              final deudaVisual = VisualDebtUtils.calcularDeudaVisual(local, cobros);
                              final tieneDeuda = deudaVisual > 0;

                              return Container(
                                padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tieneDeuda
                                    ? AppColors.danger.withValues(alpha: 0.3)
                                    : colorScheme.outlineVariant,
                                width: tieneDeuda ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre y deuda
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  local.nombreSocial ?? 'Sin nombre',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                        decoration: esInactivo ? TextDecoration.lineThrough : null,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (esInactivo) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.error.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Inactivo',
                                                    style: TextStyle(fontSize: 10, color: colorScheme.error, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                            ],
                                          ),
                                          if (local.representante != null &&
                                              local.representante!.isNotEmpty)
                                            Text(
                                              local.representante!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Deuda badge
                                    if (tieneDeuda)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.danger.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Deuda: ${DateFormatter.formatCurrency(deudaVisual.toDouble())}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.danger,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Sin Deuda',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.success,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Info adicional
                                Row(
                                  children: [
                                    if (local.codigo != null &&
                                        local.codigo!.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Código: ${local.codigo}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                      ),
                                    if (local.clave != null &&
                                        local.clave!.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Clave: ${local.clave}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Botones
                                if (tieneDeuda)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () =>
                                              _borrarDeuda(context, local, deudaVisual.toDouble()),
                                          icon: const Icon(
                                            Icons.delete_forever_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Borrar Deuda'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.danger,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _editarDeuda(context, local, deudaVisual.toDouble()),
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Editar'),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                            onPressed: () => _borrarDeuda(context, local, deudaVisual.toDouble()), // Permitimos borrar aunque sea 0 por si quieren usar el botón para "asegurar"
                                            icon: const Icon(Icons.delete_sweep, size: 18),
                                            label: const Text('Borrar (En Cero)'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                            onPressed: () => _asignarDeuda(context, local), // Permitimos asignar deudas
                                            icon: const Icon(Icons.add_card, size: 18),
                                            label: const Text('Asignar'),
                                        ),
                                      ),
                                    ],
                                  ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () => _purgarHistorialCero(context, local),
                                            icon: Icon(Icons.cleaning_services, size: 18, color: colorScheme.error),
                                            label: Text('Purgar Ceros y Pendientes', style: TextStyle(color: colorScheme.error)),
                                          ),
                                        ),
                                      ],
                                    )
                              ],
                            ),
                          );
                        });
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _borrarDeuda(BuildContext context, Local local, double deudaVisual) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Confirmar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Borrar la deuda de ${local.nombreSocial}?',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Deuda actual: ${DateFormatter.formatCurrency(deudaVisual)}\n\nEsta acción actualizará la deuda a L 0.00.',
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sí, Borrar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('locales')
          .doc(local.id)
          .update({'deudaAcumulada': 0, 'saldoAFavor': FieldValue.delete()}); // Borramos también saldo a favor para no generar inconsistencia

      // También intentamos eliminar cobros "pendientes" virtuales insertados en BD hoy
      final hoy = DateTime.now();
      final cobrosRef = await FirebaseFirestore.instance
          .collection('cobros')
          .where('localId', isEqualTo: local.id)
          .where('estado', isEqualTo: 'pendiente')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in cobrosRef.docs) {
         final f = (doc.data()['fecha'] as Timestamp?)?.toDate();
         if (f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
            batch.delete(doc.reference);
         }
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deuda borrada: ${local.nombreSocial}'),
            backgroundColor: AppColors.success,
          ),
        );
        // Recargar la lista y cobros
        ref.invalidate(localesProvider);
        ref.invalidate(localCobrosStreamProvider(local.id!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _purgarHistorialCero(BuildContext context, Local local) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Purgar Historial de Ceros/Pendientes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Limpiar el historial nulo de ${local.nombreSocial}?',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Esto eliminará:\n1) Todos los cobros viejos con valor de L 0.00.\n2) Todos los cobros en estado "pendiente".\n3) Restaurará la deuda del local a 0.\n\nEsta acción es fuerte e irreversible.',
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Purgar Datos'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // 1. Restaurar local a cero
      await FirebaseFirestore.instance
          .collection('locales')
          .doc(local.id)
          .update({'deudaAcumulada': 0, 'saldoAFavor': FieldValue.delete()});

      // 2. Buscar todos los cobros de este local enteros.
      final cobrosRef = await FirebaseFirestore.instance
          .collection('cobros')
          .where('localId', isEqualTo: local.id)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      int borrados = 0;

      for (var doc in cobrosRef.docs) {
         final data = doc.data();
         final estado = data['estado'] as String?;
         final monto = (data['monto'] as num?)?.toDouble() ?? 0.0;
         final cuota = (data['cuotaDiaria'] as num?)?.toDouble() ?? 0.0;

         // Criterios de purga: Es pendiente, O (está pagado/adelantado y fue de 0.00 en monto y cuota)
         if (estado == 'pendiente' || (monto <= 0 && cuota <= 0)) {
            batch.delete(doc.reference);
            borrados++;
         }
      }

      if (borrados > 0) {
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Se purgaron $borrados registros en cero/pendientes de ${local.nombreSocial}'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(localesProvider);
        ref.invalidate(localCobrosStreamProvider(local.id!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al purgar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _editarDeuda(BuildContext context, Local local, double deudaVisual) async {
    final montoCtrl = TextEditingController(
      text: deudaVisual.toStringAsFixed(2),
    );

    final nuevoMonto = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Deuda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              local.nombreSocial ?? 'Sin nombre',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Nuevo monto de deuda',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixText: 'L ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              Navigator.pop(ctx, monto);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (nuevoMonto == null || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('locales')
          .doc(local.id)
          .update({'deudaAcumulada': nuevoMonto});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Deuda actualizada a ${DateFormatter.formatCurrency(nuevoMonto)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(localesProvider);
        ref.invalidate(localCobrosStreamProvider(local.id!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _asignarDeuda(BuildContext context, Local local) async {
    final montoCtrl = TextEditingController();

    final nuevoMonto = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asignar Deuda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              local.nombreSocial ?? 'Sin nombre',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto de deuda',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixText: 'L ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              Navigator.pop(ctx, monto);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Asignar'),
          ),
        ],
      ),
    );

    if (nuevoMonto == null || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('locales')
          .doc(local.id)
          .update({'deudaAcumulada': nuevoMonto});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Deuda asignada: ${DateFormatter.formatCurrency(nuevoMonto)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(localesProvider);
        ref.invalidate(localCobrosStreamProvider(local.id!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
