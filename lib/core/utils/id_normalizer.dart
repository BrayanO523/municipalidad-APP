abstract class IdNormalizer {
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'ñ'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String municipalidadId(String nombre) => 'MUN-${normalize(nombre)}';

  static String mercadoId(String municipalidadNombre, String nombre) =>
      'MER-${normalize(municipalidadNombre)}-${normalize(nombre)}';

  static String localId(String mercadoId, String numero) =>
      'LOC-$mercadoId-${normalize(numero)}';

  static String tipoNegocioId(String nombre) => 'TN-${normalize(nombre)}';

  static String cobroId(String localId, DateTime fecha) {
    final fechaStr =
        '${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';
    return 'COB-$localId-$fechaStr';
  }
}
