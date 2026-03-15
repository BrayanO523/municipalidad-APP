import 'package:flutter/material.dart';
import '../../../gestiones/domain/entities/gestion.dart';
import '../../../../app/theme/app_theme.dart';

/// Resultado de la selección en el BottomSheet de incidencias.
class IncidenciaResult {
  final TipoIncidencia tipo;
  final String? comentario;

  const IncidenciaResult({required this.tipo, this.comentario});
}

/// BottomSheet reutilizable para registrar incidencias de cobro.
///
/// Muestra chips de selección rápida para los motivos más comunes
/// y un campo de texto libre para el motivo "Otro".
///
/// Retorna un [IncidenciaResult] si se confirma, o `null` si se cancela.
class IncidenciaBottomSheet extends StatefulWidget {
  final String nombreLocal;

  const IncidenciaBottomSheet({super.key, required this.nombreLocal});

  /// Muestra el BottomSheet y retorna el resultado seleccionado.
  static Future<IncidenciaResult?> show(
    BuildContext context, {
    required String nombreLocal,
  }) {
    return showModalBottomSheet<IncidenciaResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IncidenciaBottomSheet(nombreLocal: nombreLocal),
    );
  }

  @override
  State<IncidenciaBottomSheet> createState() => _IncidenciaBottomSheetState();
}

class _IncidenciaBottomSheetState extends State<IncidenciaBottomSheet> {
  TipoIncidencia? _seleccion;
  final _comentarioCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final bool _guardando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _seleccionar(TipoIncidencia tipo) {
    setState(() {
      _seleccion = tipo;
      if (tipo == TipoIncidencia.otro) {
        // Auto-focus al campo de texto
        Future.microtask(() => _focusNode.requestFocus());
      } else {
        _focusNode.unfocus();
      }
    });
  }

  void _confirmar() {
    if (_seleccion == null) return;
    if (_seleccion == TipoIncidencia.otro &&
        _comentarioCtrl.text.trim().isEmpty) {
      // Mostrar indicación de que debe escribir el motivo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe el motivo de la incidencia'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      IncidenciaResult(
        tipo: _seleccion!,
        comentario: _seleccion == TipoIncidencia.otro
            ? _comentarioCtrl.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: bottomInset + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Icono animado + Título en un Container atractivo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_late_rounded,
                    size: 40,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Registrar Incidencia',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.nombreLocal,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 32),

                // Subtitle
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¿Cuál es el motivo de la no gestión?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Chips de motivos rápidos
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _MotivoChip(
                      tipo: TipoIncidencia.cerrado,
                      icon: Icons.lock_rounded,
                      selected: _seleccion == TipoIncidencia.cerrado,
                      onTap: () => _seleccionar(TipoIncidencia.cerrado),
                    ),
                    _MotivoChip(
                      tipo: TipoIncidencia.ausente,
                      icon: Icons.person_off_rounded,
                      selected: _seleccion == TipoIncidencia.ausente,
                      onTap: () => _seleccionar(TipoIncidencia.ausente),
                    ),
                    _MotivoChip(
                      tipo: TipoIncidencia.sinEfectivo,
                      icon: Icons.money_off_rounded,
                      selected: _seleccion == TipoIncidencia.sinEfectivo,
                      onTap: () => _seleccionar(TipoIncidencia.sinEfectivo),
                    ),
                    _MotivoChip(
                      tipo: TipoIncidencia.negado,
                      icon: Icons.block_rounded,
                      selected: _seleccion == TipoIncidencia.negado,
                      onTap: () => _seleccionar(TipoIncidencia.negado),
                    ),
                    _MotivoChip(
                      tipo: TipoIncidencia.volverTarde,
                      icon: Icons.schedule_rounded,
                      selected: _seleccion == TipoIncidencia.volverTarde,
                      onTap: () => _seleccionar(TipoIncidencia.volverTarde),
                    ),
                    _MotivoChip(
                      tipo: TipoIncidencia.otro,
                      icon: Icons.add_rounded,
                      selected: _seleccion == TipoIncidencia.otro,
                      onTap: () => _seleccionar(TipoIncidencia.otro),
                    ),
                  ],
                ),

                // Campo de texto para "Otro"
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  child: _seleccion == TipoIncidencia.otro
                      ? Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: TextField(
                            controller: _comentarioCtrl,
                            focusNode: _focusNode,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Describe el motivo (Requerido)',
                              hintText: 'Ej: El local está en remodelación...',
                              prefixIcon: const Icon(Icons.edit_note_rounded),
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: cs.outlineVariant,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: cs.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.warning,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 32),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _guardando
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: (_seleccion == null || _guardando)
                            ? null
                            : _confirmar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _guardando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirmar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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

class _MotivoChip extends StatelessWidget {
  final TipoIncidencia tipo;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MotivoChip({
    required this.tipo,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = selected ? AppColors.warning : cs.onSurface;
    final bgColor = selected
        ? AppColors.warning.withValues(alpha: 0.15)
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final borderColor = selected
        ? AppColors.warning
        : cs.outline.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Text(
                tipo.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
