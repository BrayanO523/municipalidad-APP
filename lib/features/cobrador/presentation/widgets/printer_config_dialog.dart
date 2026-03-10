import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../app/di/providers.dart';

class PrinterConfigDialog extends ConsumerStatefulWidget {
  const PrinterConfigDialog({super.key});

  @override
  ConsumerState<PrinterConfigDialog> createState() =>
      _PrinterConfigDialogState();
}

class _PrinterConfigDialogState extends ConsumerState<PrinterConfigDialog> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  bool _isBluetoothEnabled = true;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() => _isLoading = true);
    try {
      final isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      setState(() => _isBluetoothEnabled = isEnabled);

      if (!isEnabled) {
        setState(() => _devices = []);
        return;
      }

      final printer = ref.read(printerServiceProvider);
      final devices = await printer.getPairedDevices();

      final currentMac = ref.read(connectedPrinterMacProvider);
      if (currentMac != null) {
        devices.sort((a, b) {
          if (a['mac'] == currentMac) return -1;
          if (b['mac'] == currentMac) return 1;
          return (a['name'] as String).compareTo(b['name'] as String);
        });
      }

      setState(() {
        _devices = devices;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToDevice(String mac, String name) async {
    setState(() => _isLoading = true);
    try {
      final printer = ref.read(printerServiceProvider);
      // Desconectamos cualquier previa
      final currentMac = ref.read(connectedPrinterMacProvider);
      if (currentMac != null) {
        await printer.disconnect();
      }
      final success = await printer.connect(mac);

      if (mounted) {
        if (success) {
          ref.read(connectedPrinterMacProvider.notifier).setMac(mac);
          final snackColor = Theme.of(context).colorScheme.primary;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conectado a $name / $mac'),
              backgroundColor: snackColor,
            ),
          );
        } else {
          final errorColor = Theme.of(context).colorScheme.error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error al conectar con la impresora.'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    try {
      final printer = ref.read(printerServiceProvider);
      await printer.disconnect();
      if (mounted) {
        ref.read(connectedPrinterMacProvider.notifier).setMac(null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Impresora desconectada')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMac = ref.watch(connectedPrinterMacProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Configuración de Impresora'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _devices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : !_isBluetoothEnabled
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_disabled_rounded,
                            size: 48,
                            color: Colors.orange,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'El Bluetooth está desactivado. Por favor, actívalo para conectar la impresora.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : _devices.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron impresoras Bluetooth emparejadas. Empareja una impresora térmica desde el menú de Bluetooth de tu dispositivo.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final name = device['name'] as String;
                        final mac = device['mac'] as String;
                        final isThisConnected = currentMac == mac;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: Icon(
                            Icons.print_rounded,
                            color: isThisConnected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            mac,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                          trailing: isThisConnected
                              ? OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _disconnect,
                                  icon: const Icon(
                                    Icons.link_off_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Salir',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    foregroundColor: colorScheme.error,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _connectToDevice(mac, name),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Vincular',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _scanDevices,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Buscar de nuevo'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
