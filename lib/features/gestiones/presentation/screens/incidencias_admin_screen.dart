import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/gestion.dart';
import '../viewmodels/incidencias_admin_notifier.dart';

class IncidenciasAdminScreen extends ConsumerStatefulWidget {
  const IncidenciasAdminScreen({super.key});

  @override
  ConsumerState<IncidenciasAdminScreen> createState() =>
      _IncidenciasAdminScreenState();
}

class _IncidenciasAdminScreenState
    extends ConsumerState<IncidenciasAdminScreen> {
  DateTime? _fechaFiltro;

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _fechaFiltro = picked);
      ref.read(incidenciasAdminProvider.notifier).filtrarPorFecha(picked);
    }
  }

  void _limpiarFiltro() {
    setState(() => _fechaFiltro = null);
    ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
  }

  String _tipoIncidenciaLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    return TipoIncidencia.fromFirestore(raw).label;
  }

  Future<void> _confirmarEliminar(IncidenciaUI incidencia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar incidencia'),
        content: Text(
          'Se eliminara la incidencia de ${incidencia.localNombre}. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    final incidenciaId = incidencia.gestion.id;
    if (incidenciaId == null || incidenciaId.isEmpty) return;

    try {
      await ref
          .read(incidenciasAdminProvider.notifier)
          .eliminarIncidencia(incidenciaId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incidencia eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Future<void> _abrirFormularioIncidencia({IncidenciaUI? incidencia}) async {
    final usuarioActual = ref.read(currentUsuarioProvider).value;
    final municipalidadId = usuarioActual?.municipalidadId;

    if (municipalidadId == null || municipalidadId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontro municipalidad para crear incidencia.'),
        ),
      );
      return;
    }

    final localDs = ref.read(localDatasourceProvider);
    final authDs = ref.read(authDatasourceProvider);

    final localesRaw = await localDs.listarTodos();
    final usuariosRaw = await authDs.listarTodos(
      municipalidadId: municipalidadId,
    );

    final locales =
        localesRaw
            .where((l) => l.id != null && l.municipalidadId == municipalidadId)
            .toList()
          ..sort(
            (a, b) => (a.nombreSocial ?? '').compareTo(b.nombreSocial ?? ''),
          );
    final cobradores =
        usuariosRaw.where((u) => u.id != null && u.esCobrador).toList()
          ..sort((a, b) => (a.nombre ?? '').compareTo(b.nombre ?? ''));

    if (locales.isEmpty || cobradores.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se requieren locales y cobradores para registrar incidencias.',
          ),
        ),
      );
      return;
    }

    String? localId = incidencia?.gestion.localId;
    String? cobradorId = incidencia?.gestion.cobradorId;
    String tipoIncidencia =
        incidencia?.gestion.tipoIncidencia ??
        TipoIncidencia.otro.firestoreValue;
    final comentarioCtrl = TextEditingController(
      text: incidencia?.gestion.comentario ?? '',
    );

    if (!locales.any((l) => l.id == localId)) {
      localId = locales.first.id;
    }
    if (!cobradores.any((u) => u.id == cobradorId)) {
      cobradorId = cobradores.first.id;
    }

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(
            incidencia == null ? 'Crear incidencia' : 'Editar incidencia',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: localId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Local',
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                    items: locales
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l.id,
                            child: Text(
                              '${l.nombreSocial ?? 'Sin nombre'} | Cod: ${l.codigo ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() => localId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cobradorId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cobrador',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    items: cobradores
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(u.nombre ?? u.email ?? 'Sin nombre'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => cobradorId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipoIncidencia,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de incidencia',
                      prefixIcon: Icon(Icons.assignment_late_rounded),
                    ),
                    items: TipoIncidencia.values
                        .map(
                          (tipo) => DropdownMenuItem<String>(
                            value: tipo.firestoreValue,
                            child: Text(tipo.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(
                      () => tipoIncidencia = value ?? tipoIncidencia,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comentarioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentario',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(incidencia == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar != true || localId == null || cobradorId == null) return;

    final localSeleccionado = locales.firstWhere((l) => l.id == localId);
    final mercadoId = localSeleccionado.mercadoId;
    final notifier = ref.read(incidenciasAdminProvider.notifier);

    try {
      if (incidencia == null) {
        await notifier.crearIncidencia(
          localId: localId!,
          cobradorId: cobradorId!,
          tipoIncidencia: tipoIncidencia,
          comentario: comentarioCtrl.text.trim(),
          municipalidadId: municipalidadId,
          mercadoId: mercadoId,
        );
      } else {
        final incidenciaId = incidencia.gestion.id;
        if (incidenciaId == null || incidenciaId.isEmpty) {
          throw Exception('Incidencia sin id.');
        }
        await notifier.editarIncidencia(
          id: incidenciaId,
          localId: localId!,
          cobradorId: cobradorId!,
          tipoIncidencia: tipoIncidencia,
          comentario: comentarioCtrl.text.trim(),
          municipalidadId: municipalidadId,
          mercadoId: mercadoId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            incidencia == null
                ? 'Incidencia creada correctamente.'
                : 'Incidencia actualizada correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar incidencia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incidenciasAdminProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Incidencias Reportadas'),
        elevation: 0,
        actions: [
          if (_fechaFiltro != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: ActionChip(
                label: Text(DateFormatter.formatDate(_fechaFiltro!)),
                onPressed: _limpiarFiltro,
                avatar: const Icon(Icons.close, size: 16),
                backgroundColor: colorScheme.primaryContainer,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: 'Filtrar por fecha',
            onPressed: _seleccionarFecha,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () {
              if (_fechaFiltro != null) {
                ref
                    .read(incidenciasAdminProvider.notifier)
                    .filtrarPorFecha(_fechaFiltro!);
              } else {
                ref.read(incidenciasAdminProvider.notifier).cargarIncidencias();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Crear incidencia',
            onPressed: () => _abrirFormularioIncidencia(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.when(
        data: (incidencias) {
          if (incidencias.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay incidencias reportadas.',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: incidencias.length,
            itemBuilder: (context, index) {
              final inc = incidencias[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              inc.localNombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'INCIDENCIA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () =>
                                _abrirFormularioIncidencia(incidencia: inc),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            onPressed: () => _confirmarEliminar(inc),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Clave: ${inc.localClave} | Cod: ${inc.localCodigo}',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Motivo / Observación: ${_tipoIncidenciaLabel(inc.gestion.tipoIncidencia)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (inc.gestion.comentario ?? '').isEmpty
                                  ? '-'
                                  : inc.gestion.comentario!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                inc.cobradorNombre,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            DateFormatter.formatDateTime(inc.gestion.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
    );
  }
}
