import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/utils/date_formatter.dart';
import 'printer_service.dart';

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
      print('--- Verificando estado de Bluetooth ---');
      final bool isBluetoothEnabled =
          await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBluetoothEnabled) {
        print('--- Error: Bluetooth desactivado ---');
        return false;
      }

      // Desconexión preventiva para limpiar sockets previos
      print('--- Desconexión preventiva ---');
      await PrintBluetoothThermal.disconnect;

      print('--- Intentando conectar a impresora: $macAddress ---');
      final isConnected = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      print('--- Resultado de conexión: $isConnected ---');
      return isConnected;
    } catch (e) {
      print('--- Error fatal en connect: $e ---');
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
    String? cobrador,
    int? correlativo,
    int? anioCorrelativo,
  }) async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) return false;

      // Ayuda para escribir líneas simples
      Future<void> w(String t, int s) async =>
          await PrintBluetoothThermal.writeString(
            printText: PrintTextSize(size: s, text: '$t\n'),
          );

      // Ayuda para centrar texto
      String c(String text, int width) {
        if (text.length >= width) return text;
        int leftPad = (width - text.length) ~/ 2;
        return text.padLeft(leftPad + text.length).padRight(width);
      }

      // Ayuda para alinear clave a la izquierda y valor a la derecha
      String r(String key, String value, int width) {
        int spaceCount = width - key.length - value.length;
        if (spaceCount < 1) return '$key $value'; // Fallback si es muy largo
        return key + (' ' * spaceCount) + value;
      }

      const int fullWidth = 42;
      const String d = '------------------------------------------';

      // 1. ENCABEZADO CENTRADO (Ancho 32 para impresoras de 58mm)
      await w(c(empresa.toUpperCase(), 32), 2);
      if (mercado != null) {
        await w(c(mercado.toUpperCase(), 32), 2);
      }
      await w(c('BOLETA DE PAGO', 32), 2);
      if (correlativo != null && anioCorrelativo != null) {
        final numeroBoleta = correlativo.toString().padLeft(5, '0');
        await w(c('No. $anioCorrelativo-$numeroBoleta', 32), 2);
      }
      await w(d, 1);

      // 2. CUERPO (CLAVE: VALOR)
      final fechaStr = DateFormatter.formatDateTime(fecha);
      await w(r('LOCAL:', local.toUpperCase(), fullWidth), 1);
      await w(r('FECHA:', fechaStr, fullWidth), 1);
      if (cobrador != null) {
        await w(r('COBRADOR:', cobrador.toUpperCase(), fullWidth), 1);
      }
      await w(d, 1);

      // 3. MONTO (Diseño original a la izquierda)
      await w('MONTO PAGADO:', 1);
      await w('L ${monto.toStringAsFixed(2)}', 2);
      await w(d, 1);

      // 4. SALDOS
      if (deudaAnterior != null && deudaAnterior > 0) {
        await w(
          r(
            'DEUDA ANTERIOR:',
            DateFormatter.formatCurrency(deudaAnterior),
            fullWidth,
          ),
          1,
        );
        await w(
          r(
            'ABONO:',
            DateFormatter.formatCurrency(montoAbonadoDeuda ?? 0),
            fullWidth,
          ),
          1,
        );
        await w(
          r(
            'DEUDA ACTUAL:',
            DateFormatter.formatCurrency(saldoPendiente ?? 0),
            fullWidth,
          ),
          1,
        );
      } else if (saldoPendiente != null && saldoPendiente > 0) {
        await w(
          r(
            'DEUDA ACTUAL:',
            DateFormatter.formatCurrency(saldoPendiente),
            fullWidth,
          ),
          1,
        );
      }
      if (saldoAFavor != null && saldoAFavor > 0) {
        await w(
          r(
            'SALDO A FAVOR:',
            DateFormatter.formatCurrency(saldoAFavor),
            fullWidth,
          ),
          1,
        );
      }
      await w(d, 1);

      // 5. PIE DE PÁGINA
      await w(c('¡Gracias por su pago!', 32), 1);
      await w(' ', 1);
      await w(' ', 1);
      await w(' ', 1);
      await w(' ', 1);
      await w(' ', 1);

      return true;
    } catch (e) {
      return false;
    }
  }
}

PrinterService getPrinterAdapter() => BluetoothPrinterAdapter();