import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/platform/permission_requester.dart';

class MobilePermissionRequester implements PermissionRequester {
  @override
  Future<void> requestInitialPermissions() async {
    // kIsWeb check extra safety even though we use conditional imports
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      } catch (e) {
        debugPrint('Error al solicitar permisos iniciales en móvil: $e');
      }
    }
  }
}

PermissionRequester getPlatformPermissionRequester() => MobilePermissionRequester();

