import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/utils/receipt_dispatcher.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../tipos_negocio/domain/entities/tipo_negocio.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../cobros/presentation/viewmodels/cobro_viewmodel.dart';
import '../../../../app/theme/app_theme.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  Local? _localEncontrado;
  bool _yaEscaneado = false;
  bool _buscando = false;
  bool _isRegistering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // MobileScanner autoinicia el controlador internamente.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetScanner() {
    setState(() {
      _localEncontrado = null;
      _buscando = false;
      _error = null;
      _yaEscaneado = false;
      _isRegistering = false;
    });
    // Ya no hacemos _controller.start() manualmente.
    // El widget MobileScanner lo hace automáticamente en su ciclo de vida,
    // y si nunca salió del widget tree, nunca se detuvo.
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_buscando || _localEncontrado != null || _yaEscaneado) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    // Si no tiene datos o es menor a un ID típico de Firestore (~20 chars) = Error
    if (qrData == null || qrData.length < 15) {
      setState(() {
        _error = 'QR invalido. Asegurate de escanear un QR de local válido.';
        _yaEscaneado = true;
      });
      return;
    }

    setState(() {
      _buscando = true;
      _error = null;
      _yaEscaneado = true;
    });
    // Ya no detenemos el hardware manualmente para evitar conflictos de estado.
    // La bandera _yaEscaneado impide que se procesen frames adicionales.

    try {
      final localId = qrData.split('LOCAL-').last;
      final localRepo = ref.read(localRepositoryProvider);
      final local = await localRepo.obtenerPorId(localId);

      if (local != null) {
        setState(() {
          _localEncontrado = local;
          _buscando = false;
        });
      } else {
        setState(() {
          _error = 'Local no encontrado con el QR escaneado.';
          _buscando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al buscar el local: $e';
        _buscando = false;
      });
    }
  }

  Future<void> _registrarCobro(Local local) async {
    final cobrosHoy = ref.read(cobrosHoyCobradorProvider).value ?? [];
    final pagadoHoy = cobrosHoy
        .where((c) => c.localId == local.id)
        .fold<num>(0, (sum, c) => sum + (c.monto ?? 0));

    final montoCtrl = TextEditingController(
      text: local.cuotaDiaria?.toStringAsFixed(0),
    );
    final obsCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 36, color: cs.primary),
                const SizedBox(height: 8),
                Text(
                  'Registrar Cobro',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Local: ${local.nombreSocial}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Cuota Diaria:',
                  value: DateFormatter.formatCurrency(local.cuotaDiaria),
                ),
                _InfoRow(
                  label: 'Deuda Acumulada:',
                  value: DateFormatter.formatCurrency(local.deudaAcumulada),
                ),
                _InfoRow(
                  label: 'Saldo a Favor:',
                  value: DateFormatter.formatCurrency(local.saldoAFavor),
                ),
                _InfoRow(
                  label: 'Pagado hoy:',
                  value: DateFormatter.formatCurrency(pagadoHoy),
                  color: AppColors.success,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    labelText: 'Monto a Cobrar',
                    prefixText: 'L ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final monto = num.tryParse(montoCtrl.text) ?? 0;
                          if (monto <= 0) return;
                          Navigator.pop(ctx);
                          final usuario = ref.read(currentUsuarioProvider).value;
                          await _guardarCobro(
                            local: local,
                            monto: monto,
                            observaciones: obsCtrl.text,
                            usuario: usuario,
                            pagadoHoy: pagadoHoy.toDouble(),
                          );
                        },
                        child: const Text('Confirmar Cobro'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _guardarCobro({
    required Local local,
    required num monto,
    required String observaciones,
    required dynamic usuario,
    required double pagadoHoy,
  }) async {
    setState(() => _isRegistering = true);

    // Leer providers síncronamente antes de los await para evitar Bad state
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);
    final cobroViewModel = ref.read(cobroViewModelProvider.notifier);

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
    final mercadoNombre = merc?.nombre;

    final cuota = local.cuotaDiaria ?? 0;
    final num saldoFavorExistente = local.saldoAFavor ?? 0;

    // --- LÓGICA DE DISTRIBUCIÓN SECUENCIAL ---
    // 1. Pagar cuota de hoy con EFECTIVO (Prioridad 1)
    final faltanteHoy = (cuota - pagadoHoy).clamp(0, cuota);
    final pagoACuota = monto > faltanteHoy ? faltanteHoy : monto;
    final num montoRestanteTrasHoy = (monto - pagoACuota).clamp(0, double.infinity);

    // 2. Pagar deuda acumulada con excedente de EFECTIVO (Prioridad 2)
    final deudaPast = local.deudaAcumulada ?? 0;
    final paraDeudaReal = montoRestanteTrasHoy > deudaPast
        ? deudaPast
        : montoRestanteTrasHoy;
    final num montoRestanteTrasDeuda = (montoRestanteTrasHoy - paraDeudaReal)
        .clamp(0, double.infinity);

    // 3. Excedente de efectivo a Saldo a Favor (Prioridad 3)
    final paraSaldoFavorReal = montoRestanteTrasDeuda;

    // 4. Si el efectivo NO alcanzó para la cuota, complementar con saldo a favor
    final num faltanteTrasEfectivo = (faltanteHoy - pagoACuota).clamp(0, double.infinity);
    final num saldoConsumido = faltanteTrasEfectivo > saldoFavorExistente
        ? saldoFavorExistente
        : faltanteTrasEfectivo;

    // Delta neto del saldo: nuevo excedente - saldo consumido
    final num deltaSaldoFavor = paraSaldoFavorReal - saldoConsumido;

    // Estado resultante de la jornada de hoy
    final saldoHoy = (faltanteHoy - pagoACuota - saldoConsumido).clamp(0, cuota);
    final cuotaTotalHoy = pagadoHoy + pagoACuota + saldoConsumido;
    final estado = cuotaTotalHoy >= cuota
        ? 'cobrado'
        : cuotaTotalHoy > 0
        ? 'abono_parcial'
        : 'pendiente';

    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';

    final double saldoResultante =
        (local.deudaAcumulada ?? 0).toDouble() -
        paraDeudaReal.toDouble() +
        saldoHoy.toDouble();
    final double favorResultante =
        (local.saldoAFavor ?? 0).toDouble() + deltaSaldoFavor.toDouble();

    try {

      final nuevoCobro = Cobro(
        id: docId,
        cobradorId: usuario?.id ?? '',
        actualizadoEn: now,
        actualizadoPor: usuario?.id ?? 'cobrador',
        creadoEn: now,
        creadoPor: usuario?.id ?? 'cobrador',
        cuotaDiaria: cuota,
        estado: estado,
        fecha: now,
        localId: local.id,
        mercadoId: local.mercadoId,
        municipalidadId: local.municipalidadId,
        monto: monto,
        pagoACuota: pagoACuota,
        observaciones: monto > 0
            ? () {
                final partes = <String>[];
                if (paraDeudaReal > 0) {
                  partes.add('L ${paraDeudaReal.toStringAsFixed(2)} a deuda anterior');
                }
                if (pagoACuota > 0) {
                  final hoyStr = '${now.day.toString().padLeft(2, "0")}/${now.month.toString().padLeft(2, "0")}/${now.year}';
                  partes.add('L ${pagoACuota.toStringAsFixed(2)} cuota del $hoyStr');
                }
                if (saldoConsumido > 0) {
                  partes.add('L ${saldoConsumido.toStringAsFixed(2)} de saldo a favor');
                }
                if (paraSaldoFavorReal > 0) {
                  partes.add('L ${paraSaldoFavorReal.toStringAsFixed(2)} a favor');
                }
                final prefijo = observaciones.isNotEmpty ? '$observaciones | ' : '';
                return '${prefijo}Distribuido: ${partes.join(", ")}';
              }()
            : observaciones,
        saldoPendiente: saldoHoy,
        deudaAnterior: local.deudaAcumulada ?? 0,
        montoAbonadoDeuda: paraDeudaReal,
        nuevoSaldoFavor: favorResultante,
        telefonoRepresentante: local.telefonoRepresentante,
      );

      final resultado = await cobroViewModel.registrarPago(
        cobro: nuevoCobro,
        localId: local.id!,
        montoAbonadoDeuda: paraDeudaReal,
        incrementoSaldoFavor: deltaSaldoFavor,
      );

      final String correlativoStr = resultado.numeroBoleta ?? '0';
      final List<DateTime> fechasSaldadas = resultado.fechasSaldadas;

      if (mounted) {
        setState(() => _isRegistering = false);
        String? periodoFavorStr;
        if (favorResultante > 0 && cuota > 0) {
          int dias = (favorResultante / cuota).floor();
          if (dias > 0) {
            DateTime inicioFavor = now.add(const Duration(days: 1));
            if (fechasSaldadas.isNotEmpty) {
               final sorted = List<DateTime>.from(fechasSaldadas)..sort();
               inicioFavor = sorted.last.add(const Duration(days: 1));
            }
            periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(inicioFavor, dias);
          }
        }

        await ReceiptDispatcher.presentReceiptOptions(
          context: context,
          ref: ref,
          local: local,
          monto: monto.toDouble(),
          fecha: now,
          saldoPendiente: saldoResultante,
          deudaAnterior: (local.deudaAcumulada ?? 0).toDouble(),
          montoAbonadoDeuda: paraDeudaReal.toDouble(),
          saldoAFavor: favorResultante,
          numeroBoleta: correlativoStr,
          municipalidadNombre: municipalidadNombre,
          mercadoNombre: mercadoNombre,
          cobradorNombre: usuario?.nombre,
          fechasSaldadas: fechasSaldadas,
          periodoSaldoAFavorStr: periodoFavorStr,
          slogan: muni?.slogan,
        );
        _resetScanner();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Escanear QR'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              if (_yaEscaneado)
                IconButton(
                  onPressed: _resetScanner,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Escanear otro',
                ),
            ],
          ),
          body: _localEncontrado != null
              ? _LocalDetailPanel(
                  local: _localEncontrado!,
                  onCobrar: () => _registrarCobro(_localEncontrado!),
                  onScanOtro: _resetScanner,
                )
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: _onDetect,
                          ),
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_buscando)
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Buscando local...'),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _resetScanner,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Intentar de nuevo'),
                            ),
                          ],
                        ),
                      ),
                    if (!_buscando && _error == null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Apunta la cámara al código QR del local',
                          style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                  ],
                ),
        ),
        if (_isRegistering)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    CircularProgressIndicator(color: AppColors.success),
                  SizedBox(height: 16),
                  Text(
                    'Registrando cobro...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalDetailPanel extends ConsumerWidget {
  final Local local;
  final VoidCallback onCobrar;
  final VoidCallback onScanOtro;

  const _LocalDetailPanel({
    required this.local,
    required this.onCobrar,
    required this.onScanOtro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final mercados = ref
        .watch(mercadosProvider)
        .maybeWhen(data: (list) => list, orElse: () => <Mercado>[]);
    final tipos = ref
        .watch(tiposNegocioProvider)
        .maybeWhen(data: (list) => list, orElse: () => <TipoNegocio>[]);

    final mercadoNombre =
        mercados.where((m) => m.id == local.mercadoId).firstOrNull?.nombre ??
        local.mercadoId ??
        '-';
    final tipoNombre =
        tipos.where((t) => t.id == local.tipoNegocioId).firstOrNull?.nombre ??
        local.tipoNegocioId ??
        '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Local Encontrado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    local.nombreSocial ?? 'Sin nombre',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.person_rounded,
                    label: 'Representante',
                    value: local.representante ?? '-',
                  ),
                  _DetailRow(
                    icon: Icons.store_rounded,
                    label: 'Mercado',
                    value: mercadoNombre,
                  ),
                  _DetailRow(
                    icon: Icons.square_foot_rounded,
                    label: 'Espacio',
                    value: '${local.espacioM2 ?? '-'} m²',
                  ),
                  _DetailRow(
                    icon: Icons.category_rounded,
                    label: 'Tipo',
                    value: tipoNombre,
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.payments_rounded,
                    label: 'Cuota Diaria',
                    value: DateFormatter.formatCurrency(local.cuotaDiaria),
                    valueStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onCobrar,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text(
                'Registrar Cobro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (local.latitud != null && local.longitud != null) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${local.latitud},${local.longitud}',
                  );
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir el mapa'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Abrir Ubicación (Maps)'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onScanOtro,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Escanear Otro QR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style:
                  valueStyle ??
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
