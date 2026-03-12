import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/usuario.dart';

class CobrosCobradorScreen extends ConsumerStatefulWidget {
  final Usuario cobrador;

  const CobrosCobradorScreen({super.key, required this.cobrador});

  @override
  ConsumerState<CobrosCobradorScreen> createState() => _CobrosCobradorScreenState();
}

class _CobrosCobradorScreenState extends ConsumerState<CobrosCobradorScreen> {
  bool _isLoading = true;
  List<dynamic> _cobros = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCobros();
  }

  Future<void> _cargarCobros() async {
    try {
      final ds = ref.read(cobroDatasourceProvider);
      final rawCobros = await ds.listarPorCobrador(widget.cobrador.id!, limite: 150);
      
      // Filtrar pendientes automáticos y registros virtuales sin boleta real
      final cobrosLimpios = rawCobros.where((c) {
        if (c.monto == 0 && c.estado == 'pendiente') return false; 
        if (c.estado == 'adelantado' || c.estado == 'cobrado_saldo') return false;
        if (c.id?.startsWith('VIRTUAL') == true) return false;
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _cobros = cobrosLimpios;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de Correlativos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Cobrador: ${widget.cobrador.nombre} (${widget.cobrador.codigoCobrador ?? "Sin cod"})',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(150),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 700;
          return Padding(
            padding: isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(77),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withAlpha(26)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(
                        'Error: $_error',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    )
                  : _cobros.isEmpty
                      ? Center(
                          child: Text(
                            'No hay cobros registrados para este usuario.',
                            style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(128),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _cobros.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: colorScheme.outline.withAlpha(26),
                          ),
                          itemBuilder: (context, index) {
                            final c = _cobros[index];
                            final bool esSello = c.monto == 0 && c.estado == 'pendiente';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: esSello 
                                    ? Colors.orange.withAlpha(26)
                                    : Colors.green.withAlpha(26),
                                child: Icon(
                                  esSello ? Icons.cancel_presentation_rounded : Icons.payments_rounded,
                                  color: esSello ? Colors.orange : Colors.green,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                c.numeroBoleta ?? 'Boleta N/D',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              subtitle: Text(
                                'Fecha: ${c.fecha != null ? DateFormatter.formatDate(c.fecha) : "-"}',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha(150)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    DateFormatter.formatCurrency(c.monto ?? 0),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: esSello ? colorScheme.onSurface.withAlpha(150) : colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    esSello ? 'Sello/Sin Cobro' : 'Cobrado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: esSello ? Colors.orange : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
          );
        },
      ),
    );
  }
}
