import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../locales/domain/entities/local.dart';

/// Pantalla DEBUG-ONLY para gestionar y borrar deudas de locales.
/// Solo disponible en modo debug para testing rápido.
class DebugDeudaManagerScreen extends ConsumerStatefulWidget {
  const DebugDeudaManagerScreen({super.key});

  @override
  ConsumerState<DebugDeudaManagerScreen> createState() =>
      _DebugDeudaManagerScreenState();
}

class _DebugDeudaManagerScreenState
    extends ConsumerState<DebugDeudaManagerScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localesAsync = ref.watch(localesCobradorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🐛 DEBUG: Gestor de Deudas'),
        centerTitle: true,
        backgroundColor: AppColors.danger.withValues(alpha: 0.1),
      ),
      body: localesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (locales) {
          // Filtrar locales activos
          final localesActivos = locales
              .where((l) => l.activo == true)
              .toList();

          // Aplicar búsqueda
          final localesFiltrados = localesActivos.where((l) {
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
                      'Total de locales: ${localesActivos.length}',
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
                        hintText: 'Buscar por nombre, dueño o código...',
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
                          final tieneDeuda = (local.deudaAcumulada ?? 0) > 0;

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
                                          Text(
                                            local.nombreSocial ?? 'Sin nombre',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                          'Deuda: ${DateFormatter.formatCurrency(local.deudaAcumulada!)}',
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
                                              _borrarDeuda(context, local),
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
                                              _editarDeuda(context, local),
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
                                  OutlinedButton(
                                    onPressed: () =>
                                        _asignarDeuda(context, local),
                                    child: const Text('Asignar Deuda'),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _borrarDeuda(BuildContext context, Local local) async {
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
                'Deuda actual: ${DateFormatter.formatCurrency(local.deudaAcumulada ?? 0)}\n\nEsta acción NO se puede deshacer.',
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
          .update({'deudaAcumulada': 0});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deuda borrada: ${local.nombreSocial}'),
            backgroundColor: AppColors.success,
          ),
        );
        // Recargar la lista
        ref.invalidate(localesCobradorProvider);
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

  Future<void> _editarDeuda(BuildContext context, Local local) async {
    final montoCtrl = TextEditingController(
      text: (local.deudaAcumulada ?? 0).toStringAsFixed(2),
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
        ref.invalidate(localesCobradorProvider);
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
        ref.invalidate(localesCobradorProvider);
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
