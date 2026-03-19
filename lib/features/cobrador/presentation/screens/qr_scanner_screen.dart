import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/utils/receipt_dispatcher.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../../core/utils/monthly_visual_utils.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../mercados/domain/entities/mercado.dart';
import '../../../tipos_negocio/domain/entities/tipo_negocio.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../cobros/domain/utils/calculadora_distribucion.dart';
import '../../../cobros/presentation/viewmodels/cobro_viewmodel.dart';
import '../../../../app/theme/app_theme.dart';
import '../widgets/incidencia_bottom_sheet.dart';

bool _mismoDia(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

double _deudaHastaAyer({
  required Local local,
  required Map<String, double>? deudasMap,
  required List<Cobro> cobrosHoy,
}) {
  final localId = local.id;
  if (localId != null && deudasMap != null && deudasMap.containsKey(localId)) {
    return (deudasMap[localId] ?? 0).toDouble();
  }

  final deudaBase = (local.deudaAcumulada ?? 0).toDouble();
  if (deudaBase <= 0 || localId == null) return deudaBase;

  final hoy = DateTime.now();
  final deudaHoy = cobrosHoy
      .where((c) {
        if (c.localId != localId) return false;
        final estado = (c.estado ?? '').toLowerCase();
        if (estado != 'pendiente' && estado != 'abono_parcial') return false;
        final fecha = c.fecha ?? c.creadoEn;
        if (fecha == null) return false;
        return _mismoDia(fecha, hoy);
      })
      .fold<double>(
        0,
        (sum, c) => sum + (c.saldoPendiente ?? c.cuotaDiaria ?? 0).toDouble(),
      );

  return (deudaBase - deudaHoy).clamp(0.0, double.infinity);
}

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

  double _deudaVencidaReal(Local local) {
    final deudasMap = ref.read(deudasVencidasCobradorProvider).value;
    final cobrosHoy =
        ref.read(cobrosHoyCobradorProvider).value ?? const <Cobro>[];
    return _deudaHastaAyer(
      local: local,
      deudasMap: deudasMap,
      cobrosHoy: cobrosHoy,
    );
  }

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
        // VALIDACIÓN ESTRICTA DE RUTA PARA COBRADORES
        final usuario = ref.read(currentUsuarioProvider).value;
        if (usuario?.rol == 'cobrador') {
          final rutasAsignadas = usuario?.rutaAsignada ?? [];
          if (!rutasAsignadas.contains(local.id)) {
            setState(() {
              _error =
                  'Acceso Denegado: Este local no está asignado a tu ruta o mercado.';
              _buscando = false;
            });
            return;
          }
        }

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
    final mensualVisual = MonthlyVisualUtils.calcular(
      local,
      referencia: DateTime.now(),
    );
    final pagadoHoy = cobrosHoy
        .where((c) => c.localId == local.id)
        .fold<num>(0, (sum, c) => sum + (c.pagoACuota ?? 0));

    final montoCtrl = TextEditingController(text: '');
    final obsCtrl = TextEditingController();
    bool usarSaldoFavor = false;
    final montoSaldoFavorCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      local.nombreSocial ?? 'Local Reconocido',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _InfoRow(
                      label: 'Cuota Diaria:',
                      value: DateFormatter.formatCurrency(local.cuotaDiaria),
                    ),
                    if (mensualVisual != null) ...[
                      _InfoRow(
                        label: 'Día cobro mensual:',
                        value:
                            '${mensualVisual.diaCobroConfigurado} de cada mes',
                      ),
                      _InfoRow(
                        label: 'Cuota ciclo mensual:',
                        value: DateFormatter.formatCurrency(
                          mensualVisual.cuotaCicloMensual,
                        ),
                      ),
                      _InfoRow(
                        label: 'Acumulado mes a hoy:',
                        value: DateFormatter.formatCurrency(
                          mensualVisual.acumuladoHastaHoy,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // --- PANEL SUPERIOR REACTIVO ---
                    Builder(
                      builder: (context) {
                        final currMonto = double.tryParse(montoCtrl.text) ?? 0;
                        final currExtraer = usarSaldoFavor
                            ? (double.tryParse(montoSaldoFavorCtrl.text) ?? 0)
                            : 0;
                        final deudaVencidaActual = _deudaVencidaReal(local);

                        final dist = CalculadoraDistribucionPago.calcular(
                          montoEfectivo: currMonto,
                          deudaAcumuladaInicial: deudaVencidaActual,
                          cuotaDiaria: local.cuotaDiaria ?? 0,
                          pagadoHoyPreviamente: pagadoHoy,
                          saldoFavorInicial: local.saldoAFavor ?? 0,
                          fechaReferencia: DateTime.now(),
                          saldoAExtraer: currExtraer,
                        );

                        Widget buildDynamicRow({
                          required String label,
                          required String value,
                          String? subtitle,
                          Color? valueColor,
                        }) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (subtitle != null &&
                                          subtitle.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                            right: 8,
                                          ),
                                          child: Text(
                                            subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: valueColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        valueColor ??
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Formatear proyecciones de tiempo
                        String rangoDeudaStr = '';
                        if (dist.diasAtrasadosSaldados > 0 &&
                            dist.inicioDeudaPagada != null &&
                            dist.finDeudaPagada != null) {
                          final ini =
                              '${dist.inicioDeudaPagada!.day.toString().padLeft(2, '0')}/${dist.inicioDeudaPagada!.month.toString().padLeft(2, '0')}/${dist.inicioDeudaPagada!.year}';
                          final fin =
                              '${dist.finDeudaPagada!.day.toString().padLeft(2, '0')}/${dist.finDeudaPagada!.month.toString().padLeft(2, '0')}/${dist.finDeudaPagada!.year}';
                          rangoDeudaStr = dist.diasAtrasadosSaldados == 1
                              ? 'Cubre el $ini'
                              : 'Cubre del $ini al $fin';
                        }

                        String rangoAdelantoStr = '';
                        if (dist.diasAdelantados > 0 &&
                            dist.inicioDiasAdelantados != null &&
                            dist.finDiasAdelantados != null) {
                          final ini =
                              '${dist.inicioDiasAdelantados!.day.toString().padLeft(2, '0')}/${dist.inicioDiasAdelantados!.month.toString().padLeft(2, '0')}/${dist.inicioDiasAdelantados!.year}';
                          final fin =
                              '${dist.finDiasAdelantados!.day.toString().padLeft(2, '0')}/${dist.finDiasAdelantados!.month.toString().padLeft(2, '0')}/${dist.finDiasAdelantados!.year}';
                          rangoAdelantoStr = dist.diasAdelantados == 1
                              ? 'Adelanta el $ini'
                              : 'Adelanta del $ini al $fin';
                        }

                        final isTyping = currMonto > 0 || currExtraer > 0;
                        final realFaltanteHoy =
                            ((local.cuotaDiaria ?? 0) - pagadoHoy).clamp(
                              0,
                              (local.cuotaDiaria ?? 0),
                            );

                        final cuotaLocal = local.cuotaDiaria ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isTyping) ...[
                              // === ESTADO REAL (sin teclear) ===
                              if ((local.saldoAFavor ?? 0) > 0)
                                buildDynamicRow(
                                  label: 'Saldo a favor',
                                  value: DateFormatter.formatCurrency(
                                    local.saldoAFavor ?? 0,
                                  ),
                                  valueColor: AppColors.success,
                                ),
                              if (deudaVencidaActual > 0)
                                buildDynamicRow(
                                  label: 'Deuda acumulada (hasta ayer)',
                                  value: DateFormatter.formatCurrency(
                                    deudaVencidaActual,
                                  ),
                                  valueColor: AppColors.danger,
                                ),
                              buildDynamicRow(
                                label: 'Cuota de hoy',
                                value: realFaltanteHoy == 0
                                    ? (cuotaLocal > 0 ? 'Saldada' : 'N/A')
                                    : 'Falta ${DateFormatter.formatCurrency(realFaltanteHoy)}',
                                valueColor: realFaltanteHoy == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : AppColors.warning,
                              ),
                            ] else ...[
                              // === DISTRIBUCIÓN DEL PAGO (tecleando) ===
                              if (dist.paraDeudaReal > 0)
                                buildDynamicRow(
                                  label: 'Abono a deuda',
                                  value: DateFormatter.formatCurrency(
                                    dist.paraDeudaReal,
                                  ),
                                  subtitle: rangoDeudaStr,
                                  valueColor: AppColors.danger,
                                ),
                              if (dist.deudaFinalResultante > 0)
                                buildDynamicRow(
                                  label: 'Deuda restante',
                                  value: DateFormatter.formatCurrency(
                                    dist.deudaFinalResultante,
                                  ),
                                  valueColor: AppColors.danger,
                                ),
                              buildDynamicRow(
                                label: 'Cuota de hoy',
                                value:
                                    dist.estadoCuotaHoy == 0 && cuotaLocal > 0
                                    ? 'Completa'
                                    : 'Falta ${DateFormatter.formatCurrency(dist.estadoCuotaHoy)}',
                                subtitle: dist.pagoACuotaHoy > 0
                                    ? 'Se abonó ${DateFormatter.formatCurrency(dist.pagoACuotaHoy)}'
                                    : (dist.paraDeudaReal > 0
                                          ? 'El pago fue a deuda antigua'
                                          : null),
                                valueColor: dist.estadoCuotaHoy == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : AppColors.warning,
                              ),
                              if (dist.saldoFavorFinalResultante > 0)
                                buildDynamicRow(
                                  label: 'Saldo a favor',
                                  value: DateFormatter.formatCurrency(
                                    dist.saldoFavorFinalResultante,
                                  ),
                                  subtitle: rangoAdelantoStr,
                                  valueColor: AppColors.success,
                                ),
                            ],

                            if (dist.saldoFavorConsumido > 0 && isTyping)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4.0,
                                  bottom: 8.0,
                                ),
                                child: Text(
                                  'Se usará L${dist.saldoFavorConsumido.toStringAsFixed(2)} del saldo a favor.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    // --- FIN PANEL SUPERIOR ---
                    const SizedBox(height: 20),
                    TextField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Monto a Cobrar',
                        prefixText: 'L ',
                      ),
                    ),

                    if ((local.saldoAFavor ?? 0) > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    '¿Usar saldo a favor?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: usarSaldoFavor,
                                  onChanged: (val) {
                                    setModalState(() {
                                      usarSaldoFavor = val;
                                      if (val) {
                                        montoSaldoFavorCtrl.text =
                                            (local.saldoAFavor ?? 0)
                                                .toDouble()
                                                .toStringAsFixed(2);
                                      } else {
                                        montoSaldoFavorCtrl.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (usarSaldoFavor) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: montoSaldoFavorCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Monto a usar (L)',
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 20,
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final parsed = double.tryParse(val) ?? 0;
                                  final maxSaldo = (local.saldoAFavor ?? 0)
                                      .toDouble();
                                  if (parsed > maxSaldo) {
                                    montoSaldoFavorCtrl.text = maxSaldo
                                        .toStringAsFixed(2);
                                    montoSaldoFavorCtrl
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset: montoSaldoFavorCtrl.text.length,
                                      ),
                                    );
                                  }
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    TextField(
                      controller: obsCtrl,
                      onChanged: (_) => setModalState(() {}),
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
                              final maxSaldo = (local.saldoAFavor ?? 0)
                                  .toDouble();
                              final saldoAExtraerRaw = usarSaldoFavor
                                  ? (double.tryParse(
                                          montoSaldoFavorCtrl.text,
                                        ) ??
                                        0)
                                  : 0;
                              final saldoAExtraer = saldoAExtraerRaw.clamp(
                                0.0,
                                maxSaldo,
                              );
                              final hayMovimiento =
                                  monto > 0 || saldoAExtraer > 0;
                              if (!hayMovimiento) return;
                              Navigator.pop(ctx);
                              final usuario = ref
                                  .read(currentUsuarioProvider)
                                  .value;
                              await _guardarCobro(
                                local: local,
                                monto: monto,
                                saldoAExtraer: saldoAExtraer,
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
      },
    );
  }

  Future<void> _guardarCobro({
    required Local local,
    required num monto,
    required num saldoAExtraer,
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

    // CONGELAR VALORES INICIALES (Evita que la vista lea el objeto mutado post-await)
    final double deudaTotalInicial = _deudaVencidaReal(local);

    final cuota = local.cuotaDiaria ?? 0;
    final saldoFavorExistente = local.saldoAFavor ?? 0;

    final now = DateTime.now();

    // Usamos la calculadora centralizada con extracción manual de saldo a favor.
    final dist = CalculadoraDistribucionPago.calcular(
      montoEfectivo: monto,
      deudaAcumuladaInicial: deudaTotalInicial,
      cuotaDiaria: cuota,
      pagadoHoyPreviamente: pagadoHoy,
      saldoFavorInicial: saldoFavorExistente,
      fechaReferencia: now,
      saldoAExtraer: saldoAExtraer,
    );

    // Estado resultante de la jornada de hoy
    final cuotaTotalHoy = pagadoHoy + dist.pagoACuotaHoy;
    final estado = cuotaTotalHoy >= cuota
        ? 'cobrado'
        : cuotaTotalHoy > 0
        ? 'abono_parcial'
        : 'pendiente';

    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';

    final double favorResultante = dist.saldoFavorFinalResultante.toDouble();

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
        pagoACuota: dist.pagoACuotaHoy,
        observaciones: monto > 0
            ? () {
                final partes = <String>[];
                if (dist.paraDeudaReal > 0) {
                  partes.add(
                    'L ${dist.paraDeudaReal.toStringAsFixed(2)} a deuda anterior',
                  );
                }
                if (dist.pagoACuotaHoy > 0) {
                  final hoyStr =
                      '${now.day.toString().padLeft(2, "0")}/${now.month.toString().padLeft(2, "0")}/${now.year}';
                  partes.add(
                    'L ${dist.pagoACuotaHoy.toStringAsFixed(2)} cuota del $hoyStr',
                  );
                }
                if (dist.saldoFavorConsumido > 0) {
                  partes.add(
                    'L ${dist.saldoFavorConsumido.toStringAsFixed(2)} de saldo a favor',
                  );
                }
                if (dist.paraNuevoSaldoFavor > 0) {
                  partes.add(
                    'L ${dist.paraNuevoSaldoFavor.toStringAsFixed(2)} a favor',
                  );
                }
                final prefijo = observaciones.isNotEmpty
                    ? '$observaciones | '
                    : '';
                return '${prefijo}Distribuido: ${partes.join(", ")}';
              }()
            : observaciones,
        saldoPendiente: (dist.deudaFinalResultante + dist.estadoCuotaHoy)
            .toDouble(),
        deudaAnterior: deudaTotalInicial,
        montoAbonadoDeuda: dist.paraDeudaReal,
        nuevoSaldoFavor: favorResultante,
        telefonoRepresentante: local.telefonoRepresentante,
      );

      final resultado = await cobroViewModel.registrarPago(
        cobro: nuevoCobro,
        localId: local.id!,
        montoAbonadoDeuda: dist.paraDeudaReal,
        incrementoSaldoFavor: dist.deltaSaldoFavor,
        fechaReferenciaMora: muni?.fechaReferenciaMora,
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
            periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
              inicioFavor,
              dias,
            );
          }
        }
        // Calcular rango de fechas cubiertas (deuda abonada) + Cuota de hoy
        String? periodoAbonadoStr;
        List<DateTime> fechasAMostrar = List<DateTime>.from(fechasSaldadas);
        // Si pagó la cuota de hoy, agregamos el día de hoy a las fechas cubiertas del recibo.
        if (dist.pagoACuotaHoy > 0) {
          final hoySinHora = DateTime(now.year, now.month, now.day);
          if (!fechasAMostrar.any(
            (d) =>
                d.year == hoySinHora.year &&
                d.month == hoySinHora.month &&
                d.day == hoySinHora.day,
          )) {
            fechasAMostrar.add(hoySinHora);
          }
        }

        if (fechasAMostrar.isNotEmpty) {
          periodoAbonadoStr = DateRangeFormatter.formatearRangos(
            fechasAMostrar,
          );
        }

        final double cuotaLocal = (local.cuotaDiaria ?? 0).toDouble();
        final double abonoCuotaHoyVal = dist.pagoACuotaHoy.toDouble();
        double? pagoHoyVal;
        double? abonoCuotaHoyMostrar;
        if (abonoCuotaHoyVal > 0) {
          pagoHoyVal = cuotaLocal - abonoCuotaHoyVal;
          if (pagoHoyVal < 0) pagoHoyVal = 0;
          abonoCuotaHoyMostrar = abonoCuotaHoyVal;
        }
        final double deudaVencidaRestante = dist.deudaFinalResultante
            .toDouble();

        await ReceiptDispatcher.presentReceiptOptions(
          context: context,
          ref: ref,
          local: local,
          monto: (monto + dist.saldoFavorConsumido).toDouble(),
          fecha: now,
          saldoPendiente: deudaVencidaRestante,
          deudaAnterior: deudaTotalInicial,
          montoAbonadoDeuda: dist.paraDeudaReal.toDouble(),
          pagoHoy: pagoHoyVal,
          abonoCuotaHoy: abonoCuotaHoyMostrar,
          saldoAFavor: favorResultante,
          numeroBoleta: correlativoStr,
          municipalidadNombre: municipalidadNombre,
          mercadoNombre: mercadoNombre,
          cobradorNombre: usuario?.nombre,
          fechasSaldadas: fechasAMostrar,
          periodoAbonadoStr: periodoAbonadoStr,
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

  Future<void> _registrarIncidenciaQr(Local local) async {
    final result = await IncidenciaBottomSheet.show(
      context,
      nombreLocal: local.nombreSocial ?? 'Local',
    );

    if (result == null || !mounted) return;

    try {
      final usuario = ref.read(currentUsuarioProvider).value;
      final ds = ref.read(gestionDatasourceProvider);

      await ds.registrarGestion(
        localId: local.id!,
        cobradorId: usuario?.id ?? '',
        tipoIncidencia: result.tipo.firestoreValue,
        comentario: result.comentario,
        latitud: local.latitud,
        longitud: local.longitud,
        municipalidadId: local.municipalidadId,
        mercadoId: local.mercadoId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📋 Incidencia registrada: ${result.tipo.label}'),
            backgroundColor: AppColors.warning,
          ),
        );
        _resetScanner();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al registrar incidencia: $e'),
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
                  onIncidencia: () => _registrarIncidenciaQr(_localEncontrado!),
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
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
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
  final VoidCallback? onIncidencia;
  final VoidCallback onScanOtro;

  const _LocalDetailPanel({
    required this.local,
    required this.onCobrar,
    this.onIncidencia,
    required this.onScanOtro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final mensualVisual = MonthlyVisualUtils.calcular(
      local,
      referencia: DateTime.now(),
    );
    final deudasMap = ref.watch(deudasVencidasCobradorProvider).value;
    final cobrosHoy =
        ref.watch(cobrosHoyCobradorProvider).value ?? const <Cobro>[];
    final deuda = _deudaHastaAyer(
      local: local,
      deudasMap: deudasMap,
      cobrosHoy: cobrosHoy,
    );

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
                  if (mensualVisual != null) ...[
                    _DetailRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Día de Cobro Mensual',
                      value: mensualVisual.diaCobroConfigurado.toString(),
                    ),
                    _DetailRow(
                      icon: Icons.event_repeat_rounded,
                      label: 'Cuota Ciclo Mensual',
                      value: DateFormatter.formatCurrency(
                        mensualVisual.cuotaCicloMensual,
                      ),
                    ),
                    _DetailRow(
                      icon: Icons.trending_up_rounded,
                      label: 'Acumulado Mes a Hoy',
                      value: DateFormatter.formatCurrency(
                        mensualVisual.acumuladoHastaHoy,
                      ),
                    ),
                  ],
                  // --- ESTADO FINANCIERO ---
                  Builder(
                    builder: (context) {
                      final cuota = (local.cuotaDiaria ?? 0).toDouble();
                      final saldoFavor = (local.saldoAFavor ?? 0).toDouble();

                      // Calcular rango de deuda si existe
                      String? rangoDeuda;
                      if (deuda > 0 && cuota > 0) {
                        final dias = (deuda / cuota).floor();
                        if (dias > 0) {
                          final hoy = DateTime.now();
                          final fin = DateTime(
                            hoy.year,
                            hoy.month,
                            hoy.day,
                          ).subtract(const Duration(days: 1));
                          final inicio = DateTime(
                            fin.year,
                            fin.month,
                            fin.day,
                          ).subtract(Duration(days: dias - 1));
                          final iniStr =
                              '${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}/${inicio.year}';
                          final finStr =
                              '${fin.day.toString().padLeft(2, '0')}/${fin.month.toString().padLeft(2, '0')}/${fin.year}';
                          rangoDeuda = dias == 1
                              ? 'Fecha: $finStr'
                              : 'Del $iniStr al $finStr ($dias días)';
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 24),
                          if (saldoFavor > 0)
                            _FinanceRow(
                              label: 'Saldo a favor',
                              value: DateFormatter.formatCurrency(saldoFavor),
                              valueColor: AppColors.success,
                              icon: Icons.savings_rounded,
                            ),
                          if (deuda > 0)
                            _FinanceRow(
                              label: 'Deuda acumulada (hasta ayer)',
                              value: DateFormatter.formatCurrency(deuda),
                              subtitle: rangoDeuda,
                              valueColor: AppColors.danger,
                              icon: Icons.warning_amber_rounded,
                            ),
                        ],
                      );
                    },
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
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onIncidencia,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE67E22),
                side: const BorderSide(color: Color(0xFFE67E22)),
              ),
              icon: const Icon(Icons.assignment_late_rounded, size: 18),
              label: const Text('Registrar Incidencia'),
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
          Icon(
            icon,
            size: 18,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
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

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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

class _FinanceRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final IconData icon;

  const _FinanceRow({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: valueColor?.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: valueColor?.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
