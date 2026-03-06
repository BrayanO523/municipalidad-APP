import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../data/datasources/cobro_datasource.dart';
import '../../../locales/data/datasources/local_datasource.dart';
import '../../../locales/domain/entities/local.dart';

/// Servicio que verifica días sin cobro y crea pendientes retroactivos.
///
/// Se llama al abrir la app del cobrador. Itera los últimos [diasAtras] días
/// y para cada local activo comprueba si existe un cobro. Si no existe,
/// crea un cobro con estado 'pendiente' y suma la cuota a [deudaAcumulada].
///
/// Usa el docId `COB-{localId}-{YYYYMMDD}` para garantizar idempotencia
/// (si se ejecuta varias veces el mismo día no crea duplicados).
class DeudaService {
  final CobroDatasource cobroDs;
  final LocalDatasource localDs;
  final FirebaseFirestore firestore;

  DeudaService({
    required this.cobroDs,
    required this.localDs,
    required this.firestore,
  });

  /// Registra un cobro pendiente manualmente para un local (botón "Sin Pago").
  Future<void> registrarSinPago({
    required Local local,
    required String? cobradorId,
    String observaciones = 'Sin pago - registrado manualmente',
  }) async {
    final now = DateTime.now();
    await _crearPendiente(
      local: local,
      fecha: now,
      cobradorId: cobradorId,
      observaciones: observaciones,
    );
  }

  /// Verifica los últimos [diasAtras] días y crea pendientes retroactivos
  /// para cualquier local activo que no tenga cobro registrado ese día.
  ///
  /// Retorna el número de pendientes creados.
  Future<int> verificarYRegistrarPendientes({
    required List<Local> localesActivos,
    int diasAtras = 7,
    String? cobradorId,
  }) async {
    int creados = 0;
    final hoy = DateTime.now();
    final now = Timestamp.now();

    for (int d = 1; d <= diasAtras; d++) {
      final fecha = DateTime(hoy.year, hoy.month, hoy.day - d);

      for (final local in localesActivos) {
        if (local.id == null || local.cuotaDiaria == null) continue;

        // 1. ¿Cuánto pagó este local ese día?
        final pagadoEseDia = await cobroDs.obtenerMontoPagadoEnFecha(
          local.id!,
          fecha,
        );
        final cuota = local.cuotaDiaria!;

        // 2. Si pagó menos de la cuota, hay un faltante
        if (pagadoEseDia < cuota) {
          num faltante = cuota - pagadoEseDia;

          // 3. ¿Tiene saldo a favor para cubrir ese faltante?
          final localData = await localDs.obtenerPorId(local.id!);
          num saldoAFavorActual = localData?.saldoAFavor ?? 0;

          if (saldoAFavorActual > 0) {
            num aCoverirConSaldo = saldoAFavorActual >= faltante
                ? faltante
                : saldoAFavorActual;

            // Creamos un registro de que se cobró del saldo
            final subDocId =
                'COB-${local.id}-${fecha.year}${fecha.month.toString().padLeft(2, "0")}${fecha.day.toString().padLeft(2, "0")}-S';
            await cobroDs.crearCobroConCorrelativo(
              cobroId: subDocId,
              mercadoId: local.mercadoId!,
              cobroData: {
                'actualizadoEn': now,
                'actualizadoPor': 'sistema-saldo',
                'cobradorId': 'sistema',
                'creadoEn': now,
                'creadoPor': 'sistema-saldo',
                'cuotaDiaria': cuota,
                'estado': 'cobrado_saldo',
                'fecha': Timestamp.fromDate(fecha),
                'localId': local.id,
                'mercadoId': local.mercadoId,
                'municipalidadId': local.municipalidadId,
                'monto': aCoverirConSaldo,
                'pagoACuota': aCoverirConSaldo,
                'observaciones':
                    'Cubierto automáticamente con saldo a favor acumulado',
                'saldoPendiente': 0,
              },
            );

            await localDs.actualizarSaldoAFavor(local.id!, -aCoverirConSaldo);
            faltante -= aCoverirConSaldo;
          }

          // 4. Si después de usar el saldo aún falta, crear el pendiente
          if (faltante > 0) {
            await _crearPendiente(
              local: local,
              fecha: fecha,
              cobradorId: cobradorId,
              observaciones: pagadoEseDia > 0
                  ? 'Pendiente por pago parcial (pagó L$pagadoEseDia de L$cuota)'
                  : 'Pendiente automático — sin cobro registrado',
              montoFaltante: faltante,
            );
            creados++;
          }
        }
      }
    }

    return creados;
  }

  /// Crea un cobro con estado 'pendiente' y actualiza deudaAcumulada del local.
  Future<void> _crearPendiente({
    required Local local,
    required DateTime fecha,
    required String? cobradorId,
    required String observaciones,
    num? montoFaltante,
  }) async {
    final docId =
        'COB-${local.id}-${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';
    final cuota = local.cuotaDiaria ?? 0;
    final faltante = montoFaltante ?? cuota;

    // Usar set con merge:false solo si no existe (no sobreescribir cobros reales)
    final ref = firestore.collection(FirestoreCollections.cobros).doc(docId);
    final existing = await ref.get();
    if (existing.exists) return; // Ya tiene cobro ese día

    final now = Timestamp.now();
    await cobroDs.crearCobroConCorrelativo(
      cobroId: docId,
      mercadoId: local.mercadoId!,
      cobroData: {
        'actualizadoEn': now,
        'actualizadoPor': cobradorId ?? 'sistema',
        'cobradorId': cobradorId ?? '',
        'creadoEn': now,
        'creadoPor': cobradorId ?? 'sistema',
        'cuotaDiaria': cuota,
        'estado': 'pendiente',
        'fecha': Timestamp.fromDate(fecha),
        'localId': local.id,
        'mercadoId': local.mercadoId,
        'monto': 0,
        'pagoACuota': 0,
        'municipalidadId': local.municipalidadId,
        'observaciones': observaciones,
        'saldoPendiente': faltante,
      },
    );

    // Incrementar deuda acumulada en el local
    await localDs.actualizarDeudaAcumulada(local.id!, faltante);
  }
}
