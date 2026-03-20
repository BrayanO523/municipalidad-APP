import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../core/platform/printer_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_formatter.dart';

class BluetoothPrinterAdapter implements PrinterService {
  static Future<void> _printQueue = Future<void>.value();

  Future<T> _enqueuePrint<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _printQueue = _printQueue.catchError((_) {}).then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  String _toAscii(String text) {
    const map = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'ñ': 'n',
      'Ñ': 'N',
      'ü': 'u',
      'Ü': 'U',
      '¡': '',
      '¿': '',
      '“': '"',
      '”': '"',
      '‘': "'",
      '’': "'",
      '–': '-',
      '—': '-',
      '\t': ' ',
      '\r': ' ',
      '\n': ' ',
    };

    final b = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final mapped = map[ch];
      if (mapped != null) {
        b.write(mapped);
      } else if (rune >= 32 && rune <= 126) {
        b.write(ch);
      } else {
        b.write(' ');
      }
    }

    return b.toString();
  }

  List<String> _wrapText(String text, int width) {
    final clean = _toAscii(text).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty || width <= 0) return const [''];

    final words = clean.split(' ');
    final lines = <String>[];
    var current = '';

    for (var word in words) {
      if (word.isEmpty) continue;

      while (word.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        lines.add(word.substring(0, width));
        word = word.substring(width);
      }

      if (current.isEmpty) {
        current = word;
        continue;
      }

      final candidate = '$current $word';
      if (candidate.length <= width) {
        current = candidate;
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? const [''] : lines;
  }

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
        // On Android, plugin can return false even with granted permissions.
        return [];
      }

      final devicesInfo = await PrintBluetoothThermal.pairedBluetooths;
      return devicesInfo.map((info) {
        return {'name': info.name, 'mac': info.macAdress};
      }).toList();
    } catch (_) {
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
      final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBluetoothEnabled) {
        debugPrint('--- Error: Bluetooth desactivado ---');
        return false;
      }

      // Preventive disconnect to clear previous sockets.
      debugPrint('--- Desconexion preventiva ---');
      await PrintBluetoothThermal.disconnect;

      debugPrint('--- Intentando conectar a impresora: $macAddress ---');
      final isConnected = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      debugPrint('--- Resultado de conexion: $isConnected ---');
      return isConnected;
    } catch (e) {
      debugPrint('--- Error fatal en connect: $e ---');
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (_) {
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
  }) {
    return _enqueuePrint(() async {
      try {
        if (Platform.isAndroid) {
          await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.location,
          ].request();
        }

        // Some devices report invalid connectionStatus while still connected.
        final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!isBluetoothEnabled) return false;

        final bytes = <int>[];

        void addAlign(int align) {
          bytes.addAll([27, 97, align]); // 0: left, 1: center, 2: right
        }

        void addSize(int size) {
          if (size == 2) {
            bytes.addAll([27, 33, 48]); // double size
          } else {
            bytes.addAll([27, 33, 0]); // normal
          }
        }

        void addTextLine(String text, int size, int align) {
          addAlign(align);
          addSize(size);
          bytes.addAll(_toAscii(text).codeUnits);
          bytes.add(10); // \n
        }

        void addWrappedText(String text, int size, int align, int width) {
          final effectiveWidth = size == 2 ? (width ~/ 2) : width;
          for (final line in _wrapText(text, effectiveWidth)) {
            addTextLine(line, size, align);
          }
        }

        void addKeyValue(String key, String value, int width) {
          final cleanKey = _toAscii(key);
          final cleanValue = _toAscii(value);

          if (cleanValue.isEmpty) {
            addTextLine(cleanKey, 1, 0);
            return;
          }

          // Mantener formato fijo: clave al borde izquierdo y valor al borde derecho.
          // Reservamos columna izquierda para la clave y derecha para el valor.
          final keyWidth = (width * 0.5).round().clamp(8, width - 6);
          final valueWidth = width - keyWidth;
          if (valueWidth <= 0) {
            addTextLine('$cleanKey $cleanValue', 1, 0);
            return;
          }

          final keyText = cleanKey.length > keyWidth
              ? cleanKey.substring(0, keyWidth)
              : cleanKey;
          final keyCol = keyText.padRight(keyWidth);

          final valueLines = _wrapText(cleanValue, valueWidth);
          if (valueLines.isEmpty) {
            addTextLine(keyCol, 1, 0);
            return;
          }

          // Primera línea: clave (izquierda) + valor (derecha).
          addTextLine(
            '$keyCol${valueLines.first.padLeft(valueWidth)}',
            1,
            0,
          );

          // Líneas adicionales del valor: mantener valor en la columna derecha.
          for (final line in valueLines.skip(1)) {
            addTextLine(
              '${' ' * keyWidth}${line.padLeft(valueWidth)}',
              1,
              0,
            );
          }
        }

        const normalWidth = 32;
        final divider = '-' * normalWidth;

        // Initialize printer.
        bytes.addAll([27, 64]);

        // 1) Header.
        addWrappedText(empresa.toUpperCase(), 1, 1, normalWidth);
        if (mercado != null && mercado.trim().isNotEmpty) {
          addWrappedText(mercado.toUpperCase(), 1, 1, normalWidth);
        }
        addTextLine('BOLETA DE PAGO', 1, 1);
        addWrappedText('No. $numeroBoleta', 1, 1, normalWidth);
        addTextLine(divider, 1, 1);

        // 2) Body.
        final fechaStr = DateFormatter.formatDateTime(fecha);
        addKeyValue('LOCAL:', local.toUpperCase(), normalWidth);
        if (clave != null && clave.isNotEmpty) {
          addKeyValue('CLAVE CATASTRAL:', clave, normalWidth);
        }
        if (codigoLocal != null && codigoLocal.isNotEmpty) {
          addKeyValue('NUM PUESTO:', codigoLocal, normalWidth);
        }
        if (codigoCatastral != null && codigoCatastral.isNotEmpty) {
          addKeyValue('COD.CATA:', codigoCatastral, normalWidth);
        }
        addKeyValue('FECHA:', fechaStr, normalWidth);
        if (cobrador != null && cobrador.trim().isNotEmpty) {
          addKeyValue('COBRADOR:', cobrador.toUpperCase(), normalWidth);
        }
        addTextLine(divider, 1, 1);

        // 3) Amount.
        addTextLine('MONTO PAGADO:', 1, 1);
        addWrappedText('L ${monto.toStringAsFixed(2)}', 2, 1, normalWidth);
        addTextLine(divider, 1, 1);

        // 4) Balances.
        if (deudaAnterior != null && deudaAnterior > 0) {
          addKeyValue(
            'DEUDA ANTERIOR:',
            DateFormatter.formatCurrency(deudaAnterior),
            normalWidth,
          );
          addKeyValue(
            'ABONO A DEUDA:',
            DateFormatter.formatCurrency(montoAbonadoDeuda ?? 0),
            normalWidth,
          );
          addKeyValue(
            'DEUDA ACTUAL:',
            DateFormatter.formatCurrency(saldoPendiente ?? 0),
            normalWidth,
          );
        } else if (saldoPendiente != null && saldoPendiente > 0) {
          addKeyValue(
            'DEUDA ACTUAL:',
            DateFormatter.formatCurrency(saldoPendiente),
            normalWidth,
          );
        }

        if (pagoHoy != null) {
          addKeyValue(
            'CUOTA DEL DIA:',
            DateFormatter.formatCurrency(pagoHoy),
            normalWidth,
          );
        }

        if (periodoAbonadoStr != null &&
            periodoAbonadoStr.isNotEmpty &&
            periodoAbonadoStr != '-') {
          addTextLine('FECHAS CUBIERTAS:', 1, 0);
          addWrappedText(periodoAbonadoStr, 1, 0, normalWidth);
        } else if (fechasSaldadas != null && fechasSaldadas.length > 1) {
          final diasStr = DateRangeFormatter.formatearRangos(fechasSaldadas);
          if (diasStr != null && diasStr.isNotEmpty) {
            addTextLine('FECHAS CUBIERTAS:', 1, 0);
            addWrappedText(diasStr, 1, 0, normalWidth);
          }
        }

        if (saldoAFavor != null && saldoAFavor > 0) {
          addKeyValue(
            'SALDO A FAVOR:',
            DateFormatter.formatCurrency(saldoAFavor),
            normalWidth,
          );
          if (periodoSaldoAFavorStr != null &&
              periodoSaldoAFavorStr.isNotEmpty) {
            addTextLine('FECHAS ADELANTADAS:', 1, 0);
            addWrappedText(periodoSaldoAFavorStr, 1, 0, normalWidth);
          }
        }
        addTextLine(divider, 1, 1);

        // 5) Footer.
        addTextLine('', 1, 1);
        addTextLine('Gracias por su pago!', 1, 1);
        if (slogan != null && slogan.trim().isNotEmpty) {
          addWrappedText(slogan.trim(), 1, 1, normalWidth);
        }
        bytes.addAll([10, 10, 10]); // feed

        await PrintBluetoothThermal.writeBytes(bytes);
        return true;
      } catch (e) {
        debugPrint('Bluetooth print error: $e');
        return false;
      }
    });
  }
}

PrinterService getPlatformPrinterAdapter() => BluetoothPrinterAdapter();
