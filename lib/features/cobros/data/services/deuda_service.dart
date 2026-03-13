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
    DateTime? fechaInicioOperaciones,
  }) async {
    if (localesActivos.isEmpty) return 0;

    int creados = 0;
    final hoy = DateTime.now();
    final now = Timestamp.now();
    // Limitar retroactividad: nunca ir más atrás de fechaInicioOperaciones
    DateTime fechaLimite = DateTime(hoy.year, hoy.month, hoy.day - diasAtras);
    if (fechaInicioOperaciones != null) {
      final inicioNormalizado = DateTime(
        fechaInicioOperaciones.year,
        fechaInicioOperaciones.month,
        fechaInicioOperaciones.day,
      );
      if (inicioNormalizado.isAfter(fechaLimite)) {
        fechaLimite = inicioNormalizado;
      }
    }
    final fechaFin = DateTime(hoy.year, hoy.month, hoy.day - 1);

    // 1. CARGA MASIVA: Traer todos los cobros de la semana para estos locales
    final localIds = localesActivos
        .where((l) => l.id != null)
        .map((l) => l.id!)
        .toList();
    
    // Si la fechaLimite es posterior al fechaFin, no hay nada que revisar
    if (fechaLimite.isAfter(fechaFin)) return 0;

    final todosLosCobros = await cobroDs.listarPorLocalesYRango(
      localIds: localIds,
      inicio: fechaLimite,
      fin: fechaFin,
    );

    // 2. Indexar cobros en memoria:
    //    mapaPagos: cuánto se pagó (para calcular faltante)
    //    mapaExistencia: si YA EXISTE cualquier registro (pagado o pendiente)
    //    Esto evita duplicar pendientes y consumir saldo a favor erróneamente.
    final Map<String, Map<String, num>> mapaPagos = {};
    final Map<String, Set<String>> mapaExistencia = {};
    for (final c in todosLosCobros) {
      if (c.localId == null || c.fecha == null) continue;
      final f = c.fecha!;
      final fechaKey = "${f.year}${f.month}${f.day}";
      
      mapaPagos.putIfAbsent(c.localId!, () => {});
      final pagosDia = mapaPagos[c.localId!]!;
      pagosDia[fechaKey] = (pagosDia[fechaKey] ?? 0) + (c.monto ?? 0);
      
      // Registrar que EXISTE un cobro (sin importar el monto)
      mapaExistencia.putIfAbsent(c.localId!, () => {});
      mapaExistencia[c.localId!]!.add(fechaKey);
    }

    // 3. Procesar: iterar desde fechaLimite hasta ayer
    for (DateTime fecha = fechaLimite; !fecha.isAfter(fechaFin); fecha = fecha.add(const Duration(days: 1))) {
      final fechaKey = "${fecha.year}${fecha.month}${fecha.day}";

      for (final local in localesActivos) {
        if (local.id == null || local.cuotaDiaria == null) continue;
        final lid = local.id!;

        // Validar fecha de creación
        if (local.creadoEn != null) {
          final fechaCreacion = DateTime(
            local.creadoEn!.year,
            local.creadoEn!.month,
            local.creadoEn!.day,
          );
          if (fecha.isBefore(fechaCreacion)) continue;
        }

        // 4. Si ya existe CUALQUIER registro para este local+fecha, saltar
        //    (evita duplicar pendientes y consumir saldo a favor incorrectamente)
        final yaExisteRegistro = mapaExistencia[lid]?.contains(fechaKey) ?? false;
        if (yaExisteRegistro) continue;

        // 5. Calcular faltante
        final pagadoEseDia = mapaPagos[lid]?[fechaKey] ?? 0;
        final cuota = local.cuotaDiaria!;

        if (pagadoEseDia < cuota) {
          num faltante = cuota - pagadoEseDia;

          // 5. Saldo a favor (Sigue siendo 1 lectura por local con deuda detectada)
          final localData = await localDs.obtenerPorId(lid);
          num saldoAFavorActual = localData?.saldoAFavor ?? 0;

          if (saldoAFavorActual > 0) {
            num aCoverirConSaldo = saldoAFavorActual >= faltante
                ? faltante
                : saldoAFavorActual;

            final subDocId =
                'COB-$lid-${fecha.year}${fecha.month.toString().padLeft(2, "0")}${fecha.day.toString().padLeft(2, "0")}-S';

            final ahoraMatch = DateTime.now();
            final fechaConHora = DateTime(
              fecha.year,
              fecha.month,
              fecha.day,
              ahoraMatch.hour,
              ahoraMatch.minute,
            );

            await cobroDs.crear(subDocId, {
              'actualizadoEn': now,
              'actualizadoPor': 'sistema-saldo',
              'cobradorId': 'sistema',
              'creadoEn': now,
              'creadoPor': 'sistema-saldo',
              'cuotaDiaria': cuota,
              'estado': 'cobrado_saldo',
              'fecha': Timestamp.fromDate(fechaConHora),
              'localId': lid,
              'mercadoId': local.mercadoId,
              'municipalidadId': local.municipalidadId,
              'monto': aCoverirConSaldo,
              'pagoACuota': aCoverirConSaldo,
              'observaciones':
                  'Cubierto automáticamente con saldo a favor acumulado',
              'saldoPendiente': 0,
              'correlativo': 0,
              'anioCorrelativo': fecha.year,
            });

            await localDs.actualizarSaldoAFavor(lid, -aCoverirConSaldo);

            // Descontar ese monto de las estadísticas globales del Dashboard
            if (local.municipalidadId != null) {
              await firestore.collection('stats').doc(local.municipalidadId).set({
                'totalSaldoAFavor': FieldValue.increment(-aCoverirConSaldo),
                'ultimaActualizacion': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }

            faltante -= aCoverirConSaldo;
          }

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
    final ahoraMatch = DateTime.now();
    final fechaConHora = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      ahoraMatch.hour,
      ahoraMatch.minute,
    );

    await cobroDs.crear(docId, {
      'actualizadoEn': now,
      'actualizadoPor': cobradorId ?? 'sistema',
      'cobradorId': cobradorId ?? '',
      'creadoEn': now,
      'creadoPor': cobradorId ?? 'sistema',
      'cuotaDiaria': cuota,
      'estado': 'pendiente',
      'fecha': Timestamp.fromDate(fechaConHora),
      'localId': local.id,
      'mercadoId': local.mercadoId,
      'monto': 0,
      'pagoACuota': 0,
      'municipalidadId': local.municipalidadId,
      'observaciones': observaciones,
      'saldoPendiente': faltante,
      'correlativo': 0,
      'anioCorrelativo': fecha.year,
    });

    // Incrementar deuda acumulada en el local
    await localDs.actualizarDeudaAcumulada(local.id!, faltante);

    // Incrementar en las estadísticas globales (Dashboard)
    if (local.municipalidadId != null) {
      await firestore.collection('stats').doc(local.municipalidadId).set({
        'totalDeuda': FieldValue.increment(faltante),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Registra deudas pendientes para un local en un rango de fechas.
  /// Salta días que ya tengan cualquier registro de cobro (idempotencia).
  Future<int> registrarDeudaPorRango({
    required Local local,
    required DateTime start,
    required DateTime end,
    required String? cobradorId,
  }) async {
    if (local.id == null) return 0;

    // 1. Normalizar fechas (start siempre antes que end)
    DateTime fechaInicio = DateTime(start.year, start.month, start.day);
    DateTime fechaFin = DateTime(end.year, end.month, end.day);
    if (fechaInicio.isAfter(fechaFin)) {
      final temp = fechaInicio;
      fechaInicio = fechaFin;
      fechaFin = temp;
    }

    // 2. Carga masiva de cobros existentes en el rango para evitar duplicados
    final existentes = await cobroDs.listarPorLocalesYRango(
      localIds: [local.id!],
      inicio: fechaInicio,
      fin: fechaFin,
    );

    final Set<String> mapaExistencia = {};
    for (final c in existentes) {
      if (c.fecha == null) continue;
      final f = c.fecha!;
      mapaExistencia.add("${f.year}${f.month}${f.day}");
    }

    int creados = 0;
    // 3. Iterar día por día
    for (DateTime fecha = fechaInicio;
        !fecha.isAfter(fechaFin);
        fecha = fecha.add(const Duration(days: 1))) {
      final fechaKey = "${fecha.year}${fecha.month}${fecha.day}";

      // Saltar si ya existe registro (pagado o pendiente)
      if (mapaExistencia.contains(fechaKey)) continue;

      // Se eliminó la restricción de local.creadoEn para permitir 
      // registrar deudas de años anteriores aunque el local 
      // sea nuevo en el sistema digital.

      await _crearPendiente(
        local: local,
        fecha: fecha,
        cobradorId: cobradorId,
        observaciones: 'Deuda registrada manualmente por rango de fechas',
      );
      creados++;
    }

    return creados;
  }
}
