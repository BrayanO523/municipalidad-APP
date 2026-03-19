import 'dart:io';

void main() async {
  final file = File('lib/features/locales/presentation/screens/locales_screen.dart');
  String content = await file.readAsString();

  final startIndex1 = content.indexOf('  Widget _buildPanelDetalle(BuildContext context, Local local) {');
  final endIndex1 = content.indexOf('  void _showQrDialog(BuildContext context, Local local) {');
  
  if (startIndex1 != -1 && endIndex1 != -1 && endIndex1 > startIndex1) {
    content = content.substring(0, startIndex1) + content.substring(endIndex1);
  }

  // Ahora quitamos _showDebugDebtSaldoDialog y _parseDecimalInput
  final startDebug = content.indexOf('  Future<void> _showDebugDebtSaldoDialog(');
  final endDebug = content.indexOf('/// Vista de la lista de locales con scroll infinito.');
  if (startDebug != -1 && endDebug != -1 && endDebug > startDebug) {
    content = content.substring(0, startDebug) + content.substring(endDebug);
  }
  
  // Ahora quitamos _DetailRow hasta el final de las clases
  final startDetail = content.indexOf('class _DetailRow extends StatelessWidget {');
  if (startDetail != -1) {
    content = content.substring(0, startDetail);
  }
  
  await file.writeAsString(content);
}
