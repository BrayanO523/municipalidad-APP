/// Utilidad Dart pura para formatear listas de fechas en rangos legibles.
/// Ejemplo: [05/03, 06/03, 07/03, 10/03] → "05/03 al 07/03, 10/03"
class DateRangeFormatter {
  /// Formatea una lista de fechas en rangos inteligentes.
  /// Retorna `null` si la lista está vacía.
  ///
  /// Reglas:
  /// - Fechas consecutivas se agrupan: "05/03 al 07/03"
  /// - Rangos de 7+ días incluyen conteo: "10/02 al 10/03 (30 días)"
  /// - Fechas sueltas se listan con coma: "05/03, 08/03"
  /// - Mezcla: "05/03 al 12/03, 15/03, 18/03 al 20/03"
  static String? formatearRangos(List<DateTime> fechas) {
    if (fechas.isEmpty) return null;

    // Ordenar y eliminar duplicados (mismo día)
    final sorted = fechas.toList()
      ..sort((a, b) => a.compareTo(b));

    final uniqueDays = <DateTime>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      if (!_mismoDia(sorted[i], uniqueDays.last)) {
        uniqueDays.add(sorted[i]);
      }
    }

    if (uniqueDays.length == 1) {
      return _fmt(uniqueDays.first);
    }

    // Agrupar en rangos consecutivos
    final rangos = <_Rango>[];
    var inicio = uniqueDays.first;
    var fin = uniqueDays.first;

    for (var i = 1; i < uniqueDays.length; i++) {
      final diff = uniqueDays[i].difference(fin).inDays;
      if (diff == 1) {
        fin = uniqueDays[i];
      } else {
        rangos.add(_Rango(inicio, fin));
        inicio = uniqueDays[i];
        fin = uniqueDays[i];
      }
    }
    rangos.add(_Rango(inicio, fin));

    // Formatear cada rango
    return rangos.map((r) => r.formatear()).join(', ');
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Rango {
  final DateTime inicio;
  final DateTime fin;

  _Rango(this.inicio, this.fin);

  int get dias => fin.difference(inicio).inDays + 1;

  String formatear() {
    if (dias == 1) {
      return DateRangeFormatter._fmt(inicio);
    }
    final base = '${DateRangeFormatter._fmt(inicio)} al ${DateRangeFormatter._fmt(fin)}';
    if (dias >= 7) {
      return '$base ($dias días)';
    }
    return base;
  }
}
