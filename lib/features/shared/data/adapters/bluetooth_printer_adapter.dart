import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';
import '../../../../core/platform/printer_service.dart';
import 'package:flutter/foundation.dart';

class BluetoothPrinterAdapter implements PrinterService {
  @override
  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    try {
      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }

      final isPermissionGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!isPermissionGranted && !Platform.isAndroid) {
        // En Android a veces el plugin devuelve falso incluso si ya los dimos.
        return [];
      }

      final devicesInfo = await PrintBluetoothThermal.pairedBluetooths;
      return devicesInfo.map((info) {
        return {'name': info.name, 'mac': info.macAdress};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> connect(String macAddress) async {
    try {
      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }

      debugPrint('--- Verificando estado de Bluetooth ---');
      final bool isBluetoothEnabled =
          await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBluetoothEnabled) {
        debugPrint('--- Error: Bluetooth desactivado ---');
        return false;
      }

      // Desconexión preventiva para limpiar sockets previos
      debugPrint('--- Desconexión preventiva ---');
      await PrintBluetoothThermal.disconnect;

      debugPrint('--- Intentando conectar a impresora: $macAddress ---');
      final isConnected = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      debugPrint('--- Resultado de conexión: $isConnected ---');
      return isConnected;
    } catch (e) {
      debugPrint('--- Error fatal en connect: $e ---');
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final isDisconnected = await PrintBluetoothThermal.disconnect;
      return isDisconnected;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> printReceipt({
    required String empresa,
    String? mercado,
    required String local,
    required double monto,
    required DateTime fecha,
    double? saldoPendiente,
    double? saldoAFavor,
    double? deudaAnterior,
    double? montoAbonadoDeuda,
    double? pagoHoy,
    double? abonoCuotaHoy,
    String? cobrador,
    required String numeroBoleta,
    required int anioCorrelativo,
    List<DateTime>? fechasSaldadas,
    String? periodoAbonadoStr,
    String? periodoSaldoAFavorStr,
    String? slogan,
    String? clave,
    String? codigoLocal,
    String? codigoCatastral,
  }) async {
    try {
      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }

      // Intentamos imprimir directamente.
      // MUCHOS DISPOSITIVOS ANDROID RETORNAN FALSE EN connectionStatus SI ESTÁN OFFLINE, A PESAR DE TENER BLUETOOTH CONECTADO.
      // Solo verificamos si Bluetooth está encendido.
      final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBluetoothEnabled) return false;

      // Buffer para unificar toda la impresión en un solo envío de bytes ESC/POS
      List<int> bytes = [];

      // Comandos nativos ESC/POS
      void addAlign(int align) {
        bytes.addAll([27, 97, align]); // 0: Izquierda, 1: Centro, 2: Derecha
      }

      void addSize(int size) {
        if (size == 1) {
          bytes.addAll([27, 33, 0]); // Texto normal
        } else if (size == 2) {
          bytes.addAll([27, 33, 48]); // Texto grande (doble alto y ancho)
        }
      }

      void addText(String text, int size, int align) {
        addAlign(align);
        addSize(size);

        // Limpiamos los caracteres latinos para evitar caracteres corruptos
        // ya que las impresoras chinas varían en su soporte de codepage.
        String safeText = text
            .replaceAll('á', 'a')
            .replaceAll('é', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ú', 'u')
            .replaceAll('Á', 'A')
            .replaceAll('É', 'E')
            .replaceAll('Í', 'I')
            .replaceAll('Ó', 'O')
            .replaceAll('Ú', 'U')
            .replaceAll('ñ', 'n')
            .replaceAll('Ñ', 'N')
            .replaceAll('¡', ''); // Strip unmappable

        bytes.addAll(
          safeText.codeUnits,
        ); // Mapeo directo a 1 byte (ASCII seguro)
        bytes.addAll([10]); // \n
      }

      // Ayuda para alinear clave a la izquierda y valor a la derecha (espaciado interno)
      String r(String key, String value, int width) {
        int spaceCount = width - key.length - value.length;
        if (spaceCount < 1) return '$key $value'; // Fallback
        return key + (' ' * spaceCount) + value;
      }

      // Volvemos a 32 como standard para la línea punteada ya que el centrado
      // por hardware ESC/POS arreglará los títulos sin importar su longitud.
      const int normalWidth = 32;
      const String d = '--------------------------------';

      // Inicialización de la impresora
      bytes.addAll([27, 64]); // Reset printer

      // 1. ENCABEZADO CENTRADO (alineación = 1)
      addText(empresa.toUpperCase(), 1, 1);
      if (mercado != null) {
        addText(mercado.toUpperCase(), 1, 1);
      }
      addText('BOLETA DE PAGO', 1, 1);
      addText('No. $numeroBoleta', 1, 1);
      addText(d, 1, 1);

      // 2. CUERPO (Alineado a la izquierda = 0)
      final fechaStr = DateFormatter.formatDateTime(fecha);
      addText(r('LOCAL:', local.toUpperCase(), normalWidth), 1, 0);
      if (clave != null && clave.isNotEmpty) {
        addText(r('CLAVE:', clave, normalWidth), 1, 0);
      }
      if (codigoLocal != null && codigoLocal.isNotEmpty) {
        addText(r('NUM PUESTO:', codigoLocal, normalWidth), 1, 0);
      }
      if (codigoCatastral != null && codigoCatastral.isNotEmpty) {
        addText(r('COD.CATA:', codigoCatastral, normalWidth), 1, 0);
      }
      addText(r('FECHA:', fechaStr, normalWidth), 1, 0);
      if (cobrador != null) {
        addText(r('COBRADOR:', cobrador.toUpperCase(), normalWidth), 1, 0);
      }
      addText(d, 1, 1); // Línea centrada

      // 3. MONTO (Centrado y Grande)
      addText('MONTO PAGADO:', 1, 1);
      addText('L ${monto.toStringAsFixed(2)}', 2, 1); // Tamaño 2
      addText(d, 1, 1);

      // 4. SALDOS (Alineados a la izquierda)
      if (deudaAnterior != null && deudaAnterior > 0) {
        addText(
          r(
            'DEUDA ANTERIOR:',
            DateFormatter.formatCurrency(deudaAnterior),
            normalWidth,
          ),
          1,
          0,
        );
        addText(
          r(
            'ABONO A DEUDA:',
            DateFormatter.formatCurrency(montoAbonadoDeuda ?? 0),
            normalWidth,
          ),
          1,
          0,
        );
        addText(
          r(
            'DEUDA ACTUAL:',
            DateFormatter.formatCurrency(saldoPendiente ?? 0),
            normalWidth,
          ),
          1,
          0,
        );
      } else if (saldoPendiente != null && saldoPendiente > 0) {
        addText(
          r(
            'DEUDA ACTUAL:',
            DateFormatter.formatCurrency(saldoPendiente),
            normalWidth,
          ),
          1,
          0,
        );
      }

      if (pagoHoy != null) {
        addText(
          r(
            'CUOTA DEL DÍA:',
            DateFormatter.formatCurrency(pagoHoy),
            normalWidth,
          ),
          1,
          0,
        );
      }

      // Fechas cubiertas
      if (periodoAbonadoStr != null &&
          periodoAbonadoStr.isNotEmpty &&
          periodoAbonadoStr != '-') {
        addText('FECHAS CUBIERTAS:', 1, 0);
        addText(periodoAbonadoStr, 1, 0);
      } else if (fechasSaldadas != null && fechasSaldadas.length > 1) {
        final diasStr = DateRangeFormatter.formatearRangos(fechasSaldadas);
        if (diasStr != null) {
          addText('FECHAS CUBIERTAS:', 1, 0);
          addText(diasStr, 1, 0);
        }
      }

      if (saldoAFavor != null && saldoAFavor > 0) {
        addText(
          r(
            'SALDO A FAVOR:',
            DateFormatter.formatCurrency(saldoAFavor),
            normalWidth,
          ),
          1,
          0,
        );
        if (periodoSaldoAFavorStr != null && periodoSaldoAFavorStr.isNotEmpty) {
          addText('FECHAS ADELANTADAS:', 1, 0);
          addText(periodoSaldoAFavorStr, 1, 0);
        }
      }
      addText(d, 1, 1);

      // 5. PIE (Centrado)
      addText('', 1, 1); // Espacio en blanco
      addText('¡Gracias por su pago!', 1, 1);
      if (slogan != null && slogan.trim().isNotEmpty) {
        addText(slogan.trim(), 1, 1);
      }
      bytes.addAll([10, 10, 10]); // Avance de papel para fácil corte

      // Enviar de una sola vez
      await PrintBluetoothThermal.writeBytes(bytes);

      return true;
    } catch (e) {
      return false;
    }
  }
}

PrinterService getPlatformPrinterAdapter() => BluetoothPrinterAdapter();
