import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../cobros/data/models/hive/cobro_hive.dart';
import '../../../locales/data/models/hive/local_hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../cobros/domain/entities/cobro.dart';
import '../../../locales/domain/entities/local.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/platform/printer_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../cobros/data/services/deuda_service.dart';
import '../../../cobros/presentation/viewmodels/cobro_viewmodel.dart';

class CobradorHomeScreen extends ConsumerStatefulWidget {
  const CobradorHomeScreen({super.key});

  @override
  ConsumerState<CobradorHomeScreen> createState() => _CobradorHomeScreenState();
}

class _CobradorHomeScreenState extends ConsumerState<CobradorHomeScreen> {
  String _filtroActivo = 'todos'; // 'todos', 'pendientes', 'cobrados'

  @override
  void initState() {
    super.initState();
    // La sincronización inicial y la verificación de deuda se pueden disparar una vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dispararSyncYVerificacion();
    });
  }

  Future<void> _dispararSyncYVerificacion() async {
    try {
      final localRepo = ref.read(localRepositoryProvider);
      final cobroRepo = ref.read(cobroRepositoryProvider);
      localRepo.syncLocales().catchError((_) {});
      cobroRepo.syncCobros().catchError((_) {});

      // Esperar a que los locales carguen para verificar deuda
      final locales = await ref.read(localesCobradorProvider.future);
      if (mounted && locales.isNotEmpty) {
        _verificarDeudaRetroactiva(locales);
      }
    } catch (_) {}
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
  Future<void> _verificarDeudaRetroactiva(List<Local> localesActivos) async {
    try {
      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);
      final usuario = ref.read(currentUsuarioProvider).value;
      final service = DeudaService(
        cobroDs: cobroDs,
        localDs: localDs,
        firestore: FirebaseFirestore.instance,
      );
      await service.verificarYRegistrarPendientes(
        localesActivos: localesActivos,
        diasAtras: 7,
        cobradorId: usuario?.id,
      );
      // Al ser reactivo (ref.watch), no necesitamos llamar a setState.
      // Los nuevos cobros aparecerán automáticamente vía stream.
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Cobro?'),
        content: const Text(
          'Esta acción revertirá los saldos y eliminará el registro. '
          'Si hubo auto-pagos posteriores, también se borrarán.\n\n'
          '¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sí, Eliminar'),
          ),
        ],
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
        // Ya no cargamos datos manualmente, Riverpod detecta el cambio en Firestore.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al eliminar el cobro'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _registrarSinPago(Local local, List<Cobro> cobrosHoy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.money_off_rounded, size: 22, color: Colors.red.shade300),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Sin Pago', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿El local ${local.nombreSocial ?? ""} no realizo su pago hoy?',
            ),
            const SizedBox(height: 8),
            Text(
              'Se registrara una deuda de ${DateFormatter.formatCurrency(local.cuotaDiaria)} para hoy.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if ((local.deudaAcumulada ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Deuda acumulada: ${DateFormatter.formatCurrency(local.deudaAcumulada)}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Confirmar Sin Pago'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
          ),
        ],
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
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade700,
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
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.savings_rounded,
                size: 22,
                color: Color(0xFF00D9A6),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Usar Saldo a Favor',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${local.nombreSocial ?? ""} tiene un crédito de:'),
              const SizedBox(height: 8),
              Text(
                DateFormatter.formatCurrency(saldoActual),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D9A6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Se descontará ${DateFormatter.formatCurrency(cuota)} de ese crédito para cubrir el día de hoy.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _aplicarSaldoAFavor(local);
      return;
    }

    // Calcular cuánto falta para la cuota hoy
    final faltanteHoy = (cuota - pagadoHoy).clamp(0, cuota);
    final montoSugerido = faltanteHoy > 0 ? faltanteHoy : cuota;

    final montoCtrl = TextEditingController(text: montoSugerido.toString());
    final obsCtrl = TextEditingController();
    final usuario = ref.read(currentUsuarioProvider).value;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              cuotaCubierta
                  ? Icons.add_circle_outline_rounded
                  : Icons.receipt_long_rounded,
              size: 22,
              color: cuotaCubierta ? const Color(0xFF00D9A6) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cuotaCubierta
                    ? 'Abono Extra - ${local.nombreSocial ?? ""}'
                    : 'Cobrar - ${local.nombreSocial ?? ""}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!cuotaCubierta)
                  _InfoRow(
                    label: 'Cuota diaria',
                    value: DateFormatter.formatCurrency(cuota),
                  ),
                if (pagadoHoy > 0)
                  _InfoRow(
                    label: 'Pagado hoy',
                    value: DateFormatter.formatCurrency(pagadoHoy),
                    color: Colors.green,
                  ),
                if (faltanteHoy > 0 && pagadoHoy > 0)
                  _InfoRow(
                    label: 'Faltante cuota',
                    value: DateFormatter.formatCurrency(faltanteHoy),
                    color: Colors.orange,
                  ),
                _InfoRow(
                  label: 'Representante',
                  value: local.representante ?? '-',
                ),
                if (saldoActual > 0)
                  _InfoRow(
                    label: 'Saldo a favor',
                    value: DateFormatter.formatCurrency(saldoActual),
                    color: const Color(0xFF00D9A6),
                  ),
                if ((local.deudaAcumulada ?? 0) > 0)
                  _InfoRow(
                    label: 'Deuda Acumulada',
                    value: DateFormatter.formatCurrency(local.deudaAcumulada),
                    color: const Color(0xFFEE5A6F),
                  ),
                _InfoRow(
                  label: 'Balance Neto',
                  value: DateFormatter.formatCurrency(local.balanceNeto),
                  color: local.balanceNeto >= 0
                      ? const Color(0xFF00D9A6)
                      : const Color(0xFFEE5A6F),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monto a cobrar (L)',
                    prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                    helperText:
                        'Si paga más de L ${cuota.toStringAsFixed(0)}, el excedente queda como saldo a favor',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Registrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final monto = num.tryParse(montoCtrl.text) ?? 0;
    await _guardarCobro(
      local: local,
      monto: monto,
      observaciones: obsCtrl.text,
      usuario: usuario,
      cobrosHoy: cobrosHoy,
    );
  }

  /// Aplica el saldo a favor del local para cubrir la cuota del día.
  Future<void> _aplicarSaldoAFavor(Local local) async {
    final cuota = local.cuotaDiaria ?? 0;
    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';
    final usuario = ref.read(currentUsuarioProvider).value;
    try {
      final cobroDs = ref.read(cobroDatasourceProvider);
      final localDs = ref.read(localDatasourceProvider);

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
      ref.invalidate(localesCobradorProvider);
      ref.invalidate(cobrosHoyCobradorProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '💰 Cobro aplicado con saldo a favor: ${local.nombreSocial}',
            ),
            backgroundColor: const Color(0xFF00D9A6),
          ),
        );
      }

      // --- OBTENER DATOS MAESTROS (Con soporte offline vía repositorios) ---
      final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
      final mercadoRepo = ref.read(mercadoRepositoryProvider);

      final muni = await municipalidadRepo.obtenerPorId(
        local.municipalidadId ?? '',
      );
      final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

      final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
      final mercadoNombre = merc?.nombre;
      // ------------------------------------------------------------------

      // Imprimir boleta sin await para no bloquear el diálogo de éxito
      try {
        final printer = ref.read(printerServiceProvider);

        final double saldoResultante = (local.deudaAcumulada ?? 0).toDouble();
        final double favorResultante =
            (local.saldoAFavor ?? 0).toDouble() - cuota.toDouble();

        printer
            .printReceipt(
              empresa: municipalidadNombre,
              mercado: mercadoNombre,
              local: local.nombreSocial ?? 'Sin Nombre',
              monto: cuota.toDouble(),
              fecha: now,
              saldoPendiente: saldoResultante > 0 ? saldoResultante : 0,
              saldoAFavor: favorResultante > 0 ? favorResultante : 0,
              cobrador: usuario?.nombre,
              numeroBoleta: correlativoStr,
              anioCorrelativo: now.year,
            )
            .then((impreso) {
              if (!impreso && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Comprobante no impreso.'),
                    backgroundColor: Colors.orange.shade800,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            })
            .catchError((_) {});
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Lógica central de guardado. Maneja excedentes como abono a deuda o saldo a favor.
  Future<void> _guardarCobro({
    required Local local,
    required num monto,
    required String observaciones,
    required dynamic usuario,
    required List<Cobro> cobrosHoy,
  }) async {
    // --- OBTENER DATOS MAESTROS (Con soporte offline via repositorios) ---
    final municipalidadRepo = ref.read(municipalidadRepositoryProvider);
    final mercadoRepo = ref.read(mercadoRepositoryProvider);

    final muni = await municipalidadRepo.obtenerPorId(
      local.municipalidadId ?? '',
    );
    final merc = await mercadoRepo.obtenerPorId(local.mercadoId ?? '');

    final municipalidadNombre = muni?.nombre ?? 'MUNICIPALIDAD';
    final mercadoNombre = merc?.nombre;
    // ------------------------------------------------------------------

    final now = DateTime.now();
    final docId = 'COB-${local.id}-${now.millisecondsSinceEpoch}';

    final deudaTotalInicial = (local.deudaAcumulada ?? 0);
    final saldoFavorInicial = (local.saldoAFavor ?? 0);
    final cuotaHoy = local.cuotaDiaria ?? 0;

    // 1. Distribución lógica: El monto recibido paga primero la deuda acumulada
    // (que incluye hoy si se disparó la verificación retroactiva).
    final paraDeudaReal = monto > deudaTotalInicial ? deudaTotalInicial : monto;
    num montoRestante = monto - paraDeudaReal;

    // 2. El excedente se va a saldo a favor
    final paraSaldoFavorReal = montoRestante;

    // 3. Determinar el estado de HOY para el registro meta-data
    final double saldoResultante = (deudaTotalInicial - paraDeudaReal)
        .clamp(0, double.infinity)
        .toDouble();
    final double favorResultante = (saldoFavorInicial + paraSaldoFavorReal)
        .toDouble();

    // El estado del registro de hoy se determina por el saldo pendiente resultante para hoy
    final estado = saldoResultante == 0
        ? 'cobrado'
        : (saldoResultante < cuotaHoy)
        ? 'abono_parcial'
        : 'pendiente';

    // Para el registro individual, queremos saber cuánto de este pago específico fue a la cuota de hoy.
    final deudaVieja = (deudaTotalInicial - cuotaHoy).clamp(0, double.infinity);
    final pagoACuota = (paraDeudaReal - deudaVieja).clamp(0, cuotaHoy);
    final saldoPendienteHoy = (cuotaHoy - pagoACuota).clamp(0, cuotaHoy);

    try {
      // ====== MVVM REFACTOR: Utilizar CobroViewModel y Repositorios ======
      final cobroViewModel = ref.read(cobroViewModelProvider.notifier);

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
            ? '${observaciones.isNotEmpty ? "$observaciones | " : ""}'
                  'Distribuido: ${paraDeudaReal > 0 ? "L ${paraDeudaReal.toStringAsFixed(2)} a deuda" : ""}'
                  '${paraDeudaReal > 0 && paraSaldoFavorReal > 0 ? " y " : ""}'
                  '${paraSaldoFavorReal > 0 ? "L ${paraSaldoFavorReal.toStringAsFixed(2)} a favor" : ""}'
            : observaciones,
        saldoPendiente: saldoPendienteHoy,
        deudaAnterior: deudaTotalInicial,
        montoAbonadoDeuda: paraDeudaReal,
        nuevoSaldoFavor: favorResultante,
        telefonoRepresentante: local.telefonoRepresentante,
      );

      final String? correlativoAsignado = await cobroViewModel.registrarPago(
        cobro: nuevoCobro,
        mercadoId: local.mercadoId!,
        localId: local.id!,
        montoAbonadoDeuda: paraDeudaReal,
        incrementoSaldoFavor: paraSaldoFavorReal,
      );

      final String correlativoStr = correlativoAsignado ?? '0';
      // ====== END MVVM REFACTOR ======

      ref.invalidate(localesCobradorProvider);
      ref.invalidate(cobrosHoyCobradorProvider);

      // Imprimir boleta silenciosamente de fondo (Sin Await)
      try {
        final printer = ref.read(printerServiceProvider);
        printer
            .printReceipt(
              empresa: municipalidadNombre,
              mercado: mercadoNombre,
              local: local.nombreSocial ?? 'Sin Nombre',
              monto: monto.toDouble(), // Monto original entregado
              fecha: now,
              saldoPendiente: saldoResultante > 0 ? saldoResultante : 0.0,
              saldoAFavor: favorResultante > 0 ? favorResultante : 0.0,
              deudaAnterior: deudaTotalInicial.toDouble(),
              montoAbonadoDeuda: paraDeudaReal.toDouble(),
              cobrador: usuario?.nombre,
              numeroBoleta: correlativoStr,
              anioCorrelativo: now.year,
            )
            .then((impreso) {
              if (!impreso && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Comprobante Bluetoooth no impreso.'),
                    backgroundColor: Colors.orange.shade800,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            })
            .catchError((_) {});
      } catch (_) {}

      // Mostrar diálogo exitoso con la opción de PDF
      if (mounted) {
        String mensajeExtra = '';
        if (paraDeudaReal > 0) {
          mensajeExtra +=
              '\n📉 Deuda -${DateFormatter.formatCurrency(paraDeudaReal)}';
        }
        if (paraSaldoFavorReal > 0) {
          mensajeExtra +=
              '\n💬 Saldo +${DateFormatter.formatCurrency(paraSaldoFavorReal)}';
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1B27),
            title: const Text(
              '✅ Cobro Registrado',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '${local.nombreSocial}$mensajeExtra',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _compartirPdfPostCobro(
                    context: context,
                    local: local,
                    monto: monto.toDouble(),
                    fecha: now,
                    saldoPendiente: saldoResultante > 0 ? saldoResultante : 0,
                    deudaAnterior: (local.deudaAcumulada ?? 0).toDouble(),
                    montoAbonadoDeuda: paraDeudaReal.toDouble(),
                    saldoAFavor: favorResultante > 0 ? favorResultante : 0,
                    numeroBoleta: correlativoStr,
                    municipalidadNombre: municipalidadNombre,
                    mercadoNombre: mercadoNombre,
                    cobradorNombre: usuario?.nombre,
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _compartirPdfPostCobro({
    required BuildContext context,
    required Local local,
    required double monto,
    required DateTime fecha,
    required double saldoPendiente,
    required double deudaAnterior,
    required double montoAbonadoDeuda,
    required double saldoAFavor,
    required String numeroBoleta,
    required String? municipalidadNombre,
    required String? mercadoNombre,
    required String? cobradorNombre,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando boleta en formato PDF...'),
        duration: Duration(seconds: 1),
      ),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                (municipalidadNombre ?? 'MUNICIPALIDAD').toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (mercadoNombre != null)
                pw.Text(
                  mercadoNombre.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Comprobante de Cobro',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (local.nombreSocial != null) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Local: ${local.nombreSocial}'),
                ),
              ],
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Fecha: ${DateFormatter.formatDateTime(fecha)}'),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Cobrador: ${cobradorNombre ?? "Desconocido"}'),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Boleta N°: $numeroBoleta'),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Monto Pagado:'),
                  pw.Text(
                    DateFormatter.formatCurrency(monto),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (deudaAnterior > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deuda Anterior:'),
                    pw.Text(DateFormatter.formatCurrency(deudaAnterior)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Abono a Deuda:'),
                    pw.Text(DateFormatter.formatCurrency(montoAbonadoDeuda)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deuda Actual:'),
                    pw.Text(DateFormatter.formatCurrency(saldoPendiente)),
                  ],
                ),
              ] else if (saldoPendiente > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Deuda Actual:'),
                    pw.Text(DateFormatter.formatCurrency(saldoPendiente)),
                  ],
                ),
              ],
              if (saldoAFavor > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Saldo A Favor:'),
                    pw.Text(DateFormatter.formatCurrency(saldoAFavor)),
                  ],
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                '*** GRACIAS POR SU PAGO ***',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Comprobante_Municipalidad_$numeroBoleta.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(currentUsuarioProvider).value;
    final localesAsync = ref.watch(localesCobradorProvider);
    final cobrosAsync = ref.watch(cobrosHoyCobradorProvider);

    return localesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F1017),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Scaffold(
        backgroundColor: const Color(0xFF0F1017),
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
          if (_filtroActivo == 'pendientes') return !cuotaCubierta;
          if (_filtroActivo == 'cobrados') return cuotaCubierta;
          return true;
        }).toList();

        final int totalTotal = locales.length;
        final int cobradosCount = idsCuotaCubiertaSet.length;
        final colorScheme = Theme.of(context).colorScheme;

        // Disparar recarga de Hive en segundo plano si los datos cambiaron
        _recargarCacheManual(locales, cobrosHoy);

        return Scaffold(
          backgroundColor: const Color(0xFF0F1017),
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
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Limpiar Caché Local',
                                        ),
                                        content: const Text(
                                          'Esto borrará los cobros almacenados localmente en el dispositivo para eliminar cobros fantasma.\n\nLos datos en la nube NO se borran. ¿Continuar?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Limpiar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true || !mounted) return;
                                    try {
                                      await ref
                                          .read(cobroDatasourceProvider)
                                          .limpiarCacheLocal();
                                      ref.invalidate(localesCobradorProvider);
                                      ref.invalidate(cobrosHoyCobradorProvider);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '🧹 Caché limpiada. Recargando...',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted)
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.bug_report,
                                    color: Colors.redAccent,
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
                              ?.copyWith(color: Colors.white54),
                        ),
                        const SizedBox(height: 20),
                        // Filtros
                        Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _StatChip(
                                  icon: Icons.check_circle_rounded,
                                  label:
                                      '$cobradosCount / $totalTotal\ncobrados',
                                  color: Colors.green,
                                  isSelected: _filtroActivo == 'cobrados',
                                  onTap: () => setState(
                                    () => _filtroActivo =
                                        _filtroActivo == 'cobrados'
                                        ? 'todos'
                                        : 'cobrados',
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _StatChip(
                                  icon: Icons.payments_rounded,
                                  label: DateFormatter.formatCurrency(
                                    montoTotalHoy,
                                  ),
                                  color: colorScheme.primary,
                                  isSelected: true,
                                  onTap: null,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _StatChip(
                                icon: Icons.pending_actions_rounded,
                                label:
                                    '${totalTotal - cobradosCount}\npendientes',
                                color: Colors.orange,
                                isSelected: _filtroActivo == 'pendientes',
                                onTap: () => setState(
                                  () => _filtroActivo =
                                      _filtroActivo == 'pendientes'
                                      ? 'todos'
                                      : 'pendientes',
                                ),
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
                        if (localesFiltrados.isEmpty) {
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
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    sinAsignacion
                                        ? 'No tienes locales asignados.\nContacta al administrador.'
                                        : 'No hay locales con este filtro',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (index >= localesFiltrados.length)
                          return const SizedBox.shrink();

                        final local = localesFiltrados[index];
                        final lid = local.id ?? '';
                        final cobradoHoy = idsCobradosHoySet.contains(lid);
                        final cuotaCubierta = idsCuotaCubiertaSet.contains(lid);
                        final ultimoCobro = _cobroDelLocal(lid, cobrosHoy);

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
                          onEliminar: ultimoCobro == null
                              ? null
                              : () => _eliminarCobro(ultimoCobro),
                        );
                      },
                      childCount: localesFiltrados.isEmpty
                          ? 1
                          : localesFiltrados.length,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Offline Storage'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 Locales Bajados: ${localesAgregados.length}',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
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
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isSelected = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSelected ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
                  ? Colors.green.withValues(alpha: 0.35)
                  : cobrado
                  ? Colors.blue.withValues(alpha: 0.4)
                  : tieneDeuda
                  ? Colors.red.withValues(alpha: 0.4)
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
                            ? Colors.green.withValues(alpha: 0.15)
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
                            ? Colors.green
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
                                ?.copyWith(color: Colors.white60),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Badges de deuda / saldo
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (tieneDeuda)
                                _SmallBadge(
                                  icon: Icons.warning_amber_rounded,
                                  label:
                                      '-${DateFormatter.formatCurrency(local.deudaAcumulada ?? 0)}',
                                  color: const Color(0xFFEE5A6F),
                                ),
                              if (tieneSaldo)
                                _SmallBadge(
                                  icon: Icons.savings_rounded,
                                  label:
                                      '+${DateFormatter.formatCurrency(local.saldoAFavor ?? 0)}',
                                  color: const Color(0xFF00D9A6),
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
                            color: cuotaCubierta ? Colors.green : Colors.white,
                          ),
                        ),
                        Text(
                          'por día',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Divisor ──────────────────────────────────────────────
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
                            ? const Color(0xFF00D9A6)
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
                          color: Colors.redAccent,
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
            Icon(icon, size: 18, color: onTap == null ? Colors.white24 : color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: onTap == null ? Colors.white24 : color,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
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
