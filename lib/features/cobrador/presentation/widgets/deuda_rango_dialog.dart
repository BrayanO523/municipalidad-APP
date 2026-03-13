import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../locales/domain/entities/local.dart';

/// Diálogo personalizado para seleccionar un rango de fechas para carga de deuda.
/// Permite seleccionar "Desde" y "Hasta" individualmente mediante popups de calendario.
class DeudaRangoDialog extends StatefulWidget {
  final Local local;

  const DeudaRangoDialog({super.key, required this.local});

  @override
  State<DeudaRangoDialog> createState() => _DeudaRangoDialogState();
}

class _DeudaRangoDialogState extends State<DeudaRangoDialog> {
  late DateTime _desde;
  late DateTime _hasta;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = DateUtils.dateOnly(now);
    _desde = _hasta.subtract(const Duration(days: 7));
    
    // Permitir cargar deuda histórica incluso antes de la fecha de "creación" en el sistema
    DateTime minDate = DateTime(2010);
    minDate = DateUtils.dateOnly(minDate);

    if (_desde.isBefore(minDate)) {
      _desde = minDate;
    }

    // Asegurar que _hasta no sea anterior a _desde después de la normalización
    if (_hasta.isBefore(_desde)) {
      _hasta = _desde;
    }
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    
    // Permitir fechas históricas (útil si el local se registró recientemente pero debe años)
    DateTime minDate = DateTime(2010);
    minDate = DateUtils.dateOnly(minDate);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _desde : _hasta,
      firstDate: minDate,
      lastDate: today,
      helpText: esDesde ? 'Seleccionar Fecha Inicial' : 'Seleccionar Fecha Final',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.danger,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (esDesde) {
          _desde = picked;
          // Si 'desde' es después de 'hasta', igualamos 'hasta' a 'desde'
          if (_desde.isAfter(_hasta)) {
            _hasta = _desde;
          }
        } else {
          _hasta = picked;
          // Si 'hasta' es antes de 'desde', igualamos 'desde' a 'hasta'
          if (_hasta.isBefore(_desde)) {
            _desde = _hasta;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              child: Icon(Icons.history_edu_rounded, color: AppColors.danger, size: 24),
              alignment: PlaceholderAlignment.middle,
            ),
            WidgetSpan(child: SizedBox(width: 10)),
            TextSpan(
              text: 'Cargar Deuda por Rango',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Selecciona el periodo para el cual deseas generar registros de deuda pendiente.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _DateTile(
            label: 'DESDE',
            date: _desde,
            onTap: () => _seleccionarFecha(true),
          ),
          const SizedBox(height: 12),
          _DateTile(
            label: 'HASTA',
            date: _hasta,
            onTap: () => _seleccionarFecha(false),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline, size: 16, color: AppColors.danger),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Se crearán registros únicamente para los días que no tengan cobros previos.',
                    style: TextStyle(fontSize: 11, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DateTimeRange(start: _desde, end: _hasta)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('CONTINUAR'),
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.formatDate(date),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}
