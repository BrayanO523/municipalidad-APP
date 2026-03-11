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
import '../../../locales/domain/entities/local.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../cobros/data/services/deuda_service.dart';
import '../../../cobros/presentation/viewmodels/cobro_viewmodel.dart';
import '../../../../app/theme/app_theme.dart';

class CobradorHomeScreen extends ConsumerStatefulWidget {
  const CobradorHomeScreen({super.key});

  @override
  ConsumerState<CobradorHomeScreen> createState() => _CobradorHomeScreenState();
}

class _CobradorHomeScreenState extends ConsumerState<CobradorHomeScreen> {
  String _filtroEstado = 'todos'; // 'todos', 'pendientes', 'cobrados'
  String _filtroFrecuencia = 'todos'; // 'todos', 'diaria', 'semanal', 'quincenal', 'mensual'
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
      ref.read(localesCobradorProvider.future).then((locales) {
        if (mounted && locales.isNotEmpty) {
          _verificarDeudaRetroactiva(locales);
        }
      }).catchError((e) {
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
      final hoyString = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      
      final lastScan = prefs.getString(hoyKey);
      if (lastScan == hoyString) {
        debugPrint('DeudaService: Salto de revisión (ya escaneado hoy). Costo: 0 lecturas.');
        return;
      }

      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);
      
      final service = DeudaService(
        cobroDs: cobroDs,
        localDs: localDs,
        firestore: FirebaseFirestore.instance,
      );

      await service.verificarYRegistrarPendientes(
        localesActivos: localesActivos,
        diasAtras: 7,
        cobradorId: usuario.id,
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
        .fold<num>(0, (acc, c) => acc + (c.monto ?? 0));
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
            Icon(Icons.delete_forever_rounded, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              '¿Eliminar Cobro?',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta acción revertirá los saldos y eliminará el registro. '
              'Si hubo auto-pagos posteriores, también se borrarán.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if ((local.deudaAcumulada ?? 0) > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
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
      ref.invalidate(cobrosHoyCobradorProvider);
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
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('${local.nombreSocial ?? ""} tiene un crédito de:',
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
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
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
    final faltanteHoy = (cuota - pagadoHoy).clamp(0, cuota);

    final montoCtrl = TextEditingController(
      text: cuotaCubierta ? '' : faltanteHoy.toStringAsFixed(0),
    );
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
              left: 24, right: 24, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (!cuotaCubierta)
                    _InfoRow(
                      label: 'Cuota diaria',
                      value: DateFormatter.formatCurrency(cuota),
                    ),
                  if (pagadoHoy > 0)
                    _InfoRow(
                      label: 'Pagado hoy',
                      value: DateFormatter.formatCurrency(pagadoHoy),
                      color: AppColors.success,
                    ),
                  if (faltanteHoy > 0 && pagadoHoy > 0)
                    _InfoRow(
                      label: 'Faltante cuota',
                      value: DateFormatter.formatCurrency(faltanteHoy),
                      color: AppColors.warning,
                    ),
                  _InfoRow(
                    label: 'Representante',
                    value: local.representante ?? '-',
                  ),
                  if (saldoActual > 0)
                    _InfoRow(
                      label: 'Saldo a favor Total',
                      value: DateFormatter.formatCurrency(saldoActual),
                      color: AppColors.success,
                    ),
                  if ((local.deudaAcumulada ?? 0) > 0)
                    _InfoRow(
                      label: 'Deuda Acumulada',
                      value: DateFormatter.formatCurrency(local.deudaAcumulada),
                      color: AppColors.danger,
                    ),
                  _InfoRow(
                    label: 'Balance Neto',
                    value: DateFormatter.formatCurrency(local.balanceNeto),
                    color: local.balanceNeto >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
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
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                              ),
                              Switch(
                                value: usarSaldoFavor,
                                onChanged: (val) {
                                  setModalState(() {
                                    usarSaldoFavor = val;
                                    if (val) {
                                      montoSaldoFavorCtrl.text = saldoActual.toStringAsFixed(2);
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
                                prefixIcon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val) ?? 0;
                                if (parsed > saldoActual) {
                                  montoSaldoFavorCtrl.text = saldoActual.toStringAsFixed(2);
                                  montoSaldoFavorCtrl.selection = TextSelection.fromPosition(
                                    TextPosition(offset: montoSaldoFavorCtrl.text.length),
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsCtrl,
                    maxLines: 2,
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
    final saldoAExtraer = usarSaldoFavor ? (num.tryParse(montoSaldoFavorCtrl.text) ?? 0) : 0;
    
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
          'estado': 'cobrado',
          'fecha': Timestamp.fromDate(now),
          'localId': local.id,
          'mercadoId': local.mercadoId,
          'municipalidadId': local.municipalidadId,
          'monto': cuota,
          'observaciones': 'Pagado con saldo a favor',
          'saldoPendiente': 0,
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

      // --- OBTENER DATOS MAESTROS (Con soporte offline vía repositorios) ---
      final muni = await municipalidadRepo.obtenerPorId(
        local.municipalidadId ?? '',
      );
      final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

      final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
      final mercadoNombre = merc?.nombre;
      // ------------------------------------------------------------------

      // --- INTEGRACIÓN DE RECEIPT DISPATCHER ---
      // Mostrar recibo ANTES de invalidar providers para evitar rebuild prematuro
      if (mounted) {
        String? periodoFavorStr;
        final saldoFinal = (local.saldoAFavor ?? 0).toDouble() - cuota.toDouble();
        if (saldoFinal > 0 && cuota > 0) {
          int dias = (saldoFinal / cuota).floor();
          if (dias > 0) {
            final fechaInicio = now.add(const Duration(days: 1));
            periodoFavorStr = DateRangeFormatter.calcularPeriodoFuturo(fechaInicio, dias);
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
      ref.invalidate(localesCobradorProvider);
      ref.invalidate(cobrosHoyCobradorProvider);
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

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    debugPrint('🏛️ [HOME] Municipalidad: ${muni?.nombre} | slogan: "${muni?.slogan}" | id buscado: ${local.municipalidadId}');

    final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
    final mercadoNombre = merc?.nombre;
    // ------------------------------------------------------------------

    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';

    final deudaTotalInicial = (local.deudaAcumulada ?? 0);
    final cuotaHoy = local.cuotaDiaria ?? 0;

    // --- BOLSA TOTAL = Efectivo + Saldo a Extraer ---
    final num bolsaTotal = montoEfectivo + saldoAExtraer;

    // --- LÓGICA DE DISTRIBUCIÓN EN CASCADA ---
    // 1. Pagar cuota de hoy (Prioridad 1)
    final num pagadoHoyPrev = _montoPagadoHoy(local.id ?? '', cobrosHoy);
    final num faltanteHoy = (cuotaHoy - pagadoHoyPrev).clamp(0, cuotaHoy);
    final pagoACuota = bolsaTotal > faltanteHoy ? faltanteHoy : bolsaTotal;
    final num montoRestanteTrasHoy = (bolsaTotal - pagoACuota).clamp(
      0,
      double.infinity,
    );

    // 2. Pagar deuda acumulada con excedente (Prioridad 2)
    final deudaPast = local.deudaAcumulada ?? 0;
    final paraDeudaReal = montoRestanteTrasHoy > deudaPast
        ? deudaPast
        : montoRestanteTrasHoy;
    final num montoRestanteTrasDeuda = (montoRestanteTrasHoy - paraDeudaReal)
        .clamp(0, double.infinity);

    // 3. Excedente a Nuevo Saldo a Favor (Prioridad 3)
    final paraSaldoFavorReal = montoRestanteTrasDeuda;

    // Delta neto del saldo: nuevo excedente generado - saldo explícitamente extraído
    final num deltaSaldoFavor = paraSaldoFavorReal - saldoAExtraer;

    // Totales
    final saldoHoy = (faltanteHoy - pagoACuota).clamp(0, cuotaHoy);
    final cuotaTotalHoy = pagadoHoyPrev + pagoACuota;
    final estado = cuotaTotalHoy >= cuotaHoy
        ? 'cobrado'
        : cuotaTotalHoy > 0
        ? 'abono_parcial'
        : 'pendiente';

    final double saldoResultante =
        (local.deudaAcumulada ?? 0).toDouble() -
        paraDeudaReal.toDouble() +
        saldoHoy.toDouble();
    final double favorResultante =
        (local.saldoAFavor ?? 0).toDouble() + deltaSaldoFavor.toDouble();

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
        pagoACuota: pagoACuota,
        observaciones: monto > 0
            ? () {
                final partes = <String>[];
                if (paraDeudaReal > 0) {
                  partes.add(
                    'L ${paraDeudaReal.toStringAsFixed(2)} a deuda anterior',
                  );
                }
                if (pagoACuota > 0) {
                  final hoyStr =
                      '${now.day.toString().padLeft(2, "0")}/${now.month.toString().padLeft(2, "0")}/${now.year}';
                  partes.add(
                    'L ${pagoACuota.toStringAsFixed(2)} cuota del $hoyStr',
                  );
                }
                if (saldoAExtraer > 0) {
                  partes.add(
                    'L ${saldoAExtraer.toStringAsFixed(2)} de saldo a favor',
                  );
                }
                if (paraSaldoFavorReal > 0) {
                  partes.add(
                    'L ${paraSaldoFavorReal.toStringAsFixed(2)} a favor',
                  );
                }
                final prefijo = observaciones.isNotEmpty
                    ? '$observaciones | '
                    : '';
                return '${prefijo}Distribuido: ${partes.join(", ")}';
              }()
            : observaciones,
        saldoPendiente: saldoHoy,
        deudaAnterior: deudaTotalInicial,
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
          deudaAnterior: deudaTotalInicial.toDouble(),
          montoAbonadoDeuda: paraDeudaReal.toDouble(),
          saldoAFavor: favorResultante.toDouble(),
          numeroBoleta: correlativoStr,
          municipalidadNombre: municipalidadNombre,
          mercadoNombre: mercadoNombre,
          cobradorNombre: usuario?.nombre,
          fechasSaldadas: fechasSaldadas,
          periodoSaldoAFavorStr: periodoFavorStr,
          slogan: muni?.slogan,
        );
      }

      if (!mounted) return;
      // Refrescar datos DESPUÉS de que el usuario cierre el diálogo del recibo
      ref.invalidate(localesCobradorProvider);
      ref.invalidate(cobrosHoyCobradorProvider);
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
              final montoTotalL = montosPorLocal[l.id] ?? 0;
              final saldoFavor = l.saldoAFavor ?? 0;
              final cuota = l.cuotaDiaria ?? 0;
              // CRITERIO: Un local deja de estar "Pendiente" si ya pagó hoy
              // (aunque el pago se haya ido a la deuda) o si su saldo previo ya cubría hoy.
              return (montoTotalL > 0) || (saldoFavor >= cuota);
            })
            .map((l) => l.id ?? '')
            .toSet();

        // IDs que tienen al menos un pago hoy
        final idsCobradosHoySet = locales
            .where((l) => (montosPorLocal[l.id] ?? 0) > 0)
            .map((l) => l.id ?? '')
            .toSet();

        final localesFiltrados = locales.where((l) {
          final cuotaCubierta = idsCuotaCubiertaSet.contains(l.id ?? '');
          
          // Filtro por Estado
          bool pasaFiltroEstado = true;
          if (_filtroEstado == 'pendientes') pasaFiltroEstado = !cuotaCubierta;
          if (_filtroEstado == 'cobrados') pasaFiltroEstado = cuotaCubierta;

          // Filtro por Frecuencia
          bool pasaFiltroFrecuencia = true;
          if (_filtroFrecuencia != 'todos') {
            final freqStr = l.frecuenciaCobro ?? 'diaria';
            pasaFiltroFrecuencia = freqStr == _filtroFrecuencia;
          }

          // Filtro de Búsqueda
          bool pasaFiltroTexto = true;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final nombre = (l.nombreSocial ?? '').toLowerCase();
            final rep = (l.representante ?? '').toLowerCase();
            final currClave = (l.clave ?? '').toLowerCase();
            pasaFiltroTexto =
                nombre.contains(q) ||
                rep.contains(q) ||
                currClave.contains(q);
          }

          return pasaFiltroEstado && pasaFiltroFrecuencia && pasaFiltroTexto;
        }).toList();

        // --- Cálculos de Contadores para Chips ---
        // Estados
        final int totalesCount = locales.length;
        final int cobradosCount = idsCuotaCubiertaSet.length;
        final int pendientesCount = totalesCount - cobradosCount;

        // Frecuencias
        int diariosCount = 0;
        int semanalesCount = 0;
        int quincenalesCount = 0;
        int mensualesCount = 0;

        for (var loc in locales) {
          final f = loc.frecuenciaCobro ?? 'diaria';
          if (f == 'diaria') {
            diariosCount++;
          } else if (f == 'semanal') {
            semanalesCount++;
          } else if (f == 'quincenal') {
            quincenalesCount++;
          } else if (f == 'mensual') {
            mensualesCount++;
          }
        }
        // ----------------------------------------

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
                                  icon: const Icon(
                                    Icons.cleaning_services_rounded,
                                    color: Colors.orangeAccent,
                                  ),
                                  tooltip:
                                      'Limpiar Caché Local (Cobros Fantasma)',
                                  onPressed: () async {
                                    final confirm = await showModalBottomSheet<bool>(
                                      context: context,
                                      builder: (ctx) => Padding(
                                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.cleaning_services_rounded, size: 36, color: AppColors.warning),
                                            const SizedBox(height: 12),
                                            Text('Limpiar Caché Local', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Esto borrará los cobros almacenados localmente en el dispositivo para eliminar cobros fantasma.\n\nLos datos en la nube NO se borran. ¿Continuar?',
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 20),
                                            Row(children: [
                                              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar'))),
                                              const SizedBox(width: 12),
                                              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.warning), onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpiar'))),
                                            ]),
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
                                  icon: const Icon(
                                    Icons.cloud_download_rounded,
                                    color: Colors.blueAccent,
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
                        Text(
                          DateFormatter.formatDate(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
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
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                            prefixIcon: Icon(
                              Icons.search,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                        const SizedBox(height: 20),
                        // Filtros en formato Chips Scrolleables
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            children: [
                              // --- Bloque 1: Estados ---
                              _CustomFilterChip(
                                label: 'Todos',
                                count: totalesCount.toString(),
                                isSelected: _filtroEstado == 'todos',
                                baseColor: colorScheme.primary,
                                icon: Icons.list_alt_rounded,
                                onTap: () => setState(() => _filtroEstado = 'todos'),
                              ),
                              _CustomFilterChip(
                                label: 'Pendientes',
                                count: pendientesCount.toString(),
                                isSelected: _filtroEstado == 'pendientes',
                                baseColor: Colors.orange,
                                icon: Icons.pending_actions_rounded,
                                onTap: () => setState(() => _filtroEstado = 'pendientes'),
                              ),
                              _CustomFilterChip(
                                label: 'Cobrados',
                                count: cobradosCount.toString(),
                                isSelected: _filtroEstado == 'cobrados',
                                baseColor: AppColors.success,
                                icon: Icons.check_circle_rounded,
                                onTap: () => setState(() => _filtroEstado = 'cobrados'),
                              ),

                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 30,
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 12),

                              // --- Bloque 2: Frecuencias ---
                              _CustomFilterChip(
                                label: 'Frec. Todas',
                                isSelected: _filtroFrecuencia == 'todos',
                                baseColor: Colors.indigoAccent,
                                icon: Icons.filter_alt_outlined,
                                onTap: () => setState(() => _filtroFrecuencia = 'todos'),
                              ),
                              if (diariosCount > 0)
                                _CustomFilterChip(
                                  label: 'Diarios',
                                  count: diariosCount.toString(),
                                  isSelected: _filtroFrecuencia == 'diaria',
                                  baseColor: Colors.indigoAccent,
                                  onTap: () => setState(() => _filtroFrecuencia = 'diaria'),
                                ),
                              if (semanalesCount > 0)
                                _CustomFilterChip(
                                  label: 'Semanales',
                                  count: semanalesCount.toString(),
                                  isSelected: _filtroFrecuencia == 'semanal',
                                  baseColor: Colors.indigoAccent,
                                  onTap: () => setState(() => _filtroFrecuencia = 'semanal'),
                                ),
                              if (quincenalesCount > 0)
                                _CustomFilterChip(
                                  label: 'Quincenales',
                                  count: quincenalesCount.toString(),
                                  isSelected: _filtroFrecuencia == 'quincenal',
                                  baseColor: Colors.indigoAccent,
                                  onTap: () => setState(() => _filtroFrecuencia = 'quincenal'),
                                ),
                              if (mensualesCount > 0)
                                _CustomFilterChip(
                                  label: 'Mensuales',
                                  count: mensualesCount.toString(),
                                  isSelected: _filtroFrecuencia == 'mensual',
                                  baseColor: Colors.indigoAccent,
                                  onTap: () => setState(() => _filtroFrecuencia = 'mensual'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Monto Total Cobrado Hoy
                        Row(
                          children: [
                            const Icon(Icons.payments_rounded, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Text(
                              'Cobrado hoy: ${DateFormatter.formatCurrency(montoTotalHoy)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
                                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    sinAsignacion
                                        ? 'No tienes locales asignados.\nContacta al administrador.'
                                        : 'No hay locales con este filtro',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
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

                        return _LocalCard(
                          local: local,
                          cobrado: cobradoHoy,
                          cuotaCubierta: cuotaCubierta,
                          cobroExistente: ultimoCobro,
                          onCobrar: () => _registrarCobro(local, cobrosHoy),
                          onSinPago: cobradoHoy
                              ? null
                              : () => _registrarSinPago(local, cobrosHoy),
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
            Text('Offline Storage', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📂 Locales Bajados: ${localesAgregados.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('💰 Cobros Bajados (Nube): ${cobrosNube.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('⏳ Cobros Pendientes (Local): ${cobrosPendientes.length}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                    const Divider(),
                    const Text('Recientes Pendientes:'),
                    ...cobrosPendientes.map(
                      (cobro) => ListTile(
                        title: Text('Monto: L ${cobro.monto}'),
                        subtitle: Text('ID: ${cobro.id}\nLocal UUID: ${cobro.localId}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
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

class _CustomFilterChip extends StatelessWidget {
  final String label;
  final String? count;
  final bool isSelected;
  final Color baseColor;
  final VoidCallback onTap;
  final IconData? icon;

  const _CustomFilterChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.baseColor,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? baseColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? baseColor : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: isSelected ? baseColor : colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? baseColor : colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (count != null && count!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? baseColor : colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count!,
                      style: TextStyle(
                        color: isSelected ? (baseColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white) : colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
  final Cobro? cobroExistente;
  final VoidCallback onCobrar;
  final VoidCallback? onSinPago;
  final VoidCallback? onVerHistorial;
  final VoidCallback? onVerEstadoCuenta;
  final VoidCallback? onEliminar;

  const _LocalCard({
    required this.local,
    required this.cobrado,
    required this.cuotaCubierta,
    required this.cobroExistente,
    required this.onCobrar,
    this.onSinPago,
    this.onVerHistorial,
    this.onVerEstadoCuenta,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tieneDeuda = (local.deudaAcumulada ?? 0) > 0;
    final tieneSaldo = (local.saldoAFavor ?? 0) > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cuotaCubierta
                  ? AppColors.success.withValues(alpha: 0.35)
                  : cobrado
                  ? Colors.blue.withValues(alpha: 0.4)
                  : tieneDeuda
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : colorScheme.outline.withValues(alpha: 0.4),
            ),
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
                        color: cuotaCubierta
                            ? AppColors.success.withValues(alpha: 0.15)
                            : cobrado
                            ? Colors.blue.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        cuotaCubierta
                            ? Icons.check_circle_rounded
                            : cobrado
                            ? Icons.add_task_rounded
                            : Icons.storefront_rounded,
                        color: cuotaCubierta
                            ? AppColors.success
                            : cobrado
                            ? Colors.blue
                            : Colors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            local.nombreSocial ?? 'Sin nombre',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: cuotaCubierta
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            local.representante ?? '—',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (local.clave != null &&
                              local.clave!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Clave: ${local.clave}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.5),
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
                                label: local.frecuenciaCobro?.toUpperCase() ?? 'DIARIA',
                                color: Colors.blueGrey,
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
                            color: cuotaCubierta ? AppColors.success : colorScheme.onSurface,
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
                        color: cuotaCubierta
                            ? AppColors.success
                            : colorScheme.primary,
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
                        color: colorScheme.secondary,
                      ),
                    ),
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
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: onTap == null ? colorScheme.onSurface.withValues(alpha: 0.24) : color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: onTap == null ? colorScheme.onSurface.withValues(alpha: 0.24) : color,
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
  final Color? color;

  const _InfoRow({required this.label, required this.value, this.color});

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
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

