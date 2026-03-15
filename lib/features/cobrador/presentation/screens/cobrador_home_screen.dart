import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../cobros/data/models/hive/cobro_hive.dart';
import '../../../locales/data/models/hive/local_hive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/receipt_dispatcher.dart';
import '../../../cobros/domain/entities/cobro.dart';
import '../../../cobros/domain/utils/calculadora_distribucion.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../locales/presentation/widgets/local_form_dialog.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../cobros/data/services/deuda_service.dart';
import '../../../cobros/presentation/viewmodels/cobro_viewmodel.dart';
import '../widgets/deuda_rango_dialog.dart';
import '../../../../app/theme/app_theme.dart';
import '../widgets/incidencia_bottom_sheet.dart';

class CobradorHomeScreen extends ConsumerStatefulWidget {
  const CobradorHomeScreen({super.key});

  @override
  ConsumerState<CobradorHomeScreen> createState() => _CobradorHomeScreenState();
}

class _CobradorHomeScreenState extends ConsumerState<CobradorHomeScreen> {
  String _filtroEstado = 'pendientes'; // 'pendientes', 'cobrados'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _limiteLocales = 20;

  @override
  void initState() {
    super.initState();
    // La sincronización inicial y la verificación de deuda se pueden disparar una vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dispararSyncYVerificacion();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _dispararSyncYVerificacion() async {
    try {
      // 1. Reconexión automática de impresora (Bluetooth)
      _reconectarImpresora();

      final localRepo = ref.read(localRepositoryProvider);
      final cobroRepo = ref.read(cobroRepositoryProvider);
      final muniRepo = ref.read(municipalidadRepositoryProvider);

      localRepo.syncLocales().catchError((_) {});
      cobroRepo.syncCobros().catchError((_) {});
      muniRepo.sincronizarLocalmente().catchError((_) {});

      // Esperar a que los locales carguen en background para verificar deuda
      // Se quita el `await .future` puro para no congelar el arranque
      ref
          .read(localesCobradorProvider.future)
          .then((locales) {
            if (mounted && locales.isNotEmpty) {
              _verificarDeudaRetroactiva(locales);
            }
          })
          .catchError((e) {
            debugPrint('Error en carga background de locales: $e');
          });
    } catch (e) {
      debugPrint('Excepción en dispararSync: $e');
    }
  }

  Future<void> _reconectarImpresora() async {
    // Solo intentamos si no estamos ya conectados
    final isConnected = ref.read(printerConnectionProvider);
    if (isConnected) return;

    final mac = ref.read(connectedPrinterMacProvider);
    if (mac != null) {
      debugPrint('Bluetooth: Intentando reconexión automática a $mac');
      final printer = ref.read(printerServiceProvider);
      await printer.connect(mac).catchError((e) {
        debugPrint('Bluetooth: Error en reconexión automática: $e');
        return false;
      });
    }
  }

  Future<void> _recargarCacheManual(
    List<Local> locales,
    List<Cobro> cobrosHoy,
  ) async {
    try {
      final box = await Hive.openBox<CobroHive>('cobrosBox');
      await box.clear();
      for (final cobro in cobrosHoy) {
        final cobroH = CobroHive.fromDomain(cobro, syncStatus: 1);
        await box.put(cobroH.id, cobroH);
      }
      final boxL = await Hive.openBox<LocalHive>('localesBox');
      for (final l in locales) {
        final lH = LocalHive.fromDomain(l, syncStatus: 1);
        await boxL.put(lH.id, lH);
      }
    } catch (_) {}
  }

  /// Ejecuta la verificación de días sin cobro en background.
  /// Crea pendientes automáticos para los últimos 7 días.
  /// OPTIMIZACIÓN: Solo se ejecuta una vez al día por usuario.
  Future<void> _verificarDeudaRetroactiva(List<Local> localesActivos) async {
    try {
      final usuario = ref.read(currentUsuarioProvider).value;
      if (usuario == null) return;

      final prefs = await SharedPreferences.getInstance();
      final hoyKey = 'last_debt_scan_${usuario.id}';
      final hoyString =
          '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';

      final lastScan = prefs.getString(hoyKey);
      if (lastScan == hoyString) {
        debugPrint(
          'DeudaService: Salto de revisión (ya escaneado hoy). Costo: 0 lecturas.',
        );
        return;
      }

      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);

      // CRÍTICO: Esperar a que stats cargue para obtener fechaInicioOperaciones.
      // Si no esperamos, stats.value puede ser null y el DeudaService
      // generaría pendientes de 7 días atrás erróneamente.
      final stats = await ref.read(statsProvider.future);

      final service = DeudaService(
        cobroDs: cobroDs,
        localDs: localDs,
        firestore: FirebaseFirestore.instance,
      );

      await service.verificarYRegistrarPendientes(
        localesActivos: localesActivos,
        diasAtras: 7,
        cobradorId: usuario.id,
        fechaInicioOperaciones: stats.fechaInicioOperaciones,
      );

      // Guardar que ya se revisó hoy
      await prefs.setString(hoyKey, hoyString);
    } catch (_) {
      // Silencioso: la verificación retroactiva no debe interrumpir la UI
    }
  }

  num _montoPagadoHoy(String localId, List<Cobro> cobrosHoy) {
    return cobrosHoy
        .where((c) => c.localId == localId)
        .fold<num>(0, (acc, c) => acc + (c.pagoACuota ?? 0));
  }

  Cobro? _cobroDelLocal(String localId, List<Cobro> cobrosHoy) {
    try {
      return cobrosHoy.lastWhere((c) => c.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _eliminarCobro(Cobro cobro) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_forever_rounded,
              size: 40,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              '¿Eliminar Cobro?',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta acción revertirá los saldos y eliminará el registro. '
              'Si hubo auto-pagos posteriores, también se borrarán.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  ctx,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('Sí, Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final success = await ref
        .read(cobroViewModelProvider.notifier)
        .eliminarCobro(cobro);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Cobro eliminado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Error al eliminar el cobro'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _registrarSinPago(Local local, List<Cobro> cobrosHoy) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.money_off_rounded, size: 40, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(
              'Sin Pago',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '¿El local ${local.nombreSocial ?? ""} no realizó su pago hoy?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Se registrará una deuda de ${DateFormatter.formatCurrency(local.cuotaDiaria)} para hoy.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  ctx,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if ((local.deudaAcumulada ?? 0) > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Deuda acumulada: ${DateFormatter.formatCurrency(local.deudaAcumulada)}',
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirmar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);
      final usuario = ref.read(currentUsuarioProvider).value;
      final service = DeudaService(
        cobroDs: cobroDs,
        localDs: localDs,
        firestore: FirebaseFirestore.instance,
      );
      await service.registrarSinPago(
        local: local,
        cobradorId: usuario?.id,
        observaciones: 'Sin pago - registrado por cobrador',
      );
      // Riverpod se autoactualizara sin destruir los streams subyacentes.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📋 Sin pago registrado: ${local.nombreSocial}'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _registrarIncidencia(Local local) async {
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
            content: Text(
              '📋 Incidencia registrada: ${result.tipo.label}',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
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

  Future<void> _registrarCobro(Local local, List<Cobro> cobrosHoy) async {
    final cuota = local.cuotaDiaria ?? 0;
    final saldoActual = local.saldoAFavor ?? 0;
    final pagadoHoy = _montoPagadoHoy(local.id ?? '', cobrosHoy);
    final cuotaCubierta = pagadoHoy >= cuota;

    // Si tiene saldo a favor suficiente y NO ha pagado hoy, auto-cobrar con el crédito
    if (saldoActual >= cuota && cuota > 0 && !cuotaCubierta) {
      final confirm = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_rounded, size: 40, color: AppColors.success),
              const SizedBox(height: 12),
              Text(
                'Usar Saldo a Favor',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${local.nombreSocial ?? ""} tiene un crédito de:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormatter.formatCurrency(saldoActual),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se descontará ${DateFormatter.formatCurrency(cuota)} de ese crédito para cubrir el día de hoy.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (confirm != true || !mounted) return;
      await _aplicarSaldoAFavor(local);
      return;
    }

    // Calcular cuánto falta para la cuota hoy
    final montoCtrl = TextEditingController(text: '');
    final obsCtrl = TextEditingController();

    // Variables para saldo a favor
    bool usarSaldoFavor = false;
    final montoSaldoFavorCtrl = TextEditingController();

    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final cs = Theme.of(context).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cuotaCubierta
                        ? Icons.add_circle_outline_rounded
                        : Icons.receipt_long_rounded,
                    size: 36,
                    color: cuotaCubierta ? AppColors.success : cs.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cuotaCubierta
                        ? 'Abono Extra - ${local.nombreSocial ?? ""}'
                        : 'Cobrar - ${local.nombreSocial ?? ""}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (!cuotaCubierta)
                    _InfoRow(
                      label: 'Cuota diaria',
                      value: DateFormatter.formatCurrency(cuota),
                    ),
                  _InfoRow(
                    label: 'Representante',
                    value: local.representante ?? '-',
                  ),
                  // --- PANEL SUPERIOR REACTIVO ---
                  Builder(
                    builder: (context) {
                      final currMonto = double.tryParse(montoCtrl.text) ?? 0;
                      final currExtraer = usarSaldoFavor
                          ? (double.tryParse(montoSaldoFavorCtrl.text) ?? 0)
                          : 0;

                      final dist = CalculadoraDistribucionPago.calcular(
                        montoEfectivo: currMonto,
                        deudaAcumuladaInicial: local.deudaAcumulada ?? 0,
                        cuotaDiaria: cuota,
                        pagadoHoyPreviamente: pagadoHoy,
                        saldoFavorInicial: saldoActual,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (subtitle != null && subtitle.isNotEmpty)
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
                                  color: valueColor ?? cs.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

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

                      final isTyping = (currMonto > 0 || currExtraer > 0);
                      final realFaltanteHoy = (cuota - pagadoHoy).clamp(
                        0,
                        cuota,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isTyping) ...[
                            // === ESTADO REAL (sin teclear) ===
                            if (saldoActual > 0)
                              buildDynamicRow(
                                label: 'Saldo a favor',
                                value: DateFormatter.formatCurrency(
                                  saldoActual,
                                ),
                                valueColor: AppColors.success,
                              ),
                            if ((local.deudaAcumulada ?? 0) > 0)
                              buildDynamicRow(
                                label: 'Deuda acumulada',
                                value: DateFormatter.formatCurrency(
                                  local.deudaAcumulada ?? 0,
                                ),
                                valueColor: AppColors.danger,
                              ),
                            buildDynamicRow(
                              label: 'Cuota de hoy',
                              value: realFaltanteHoy == 0
                                  ? (cuota > 0 ? 'Saldada' : 'N/A')
                                  : 'Falta ${DateFormatter.formatCurrency(realFaltanteHoy)}',
                              valueColor: realFaltanteHoy == 0
                                  ? cs.primary
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
                              value: dist.estadoCuotaHoy == 0 && cuota > 0
                                  ? 'Completa'
                                  : 'Falta ${DateFormatter.formatCurrency(dist.estadoCuotaHoy)}',
                              subtitle: dist.pagoACuotaHoy > 0
                                  ? 'Se abonó ${DateFormatter.formatCurrency(dist.pagoACuotaHoy)}'
                                  : (dist.paraDeudaReal > 0
                                        ? 'El pago fue a deuda antigua'
                                        : null),
                              valueColor: dist.estadoCuotaHoy == 0
                                  ? cs.primary
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
                        ],
                      );
                    },
                  ),
                  // --- FIN PANEL SUPERIOR ---
                  const SizedBox(height: 16),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Efectivo Recibido (L)',
                      prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                      helperText:
                          'Si deposita más de su deuda total, se acumulará saldo a favor',
                      helperMaxLines: 2,
                    ),
                  ),
                  if (saldoActual > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.3),
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
                                  '¿Usar Saldo a Favor Disponible?',
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
                                      montoSaldoFavorCtrl.text = saldoActual
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
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Monto a Extraer (L)',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val) ?? 0;
                                if (parsed > saldoActual) {
                                  montoSaldoFavorCtrl.text = saldoActual
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
                    maxLines: 2,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Registrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != true || !mounted) return;

    final montoEfectivo = num.tryParse(montoCtrl.text) ?? 0;
    final saldoAExtraer = usarSaldoFavor
        ? (num.tryParse(montoSaldoFavorCtrl.text) ?? 0)
        : 0;

    if (montoEfectivo <= 0 && saldoAExtraer <= 0) return;

    final cobrosHoyActual = ref.read(cobrosHoyCobradorProvider).value ?? [];
    final usuario = ref.read(currentUsuarioProvider).value;

    await _guardarCobro(
      local: local,
      montoEfectivo: montoEfectivo,
      saldoAExtraer: saldoAExtraer,
      observaciones: obsCtrl.text,
      usuario: usuario,
      cobrosHoy: cobrosHoyActual,
    );
  }

  /// Aplica el saldo a favor del local para cubrir la cuota del día.
  Future<void> _aplicarSaldoAFavor(Local local) async {
    final cuota = local.cuotaDiaria ?? 0;
    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';
    final usuario = ref.read(currentUsuarioProvider).value;

    // Leer providers síncronamente antes de los await
    final cobroDs = ref.read(cobroDatasourceProvider);
    final localDs = ref.read(localDatasourceProvider);
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    try {
      final String correlativoStr = await cobroDs.crearCobroConCorrelativo(
        cobroId: docId,
        localId: local.id!,
        cobroData: {
          'cobradorId': usuario?.id ?? '',
          'creadoEn': Timestamp.fromDate(now),
          'creadoPor': usuario?.id ?? 'sistema',
          'actualizadoEn': Timestamp.fromDate(now),
          'actualizadoPor': usuario?.id ?? 'sistema',
          'cuotaDiaria': cuota,
          'estado': 'cobrado_saldo',
          'fecha': Timestamp.fromDate(now),
          'localId': local.id,
          'mercadoId': local.mercadoId,
          'municipalidadId': local.municipalidadId,
          'monto': 0, // No es efectivo real, es crédito del cliente
          'pagoACuota': cuota,
          'observaciones': 'Pagado con saldo a favor',
          'saldoPendiente': 0,
          'montoAbonadoDeuda': 0,
          'nuevoSaldoFavor':
              -cuota, // Señal para stats: descontar del saldo global
        },
      );
      // Descontar la cuota del saldo a favor
      await localDs.actualizarSaldoAFavor(local.id!, -cuota);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '💰 Cobro aplicado con saldo a favor: ${local.nombreSocial}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // --- OBTENER DATOS MAESTROS EN PARALELO (optimización de velocidad) ---
      final muniFuture = municipalidadRepo.obtenerPorId(
        local.municipalidadId ?? '',
      );
      final mercFuture = mercadoRepo.obtenerPorId(local.mercadoId ?? '');
      final muni = await muniFuture;
      final merc = await mercFuture;

      final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
      final mercadoNombre = merc?.nombre;
      // ------------------------------------------------------------------

      // --- INTEGRACIÓN DE RECEIPT DISPATCHER ---
      // Mostrar recibo ANTES de invalidar providers para evitar rebuild prematuro
      if (mounted) {
        String? periodoFavorStr;
        final saldoFinal =
            (local.saldoAFavor ?? 0).toDouble() - cuota.toDouble();
        if (saldoFinal > 0 && cuota > 0) {
          int dias = (saldoFinal / cuota).floor();
          if (dias > 0) {
            final fechaInicio = now.add(const Duration(days: 1));
            periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(
              fechaInicio,
              dias,
            );
          }
        }

        await ReceiptDispatcher.presentReceiptOptions(
          context: context,
          ref: ref,
          local: local,
          monto: cuota.toDouble(),
          fecha: now,
          saldoPendiente: (local.deudaAcumulada ?? 0).toDouble(),
          deudaAnterior: (local.deudaAcumulada ?? 0).toDouble(),
          montoAbonadoDeuda: 0, // En este caso fue saldo a favor
          pagoHoy: 0,
          abonoCuotaHoy: cuota.toDouble(),
          saldoAFavor: saldoFinal,
          numeroBoleta: correlativoStr,
          municipalidadNombre: municipalidadNombre,
          mercadoNombre: mercadoNombre,
          cobradorNombre: usuario?.nombre,
          periodoSaldoAFavorStr: periodoFavorStr,
          slogan: muni?.slogan,
        );
      }

      if (!mounted) return;
      // Refrescar datos DESPUÉS de que el usuario cierre el diálogo del recibo
      // (Eliminado ref.invalidate para no destruir el Stream de Firestore y evitar re-lecturas masivas)
    } catch (e) {
      debugPrint('❌ Error en _aplicarSaldoAFavor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Permite al cobrador cargar deuda de forma masiva seleccionando un rango.
  Future<void> _cargarDeudaPorRango(Local local) async {
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => DeudaRangoDialog(local: local),
    );

    if (picked == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Confirmar Deuda'),
          ],
        ),
        content: Text(
          'Se registrará deuda pendiente desde el ${DateFormatter.formatDate(picked.start)} hasta el ${DateFormatter.formatDate(picked.end)} para:\n\n${local.nombreSocial}\n\nLos días que ya tengan un registro serán ignorados automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final usuario = ref.read(currentUsuarioProvider).value;
    final viewModel = ref.read(cobroViewModelProvider.notifier);

    final creados = await viewModel.agregarDeudaMasiva(
      local: local,
      range: picked,
      cobradorId: usuario?.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creados > 0
                ? '✅ Se registraron $creados días de deuda para ${local.nombreSocial}'
                : 'ℹ️ No se crearon nuevos registros (ya existían o fuera de rango)',
          ),
          backgroundColor: creados > 0 ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  /// Lógica central de guardado. Maneja excedentes como abono a deuda o saldo a favor.
  /// Acepta montoEfectivo (cash) y saldoAExtraer (crédito explícito del saldo a favor).
  Future<void> _guardarCobro({
    required Local local,
    required num montoEfectivo,
    required num saldoAExtraer,
    required String observaciones,
    required dynamic usuario,
    required List<Cobro> cobrosHoy,
  }) async {
    // --- OBTENER DATOS MAESTROS síncronamente ---
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);
    final cobroViewModel = ref.read(cobroViewModelProvider.notifier);

    // --- OBTENER DATOS MAESTROS EN PARALELO (optimización de velocidad) ---
    final muniFuture = municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final mercFuture = mercadoRepo.obtenerPorId(local.mercadoId ?? '');
    final muni = await muniFuture;
    final merc = await mercFuture;

    debugPrint(
      '🏛️ [HOME] Municipalidad: ${muni?.nombre} | slogan: "${muni?.slogan}" | id buscado: ${local.municipalidadId}',
    );

    final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
    final mercadoNombre = merc?.nombre;
    // ------------------------------------------------------------------

    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';

    final deudaTotalInicial = (local.deudaAcumulada ?? 0);
    final cuotaHoy = local.cuotaDiaria ?? 0;
    final num pagadoHoyPrev = _montoPagadoHoy(local.id ?? '', cobrosHoy);
    final saldoInicial = local.saldoAFavor ?? 0;

    // Usar la calculadora centralizada
    final dist = CalculadoraDistribucionPago.calcular(
      montoEfectivo: montoEfectivo,
      deudaAcumuladaInicial: deudaTotalInicial,
      cuotaDiaria: cuotaHoy,
      pagadoHoyPreviamente: pagadoHoyPrev,
      saldoFavorInicial: saldoInicial,
      fechaReferencia: now,
    );

    // Totales y estado
    final cuotaTotalHoy = pagadoHoyPrev + dist.pagoACuotaHoy;
    final estado = cuotaTotalHoy >= cuotaHoy
        ? 'cobrado'
        : cuotaTotalHoy > 0
        ? 'abono_parcial'
        : 'pendiente';

    final double saldoResultante = dist.deudaFinalResultante.toDouble();
    final double favorResultante = dist.saldoFavorFinalResultante.toDouble();

    // Monto registrado en el cobro: solo el efectivo
    final num monto = montoEfectivo;

    try {
      // ====== MVVM REFACTOR: Utilizar CobroViewModel y Repositorios ======

      final nuevoCobro = Cobro(
        id: docId,
        cobradorId: usuario?.id ?? '',
        actualizadoEn: now,
        actualizadoPor: usuario?.id ?? 'cobrador',
        creadoEn: now,
        creadoPor: usuario?.id ?? 'cobrador',
        cuotaDiaria: cuotaHoy,
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
                if (saldoAExtraer > 0) {
                  partes.add(
                    'L ${saldoAExtraer.toStringAsFixed(2)} de saldo a favor',
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
        saldoPendiente: dist.estadoCuotaHoy,
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
      );

      final String correlativoStr = resultado.numeroBoleta ?? '0';
      final List<DateTime> fechasSaldadas = resultado.fechasSaldadas;
      // ====== END MVVM REFACTOR ======

      // --- INTEGRACIÓN DE RECEIPT DISPATCHER ---
      // IMPORTANTE: Mostrar el recibo ANTES de invalidar los providers,
      // porque ref.invalidate provoca rebuild y puede desmontar el widget.
      if (mounted) {
        String? periodoFavorStr;
        if (favorResultante > 0 && cuotaHoy > 0) {
          int dias = (favorResultante / cuotaHoy).floor();
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
        double pagoHoyVal = cuotaLocal - abonoCuotaHoyVal;
        if (pagoHoyVal < 0) pagoHoyVal = 0;

        await ReceiptDispatcher.presentReceiptOptions(
          context: context,
          ref: ref,
          local: local,
          monto: monto.toDouble(),
          fecha: now,
          saldoPendiente: saldoResultante,
          deudaAnterior: deudaTotalInicial.toDouble(),
          montoAbonadoDeuda: dist.paraDeudaReal.toDouble(),
          pagoHoy: pagoHoyVal,
          abonoCuotaHoy: abonoCuotaHoyVal,
          saldoAFavor: favorResultante.toDouble(),
          numeroBoleta: correlativoStr,
          municipalidadNombre: municipalidadNombre,
          mercadoNombre: mercadoNombre,
          cobradorNombre: usuario?.nombre,
          fechasSaldadas: fechasAMostrar,
          periodoAbonadoStr: periodoAbonadoStr,
          periodoSaldoAFavorStr: periodoFavorStr,
          slogan: muni?.slogan,
        );
      }

      if (!mounted) return;
      // Refrescar datos DESPUÉS de que el usuario cierre el diálogo del recibo
      // (Eliminado ref.invalidate para no destruir el Stream de Firestore y evitar re-lecturas masivas)
    } catch (e) {
      debugPrint('❌ Error en _guardarCobro: $e');
      if (mounted) {
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
    final usuario = ref.watch(currentUsuarioProvider).value;
    final localesAsync = ref.watch(localesCobradorProvider);
    final cobrosAsync = ref.watch(cobrosHoyCobradorProvider);

    return localesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(
        body: Center(
          child: Text(
            '❌ Error: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      data: (todosLocales) {
        final cobrosHoy = cobrosAsync.value ?? [];
        // Gestiones/incidencias del día
        final gestionesHoy = ref.watch(gestionesHoyCobradorProvider).value ?? [];
        final idsGestionadosHoySet = gestionesHoy.map((g) => g.localId ?? '').toSet();

        // 1. Filtrar locales activos
        final locales = todosLocales.where((l) => l.activo == true).toList();

        // 2. Ordenar según rutaAsignada (mantenemos lógica UI)
        if (usuario?.rutaAsignada != null &&
            usuario!.rutaAsignada!.isNotEmpty) {
          final orden = usuario.rutaAsignada!;
          locales.sort((a, b) {
            int indexA = orden.indexOf(a.id ?? '');
            int indexB = orden.indexOf(b.id ?? '');
            if (indexA == -1 && indexB == -1) return 0;
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });
        }

        // 3. Pre-cálculos para optimización O(N)
        final routeIds = locales.map((l) => l.id ?? '').toSet();
        final Map<String, num> montosPorLocal = {};
        final Map<String, num> pagosCuotaPorLocal = {};
        num montoTotalHoy = 0;

        for (final c in cobrosHoy) {
          final lid = c.localId;
          if (lid == null || !routeIds.contains(lid)) continue;
          final monto = c.monto ?? 0;
          final pagoACuota = c.pagoACuota ?? 0;
          montoTotalHoy += monto;
          montosPorLocal[lid] = (montosPorLocal[lid] ?? 0) + monto;
          pagosCuotaPorLocal[lid] = (pagosCuotaPorLocal[lid] ?? 0) + pagoACuota;
        }

        final idsCuotaCubiertaSet = locales
            .where((l) {
              final pagoCuotaL = pagosCuotaPorLocal[l.id] ?? 0;
              final saldoFavor = l.saldoAFavor ?? 0;
              final cuota = l.cuotaDiaria ?? 0;
              // CRITERIO: Un local deja de estar "Pendiente" si la cuota de HOY
              // está cubierta (por pagos directos a cuota o saldo a favor previo).
              // Un pago que fue 100% a deuda antigua NO cubre la cuota de hoy.
              return (pagoCuotaL >= cuota) || (saldoFavor >= cuota);
            })
            .map((l) => l.id ?? '')
            .toSet();

        // IDs de locales con deuda acumulada
        // IDs que tienen al menos un pago hoy (para UI de la tarjeta - Abono parcial)
        final idsCobradosHoySet = locales
            .where((l) => (montosPorLocal[l.id] ?? 0) > 0)
            .map((l) => l.id ?? '')
            .toSet();

        final localesFiltrados = locales.where((l) {
          final id = l.id ?? '';
          final cuotaCubiertaHoy = idsCuotaCubiertaSet.contains(id);

          // Filtro por Estado
          bool pasaFiltroEstado = true;
          if (_filtroEstado == 'pendientes') {
            pasaFiltroEstado = !cuotaCubiertaHoy;
          } else if (_filtroEstado == 'cobrados') {
            pasaFiltroEstado = cuotaCubiertaHoy;
          }

          // Filtro de Búsqueda
          bool pasaFiltroTexto = true;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final nombre = (l.nombreSocial ?? '').toLowerCase();
            final rep = (l.representante ?? '').toLowerCase();
            final currClave = (l.clave ?? '').toLowerCase();
            final codigo = (l.codigo ?? '').toLowerCase();
            final codigoCatastral = (l.codigoCatastral ?? '').toLowerCase();
            pasaFiltroTexto =
                nombre.contains(q) ||
                rep.contains(q) ||
                currClave.contains(q) ||
                codigo.contains(q) ||
                codigoCatastral.contains(q);
          }

          return pasaFiltroEstado && pasaFiltroTexto;
        }).toList();

        final int pendientesHoyCount =
            locales.length - idsCuotaCubiertaSet.length;
        final int cobradosHoyCount = idsCuotaCubiertaSet.length;

        final colorScheme = Theme.of(context).colorScheme;

        final localesPaginados = localesFiltrados.take(_limiteLocales).toList();
        final bool hasMore = localesFiltrados.length > _limiteLocales;

        // Disparar recarga de Hive en segundo plano si los datos cambiaron
        _recargarCacheManual(locales, cobrosHoy);

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(localesCobradorProvider);
              ref.invalidate(cobrosHoyCobradorProvider);
              await Future.wait([
                ref.read(localesCobradorProvider.future),
                ref.read(cobrosHoyCobradorProvider.future),
              ]);
            },
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ruta de Cobro',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.cleaning_services_rounded,
                                    color: colorScheme.secondary,
                                  ),
                                  tooltip:
                                      'Limpiar Caché Local (Cobros Fantasma)',
                                  onPressed: () async {
                                    final confirm = await showModalBottomSheet<bool>(
                                      context: context,
                                      builder: (ctx) => Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          8,
                                          24,
                                          32,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.cleaning_services_rounded,
                                              size: 36,
                                              color: AppColors.warning,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Limpiar Caché Local',
                                              style: Theme.of(ctx)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Esto borrará los cobros almacenados localmente en el dispositivo para eliminar cobros fantasma.\n\nLos datos en la nube NO se borran. ¿Continuar?',
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 20),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: FilledButton(
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              AppColors.warning,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Limpiar',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (confirm != true || !mounted) return;
                                    try {
                                      await ref
                                          .read(cobroDatasourceProvider)
                                          .limpiarCacheLocal();
                                      ref.invalidate(localesCobradorProvider);
                                      ref.invalidate(cobrosHoyCobradorProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '🧹 Caché limpiada. Recargando...',
                                            ),
                                            backgroundColor: AppColors.warning,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.bug_report,
                                    color: AppColors.danger,
                                  ),
                                  tooltip: 'Ver BD Local (Hive)',
                                  onPressed: () => _mostrarDebugHive(context),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.cloud_download_rounded,
                                    color: colorScheme.secondary,
                                  ),
                                  tooltip: 'Descargar Offline',
                                  onPressed: () =>
                                      _descargarDatosManual(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormatter.formatDate(DateTime.now()),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cobrado hoy: ${DateFormatter.formatCurrency(montoTotalHoy)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Buscador
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _limiteLocales = 20;
                          }),
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Buscar local, dueño o código...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _limiteLocales = 20;
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Filtros en formato estático
                        Row(
                          children: [
                            Expanded(
                              child: _EstadoFilterOption(
                                label: 'Pendientes',
                                count: pendientesHoyCount < 0
                                    ? 0
                                    : pendientesHoyCount,
                                isSelected: _filtroEstado == 'pendientes',
                                icon: Icons.pending_actions_rounded,
                                accentColor: const Color(0xFFFF9F43),
                                onTap: () => setState(
                                  () => _filtroEstado = 'pendientes',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _EstadoFilterOption(
                                label: 'Cobrados',
                                count: cobradosHoyCount,
                                isSelected: _filtroEstado == 'cobrados',
                                icon: Icons.check_circle_outline_rounded,
                                accentColor: AppColors.success,
                                onTap: () =>
                                    setState(() => _filtroEstado = 'cobrados'),
                              ),
                            ),
                          ],
                        ),
                        //const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                // Lista
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (localesPaginados.isEmpty) {
                          final sinAsignacion = locales.isEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    sinAsignacion
                                        ? Icons.lock_person_rounded
                                        : Icons.search_off_rounded,
                                    size: 48,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    sinAsignacion
                                        ? 'No tienes locales asignados.\nContacta al administrador.'
                                        : 'No hay locales con este filtro',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (index >= localesPaginados.length) {
                          if (hasMore) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _limiteLocales += 20),
                                  icon: const Icon(Icons.expand_more_rounded),
                                  label: const Text('Cargar más locales'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        final local = localesPaginados[index];
                        final lid = local.id ?? '';
                        final cobradoHoy = idsCobradosHoySet.contains(lid);
                        final cuotaCubierta = idsCuotaCubiertaSet.contains(lid);
                        final ultimoCobro = _cobroDelLocal(lid, cobrosHoy);
                        final usuario = ref.watch(currentUsuarioProvider).value;
                        final esAdminWeb =
                            kIsWeb && (usuario?.esAdmin ?? false);

                        final gestionado = idsGestionadosHoySet.contains(lid);

                        return _LocalCard(
                          local: local,
                          cobrado: cobradoHoy,
                          cuotaCubierta: cuotaCubierta,
                          gestionado: gestionado,
                          cobroExistente: ultimoCobro,
                          onCobrar: () => _registrarCobro(local, cobrosHoy),
                          onEditar: () => showLocalFormDialog(
                            context,
                            local: local,
                            onSuccess: () =>
                                ref.invalidate(localesCobradorProvider),
                          ),
                          onSinPago: cobradoHoy
                              ? null
                              : () => _registrarSinPago(local, cobrosHoy),
                          onIncidencia: () => _registrarIncidencia(local),
                          onVerHistorial: () => context.push(
                            '/cobrador/local/$lid/historial',
                            extra: local,
                          ),
                          onVerEstadoCuenta: () => context.push(
                            '/cobrador/local/$lid/cuenta',
                            extra: local,
                          ),
                          onEliminar: (ultimoCobro == null || !esAdminWeb)
                              ? null
                              : () => _eliminarCobro(ultimoCobro),
                          onCargarDeuda: () => _cargarDeudaPorRango(local),
                        );
                      },
                      childCount: localesPaginados.isEmpty
                          ? 1
                          : localesPaginados.length + (hasMore ? 1 : 0),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/cobrador/scan');
              // Al ser reactivo, no necesitamos llamar a cargarDatos manual al volver del escaneo
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(
              'Escanear QR',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Future<void> _mostrarDebugHive(BuildContext context) async {
    final cobrosBox = await Hive.openBox<CobroHive>('cobrosBox');
    final localesBox = await Hive.openBox<LocalHive>('localesBox');
    final cobrosNube = cobrosBox.values
        .where((c) => c.syncStatus == 1)
        .toList();
    final cobrosPendientes = cobrosBox.values
        .where((c) => c.syncStatus == 0)
        .toList();
    final localesAgregados = localesBox.values.toList();

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Offline Storage',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📂 Locales Bajados: ${localesAgregados.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '💰 Cobros Bajados (Nube): ${cobrosNube.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '⏳ Cobros Pendientes (Local): ${cobrosPendientes.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                    const Divider(),
                    const Text('Recientes Pendientes:'),
                    ...cobrosPendientes.map(
                      (cobro) => ListTile(
                        title: Text('Monto: L ${cobro.monto}'),
                        subtitle: Text(
                          'ID: ${cobro.id}\nLocal UUID: ${cobro.localId}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _descargarDatosManual(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Descargando Ruta para Modo Offline...'),
        duration: Duration(seconds: 2),
      ),
    );
    await _dispararSyncYVerificacion();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Descarga Completada!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _EstadoFilterOption extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  const _EstadoFilterOption({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? accentColor
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? accentColor : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accentColor : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalCard extends StatelessWidget {
  final Local local;
  final bool cobrado;
  final bool cuotaCubierta;
  final bool gestionado;
  final Cobro? cobroExistente;
  final VoidCallback onCobrar;
  final VoidCallback? onSinPago;
  final VoidCallback? onIncidencia;
  final VoidCallback? onVerHistorial;
  final VoidCallback? onVerEstadoCuenta;
  final VoidCallback? onEliminar;
  final VoidCallback? onEditar;
  final VoidCallback? onCargarDeuda;

  const _LocalCard({
    required this.local,
    required this.cobrado,
    required this.cuotaCubierta,
    this.gestionado = false,
    required this.cobroExistente,
    required this.onCobrar,
    this.onSinPago,
    this.onIncidencia,
    this.onVerHistorial,
    this.onVerEstadoCuenta,
    this.onEliminar,
    this.onEditar,
    this.onCargarDeuda,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tieneDeuda = (local.deudaAcumulada ?? 0) > 0;
    final tieneSaldo = (local.saldoAFavor ?? 0) > 0;
    final cardStatusColor = (cuotaCubierta || cobrado)
        ? AppColors.success
        : gestionado
            ? const Color(0xFFE67E22)
            : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardStatusColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Fila superior: ícono + info + cuota ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono de estado
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: cardStatusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        cuotaCubierta
                            ? Icons.check_circle_rounded
                            : cobrado
                            ? Icons.add_task_rounded
                            : Icons.storefront_rounded,
                        color: cardStatusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  local.nombreSocial ?? 'Sin nombre',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        decoration: cuotaCubierta
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                ),
                              ),
                              // El botón de editar se movió a la fila inferior
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            local.representante ?? '—',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (local.clave != null && local.clave!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Clave: ${local.clave}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (local.codigo != null && local.codigo!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Código: ${local.codigo}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          // codigoCatastral mantenido por retrocompatibilidad visual si existe
                          if (local.codigoCatastral != null &&
                              local.codigoCatastral!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Cód. Catastral: ${local.codigoCatastral}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 4),
                          // Badges de deuda / saldo / frecuencia
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _SmallBadge(
                                icon: Icons.schedule_rounded,
                                label:
                                    local.frecuenciaCobro?.toUpperCase() ??
                                    'DIARIA',
                                color: colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              if (tieneDeuda)
                                _SmallBadge(
                                  icon: Icons.warning_amber_rounded,
                                  label:
                                      '-${DateFormatter.formatCurrency(local.deudaAcumulada ?? 0)}',
                                  color: AppColors.danger,
                                ),
                              if (tieneSaldo)
                                _SmallBadge(
                                  icon: Icons.savings_rounded,
                                  label:
                                      '+${DateFormatter.formatCurrency(local.saldoAFavor ?? 0)}',
                                  color: AppColors.success,
                                ),
                              if (gestionado && !cuotaCubierta)
                                _SmallBadge(
                                  icon: Icons.assignment_turned_in_rounded,
                                  label: 'VISITADO',
                                  color: const Color(0xFFE67E22),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Cuota diaria en la esquina superior derecha
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormatter.formatCurrency(local.cuotaDiaria),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: cuotaCubierta
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'por día',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Divisor ──────────────────────────────────────────────â”€
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),

              // ── Fila de botones abajo ────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  children: [
                    // Botón principal: Cobrar / Cobrado
                    Expanded(
                      flex: 2,
                      child: _CardButton(
                        onTap: onCobrar,
                        icon: cuotaCubierta
                            ? Icons.add_circle_outline_rounded
                            : Icons.payments_rounded,
                        label: cuotaCubierta ? 'Abonar / Adelantar' : 'Cobrar',
                        color: colorScheme.primary,
                        filled: !cuotaCubierta,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    // Botón estado de cuenta
                    Expanded(
                      flex: 2,
                      child: _CardButton(
                        onTap: onVerEstadoCuenta,
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Estado',
                        color: colorScheme.primary,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    // Botón registrar incidencia
                    Expanded(
                      flex: 2,
                      child: _CardButton(
                        onTap: onIncidencia,
                        icon: gestionado
                            ? Icons.assignment_turned_in_rounded
                            : Icons.assignment_late_rounded,
                        label: gestionado ? 'Visitado' : 'Incidencia',
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    // Botón Cargar Deuda
                    Expanded(
                      flex: 2,
                      child: _CardButton(
                        onTap: onCargarDeuda,
                        icon: Icons.history_edu_rounded,
                        label: 'Deuda',
                        color: AppColors.danger,
                      ),
                    ),
                    if (onEditar != null) ...[
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      // Botón editar
                      Expanded(
                        flex: 2,
                        child: _CardButton(
                          onTap: onEditar,
                          icon: Icons.edit_rounded,
                          label: 'Editar',
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    if (local.latitud != null && local.longitud != null) ...[
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      // Botón ubicación
                      Expanded(
                        flex: 1,
                        child: _CardButton(
                          onTap: () async {
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
                          icon: Icons.location_on_rounded,
                          label: 'Mapa',
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    if (cobrado && onEliminar != null) ...[
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      Expanded(
                        flex: 1,
                        child: _CardButton(
                          onTap: onEliminar,
                          icon: Icons.delete_outline_rounded,
                          label: 'Borrar',
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón pequeño en la barra inferior de la tarjeta.
class _CardButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _CardButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: filled
            ? BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap == null
                  ? colorScheme.onSurface.withValues(alpha: 0.24)
                  : color,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: onTap == null
                    ? colorScheme.onSurface.withValues(alpha: 0.24)
                    : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge pequeño de estado (deuda/saldo) dentro de la tarjeta.
class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SmallBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
