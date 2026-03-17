import 'package:intl/intl.dart';

/// Formateador centralizado de moneda para Lempiras.
/// Usa separador de miles (,) y decimales (.) → Ej: L. 1,234.56
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  /// Devuelve el monto formateado como "L. 1,234.56"
  static String format(double amount) => 'L. ${_fmt.format(amount)}';

  /// Devuelve sólo el número formateado con separador de miles: "1,234.56"
  static String formatRaw(double amount) => _fmt.format(amount);
}
