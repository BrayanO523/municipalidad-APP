import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _soporteAlias = 'soporte';
  static const _soporteEmail = 'durlinortiz@gmail.com';
  static const _soportePassword = '123456';

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ds = ref.read(authDatasourceProvider);
      final inputEmail = _emailCtrl.text.trim();
      final inputPassword = _passwordCtrl.text;
      final normalizedPassword = inputPassword.trim().toLowerCase();
      final esAliasSoporte =
          inputEmail.toLowerCase() == _soporteAlias &&
          normalizedPassword == _soporteAlias;
      final emailFinal = esAliasSoporte ? _soporteEmail : inputEmail;
      final passwordFinal = esAliasSoporte ? _soportePassword : inputPassword;
      final esUsuarioSoporte = emailFinal.toLowerCase() == _soporteEmail;
      final user = await ds.login(emailFinal, passwordFinal);

      if (user == null) {
        setState(() => _errorMessage = 'No se pudo iniciar sesión');
        return;
      }

      final usuario = await ds.obtenerUsuario(user.uid);
      if (usuario == null) {
        if (esUsuarioSoporte) return;
        await ds.logout();
        setState(() => _errorMessage = 'Usuario no registrado en el sistema');
        return;
      }

      if (usuario.activo != true) {
        if (esUsuarioSoporte) return;
        await ds.logout();
        setState(
          () =>
              _errorMessage = 'Usuario desactivado. Contacte al administrador',
        );
        return;
      }
    } catch (e) {
      setState(() => _errorMessage = _mapAuthError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String error) {
    if (error.contains('user-not-found')) return 'Usuario no encontrado';
    if (error.contains('wrong-password')) return 'Contraseña incorrecta';
    if (error.contains('invalid-email')) return 'Correo electrónico inválido';
    if (error.contains('too-many-requests')) {
      return 'Demasiados intentos. Intente más tarde';
    }
    if (error.contains('invalid-credential')) return 'Credenciales inválidas';
    return 'Error al iniciar sesión';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoginLogo(colorScheme: colorScheme),
                  const SizedBox(height: 40),
                  _LoginCard(
                    colorScheme: colorScheme,
                    emailCtrl: _emailCtrl,
                    errorMessage: _errorMessage,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onLogin: _handleLogin,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    passwordCtrl: _passwordCtrl,
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

class _LoginLogo extends StatelessWidget {
  final ColorScheme colorScheme;

  const _LoginLogo({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'QRecauda',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Panel Administrativo',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextEditingController emailCtrl;
  final String? errorMessage;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onLogin;
  final VoidCallback onTogglePassword;
  final TextEditingController passwordCtrl;

  const _LoginCard({
    required this.colorScheme,
    required this.emailCtrl,
    required this.errorMessage,
    required this.isLoading,
    required this.obscurePassword,
    required this.onLogin,
    required this.onTogglePassword,
    required this.passwordCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Iniciar Sesión',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailCtrl,
              keyboardType: kIsWeb
                  ? TextInputType.text
                  : TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              onSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                ),
              ),
              onSubmitted: (_) => onLogin(),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Ingresar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
