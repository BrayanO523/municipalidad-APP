import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/cobros_migration.dart';
import '../viewmodels/firestore_viewer_notifier.dart';

class FirestoreViewerScreen extends ConsumerWidget {
  const FirestoreViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firestoreViewerProvider);
    final theme = Theme.of(context);

    // Hardcodeado para debug, usar clases de constantes donde sea posible
    final colecciones = [
      FirestoreCollections.cobros,
      FirestoreCollections.locales,
      FirestoreCollections.mercados,
      FirestoreCollections.municipalidades,
      FirestoreCollections.tiposNegocio,
      FirestoreCollections.usuarios,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev: Visor Firestore'),
        backgroundColor: Colors.deepPurple.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header / Controles
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de colección
                Row(
                  children: [
                    const Icon(
                      Icons.data_object_rounded,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Colección: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: state.coleccionActual,
                          hint: const Text('Seleccionar una colección'),
                          items: colecciones.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(firestoreViewerProvider.notifier)
                                  .cambiarColeccion(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Campo de búsqueda
                if (state.coleccionActual != null)
                  TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Buscar en documentos (ID, contenido, campos)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: state.searchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                ref
                                    .read(firestoreViewerProvider.notifier)
                                    .actualizarBusqueda('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (value) {
                      ref
                          .read(firestoreViewerProvider.notifier)
                          .actualizarBusqueda(value);
                    },
                    controller: TextEditingController(text: state.searchTerm)
                      ..selection = TextSelection.collapsed(
                        offset: state.searchTerm.length,
                      ),
                  ),
                const SizedBox(height: 12),
                if (kDebugMode && state.coleccionActual != null)
                  _FilterByFieldBar(state: state),
                if (kDebugMode && state.coleccionActual != null)
                  const SizedBox(height: 12),
                // Botones de Mantenimiento
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MigrationButton(
                        label: 'Migrar Mercados',
                        onPressed: () => CobrosMigration.rellenarMercadoId(),
                      ),
                      const SizedBox(width: 8),
                      _MigrationButton(
                        label: 'Vincular a Choluteca',
                        onPressed: () => CobrosMigration.vincularTodoACholuteca(),
                        color: Colors.blue.shade800,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                'Error: ${state.error}',
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),

          // Tabla / Lista de Documentos
          Expanded(
            child: state.coleccionActual == null
                ? const Center(
                    child: Text(
                      'Elija una colección arriba para comenzar a explorar.\n\nNota: Los datos no se actualizan en vivo para ahorrar lecturas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : state.documentos.isEmpty && !state.cargando
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.searchTerm.isNotEmpty
                              ? Icons.search_off
                              : Icons.folder_open,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.searchTerm.isNotEmpty
                              ? 'No se encontraron documentos que coincidan con "${state.searchTerm}"'
                              : 'Colección vacía (0 documentos)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (state.searchTerm.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(firestoreViewerProvider.notifier)
                                  .actualizarBusqueda('');
                            },
                            child: const Text('Limpiar búsqueda'),
                          ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Información de resultados
                      if (state.searchTerm.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: Colors.blue.shade50,
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mostrando ${state.documentos.length} documento(s) que coinciden con "${state.searchTerm}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Lista de documentos
                      Expanded(
                        child: ListView.builder(
                          itemCount: state.documentos.length + 1,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            if (index == state.documentos.length) {
                              return _buildFooter(context, state, ref);
                            }

                            final doc = state.documentos[index];
                            final data = doc.data();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: theme.dividerColor),
                              ),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 20,
                                      color: Colors.indigo,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      doc.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const Spacer(),
                                    if (kDebugMode)
                                      IconButton(
                                        tooltip: 'Eliminar documento',
                                        icon: const Icon(
                                          Icons.delete_forever_rounded,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _confirmDelete(context, ref, doc.id),
                                      ),
                                    if (kDebugMode)
                                      IconButton(
                                        tooltip: 'Editar documento (JSON merge)',
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.blueAccent,
                                        ),
                                        onPressed: () => _showEditDialog(
                                          context: context,
                                          ref: ref,
                                          docId: doc.id,
                                          data: data,
                                        ),
                                      ),
                                  ],
                                ),
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.2),
                                    child: SelectableText(
                                      _prettifyJson(data),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    FirestoreViewerState state,
    WidgetRef ref,
  ) {
    if (state.cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.hayMas) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: FilledButton.icon(
            onPressed: () =>
                ref.read(firestoreViewerProvider.notifier).cargarMas(),
            icon: const Icon(Icons.downloading_rounded),
            label: const Text('Cargar 20 documentos más'),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Fin de la colección',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  String _prettifyJson(Map<String, dynamic>? json) {
    if (json == null) return '{}';
    try {
      // Intenta convertir tipos complejos de Firebase como Timestamp a texto legible
      final sanitized = _sanitizeForJson(json);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(sanitized);
    } catch (e) {
      return json.toString(); // Fallback crudo
    }
  }

  Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> map) {
    final Map<String, dynamic> result = {};

    for (var entry in map.entries) {
      var value = entry.value;

      // Manejar el objeto tipo Timestamp de Firebase
      if (value != null && value.runtimeType.toString() == 'Timestamp') {
        value = '[Timestamp] ${value.toDate().toLocal().toString()}';
      } else if (value != null &&
          value.runtimeType.toString() == 'DocumentReference') {
        value = '[DocRef] ${value.path}';
      } else if (value is Map<String, dynamic>) {
        value = _sanitizeForJson(value);
      } else if (value is List) {
        value = value.map((v) {
          if (v is Map<String, dynamic>) {
            return _sanitizeForJson(v);
          }
          if (v != null && v.runtimeType.toString() == 'Timestamp') {
            return '[Timestamp] ${v.toDate().toLocal().toString()}';
          }
          return v;
        }).toList();
      }

      result[entry.key] = value;
    }

    return result;
  }
}

class _FilterByFieldBar extends ConsumerWidget {
  final FirestoreViewerState state;
  const _FilterByFieldBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueCtrl = TextEditingController(text: state.filterValue);
    final fields = state.availableFields.isNotEmpty
        ? state.availableFields
        : <String>['id', 'codigo', 'nombre'];
    final selected = state.filterField.isNotEmpty
        ? state.filterField
        : (fields.isNotEmpty ? fields.first : '');

    return Row(
      children: [
        const Icon(Icons.filter_alt_rounded, color: Colors.deepPurple),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: selected.isEmpty ? null : selected,
          hint: const Text('Campo'),
          items: fields
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              ref
                  .read(firestoreViewerProvider.notifier)
                  .aplicarFiltroCampoValor(val, state.filterValue);
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: valueCtrl,
            decoration: const InputDecoration(
              labelText: 'Valor exacto',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.search, size: 16),
          label: const Text('Filtrar'),
          onPressed: () {
            ref.read(firestoreViewerProvider.notifier).aplicarFiltroCampoValor(
                  selected,
                  valueCtrl.text,
                );
          },
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            ref.read(firestoreViewerProvider.notifier).aplicarFiltroCampoValor(
                  '',
                  '',
                );
          },
          child: const Text('Limpiar filtro'),
        ),
      ],
    );
  }
}

class _MigrationButton extends StatelessWidget {
  final String label;
  final Future<String> Function() onPressed;
  final Color? color;

  const _MigrationButton({
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final result = await onPressed() as dynamic;
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Resultado de Migración'),
              content: SingleChildScrollView(child: Text(result.toString())),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
      },
      style: FilledButton.styleFrom(
        backgroundColor: color ?? Colors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      child: Text(label),
    );
  }
}

void _confirmDelete(BuildContext context, WidgetRef ref, String docId) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar documento'),
      content: Text(
        '¿Seguro que deseas eliminar el documento "$docId"? Esta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await ref.read(firestoreViewerProvider.notifier).eliminarDoc(docId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Documento eliminado')),
              );
            }
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

void _showEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String docId,
  required Map<String, dynamic>? data,
}) {
  final initialText = _stringifyForEdit(data);
  final controller = TextEditingController(
    text: initialText,
  );

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Editar "$docId"'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: controller,
          maxLines: 18,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '{ ... }',
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final parsed = jsonDecode(controller.text);
              if (parsed is! Map<String, dynamic>) {
                throw const FormatException('El JSON debe ser un objeto');
              }
              Navigator.pop(ctx);
              await ref
                  .read(firestoreViewerProvider.notifier)
                  .actualizarDoc(docId, parsed);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Documento actualizado (merge=true)'),
                ),
              );
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error al parsear/guardar: $e')),
                );
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

String _stringifyForEdit(Map<String, dynamic>? data) {
  if (data == null) return '{}';
  try {
    final sanitized = _sanitizeMapForEdit(data);
    return const JsonEncoder.withIndent('  ').convert(sanitized);
  } catch (_) {
    return data.toString();
  }
}

Map<String, dynamic> _sanitizeMapForEdit(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  for (final entry in map.entries) {
    var value = entry.value;
    if (value != null && value.runtimeType.toString() == 'Timestamp') {
      value = '[Timestamp] ${value.toDate().toLocal().toString()}';
    } else if (value != null &&
        value.runtimeType.toString() == 'DocumentReference') {
      value = '[DocRef] ${value.path}';
    } else if (value is Map<String, dynamic>) {
      value = _sanitizeMapForEdit(value);
    } else if (value is List) {
      value = value
          .map((v) => v is Map<String, dynamic>
              ? _sanitizeMapForEdit(v)
              : (v != null &&
                      v.runtimeType.toString() == 'Timestamp')
                  ? '[Timestamp] ${v.toDate().toLocal().toString()}'
                  : v)
          .toList();
    }
    result[entry.key] = value;
  }
  return result;
}
