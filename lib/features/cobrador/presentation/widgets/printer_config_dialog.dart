import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_theme.dart';

class PrinterConfigDialog extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PrinterConfigDialog({super.key, this.scrollController});

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
      final currentMac = ref.read(connectedPrinterMacProvider);
      if (currentMac != null) {
        await printer.disconnect();
      }
      final success = await printer.connect(mac);

      if (mounted) {
        if (success) {
          ref.read(connectedPrinterMacProvider.notifier).setMac(mac);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Conectado a $name'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Error al conectar con la impresora.'),
              backgroundColor: AppColors.danger,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impresora desconectada')),
        );
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

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            children: [
              Icon(
                Icons.print_rounded,
                size: 36,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Configuración de Impresora',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona una impresora Bluetooth emparejada',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Device List
        Expanded(
          child: _isLoading && _devices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : !_isBluetoothEnabled
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled_rounded,
                          size: 48,
                          color: AppColors.warning,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'El Bluetooth está desactivado. Por favor, actívalo para conectar la impresora.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              : _devices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No se encontraron impresoras Bluetooth emparejadas. Empareja una impresora térmica desde el menú de Bluetooth de tu dispositivo.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final name = device['name'] as String;
                    final mac = device['mac'] as String;
                    final isThisConnected = currentMac == mac;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isThisConnected
                            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: isThisConnected
                            ? Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isThisConnected
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            color: isThisConnected
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.4),
                            size: 20,
                          ),
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
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                        trailing: isThisConnected
                            ? OutlinedButton.icon(
                                onPressed: _isLoading ? null : _disconnect,
                                icon: const Icon(Icons.link_off_rounded, size: 16),
                                label: const Text(
                                  'Salir',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  foregroundColor: colorScheme.error,
                                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
                                ),
                              )
                            : FilledButton.tonal(
                                onPressed: _isLoading
                                    ? null
                                    : () => _connectToDevice(mac, name),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                                child: const Text(
                                  'Vincular',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),

        // Refresh Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
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
          ),
        ),
      ],
    );
  }
}
