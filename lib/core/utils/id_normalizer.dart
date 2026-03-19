abstract class IdNormalizer {
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\u00E1\u00E0\u00E4\u00E2]'), 'a')
        .replaceAll(RegExp(r'[\u00E9\u00E8\u00EB\u00EA]'), 'e')
        .replaceAll(RegExp(r'[\u00ED\u00EC\u00EF\u00EE]'), 'i')
        .replaceAll(RegExp(r'[\u00F3\u00F2\u00F6\u00F4]'), 'o')
        .replaceAll(RegExp(r'[\u00FA\u00F9\u00FC\u00FB]'), 'u')
        .replaceAll(RegExp(r'\u00F1'), 'n')
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
