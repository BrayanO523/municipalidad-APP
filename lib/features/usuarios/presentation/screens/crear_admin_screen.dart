import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';

class CrearAdminScreen extends ConsumerStatefulWidget {
  const CrearAdminScreen({super.key});

  @override
  ConsumerState<CrearAdminScreen> createState() => _CrearAdminScreenState();
}

class _CrearAdminScreenState extends ConsumerState<CrearAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _showPass = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final currentAdmin = ref.read(currentUsuarioProvider).value;
      if (currentAdmin == null) throw Exception('No hay admin autenticado');

      final ds = ref.read(authDatasourceProvider);
      await ds.registrarAdmin(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        nombre: _nombreCtrl.text.trim(),
        municipalidadId: currentAdmin.municipalidadId ?? '',
        mercadoId: currentAdmin.mercadoId,
      );

      setState(() {
        _success =
            '✅ Admin "${_nombreCtrl.text.trim()}" creado exitosamente.\n'
            'Email: ${_emailCtrl.text.trim()}';
        _nombreCtrl.clear();
        _emailCtrl.clear();
        _passCtrl.clear();
      });
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Admin [DEV]'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner dev-only
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepOrange, width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.construction, color: Colors.deepOrange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo visible en entorno de desarrollo',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Nuevo Administrador',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: !_showPass,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Info: municipalidad/mercado se toman del admin actual
                    Text(
                      '* La municipalidad y mercado se asignarán automáticamente del admin actual.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    if (_success != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _success!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),

                    FilledButton.icon(
                      onPressed: _isLoading ? null : _crearAdmin,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.admin_panel_settings),
                      label: const Text('Crear Admin'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
