import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/firestore_collections.dart';
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
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                const Icon(Icons.data_object_rounded, color: Colors.deepPurple),
                const SizedBox(width: 12),
                const Text('Colección: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(firestoreViewerProvider.notifier).cambiarColeccion(val);
                        }
                      },
                    ),
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
                    ? const Center(child: Text('Colección vacía (0 documentos)'))
                    : ListView.builder(
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
                                  const Icon(Icons.description_outlined, size: 20, color: Colors.indigo),
                                  const SizedBox(width: 8),
                                  Text(
                                    doc.id,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
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
    );
  }

  Widget _buildFooter(BuildContext context, FirestoreViewerState state, WidgetRef ref) {
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
            onPressed: () => ref.read(firestoreViewerProvider.notifier).cargarMas(),
            icon: const Icon(Icons.downloading_rounded),
            label: const Text('Cargar 20 documentos más'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
          ),
        ),
      );
    }
    
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('Fin de la colección', style: TextStyle(color: Colors.grey)),
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
      } else if (value != null && value.runtimeType.toString() == 'DocumentReference') {
        value = '[DocRef] ${value.path}';
      } else if (value is Map<String, dynamic>) {
        value = _sanitizeForJson(value);
      } else if (value is List) {
        value = value.map((v) {
          if (v is Map<String, dynamic>) return _sanitizeForJson(v);
          if (v != null && v.runtimeType.toString() == 'Timestamp') return '[Timestamp] ${v.toDate().toLocal().toString()}';
          return v;
        }).toList();
      }
      
      result[entry.key] = value;
    }
    
    return result;
  }
}
