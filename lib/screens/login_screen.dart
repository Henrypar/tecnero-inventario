// Pantalla de ingreso al sistema con autenticacion por correo y clave.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/providers.dart';
import '../models/models.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y contraseña');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(apiServiceProvider);
      await svc.login(_emailCtrl.text.trim(), _passCtrl.text);
      final usuario = await svc.getUsuarioActual();
      if (usuario == null) throw Exception('Usuario no encontrado');
      ref.invalidate(usuarioActualProvider);
      if (!mounted) return;
      _redirigir(usuario.rol);
    } on ApiConnectionException catch (e) {
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401
            ? 'Credenciales incorrectas. Verifica e intenta de nuevo.'
            : e.message;
      });
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _redirigir(RolUsuario rol) {
    switch (rol) {
      case RolUsuario.admin:
        context.go('/admin/dashboard');
      case RolUsuario.coordinador:
        context.go('/coordinador/aprobaciones');
      case RolUsuario.operario:
        context.go('/operario/nueva-solicitud');
      case RolUsuario.bodeguero:
        context.go('/bodeguero/entregas');
      case RolUsuario.asistenteCompras:
        context.go('/admin/precios');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TecneroTheme.azulOscuro,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: TecneroTheme.naranja,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: TecneroTheme.azulOscuro,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TECNERO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sistema de Inventarios',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 40),

              // Card login
              Container(
                width: 360,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: TecneroTheme.textoPrimario,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ingresa con tu cuenta asignada',
                      style: TextStyle(
                        fontSize: 13,
                        color: TecneroTheme.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined, size: 18),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Ingresar'),
                    ),
                    const SizedBox(height: 16),
                    // Accesos rápidos demo
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Accesos rápidos (demo)',
                      style: TextStyle(
                          fontSize: 11, color: TecneroTheme.textoSecundario),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _demoBtn('Admin', 'admin@tecnero.com', '123456',
                            TecneroTheme.azulOscuro),
                        _demoBtn('Coordinador', 'coord@tecnero.com', '123456',
                            TecneroTheme.azulMedio),
                        _demoBtn('Operario', 'operario@tecnero.com', '123456',
                            TecneroTheme.naranja),
                        _demoBtn('Bodeguero', 'bodega@tecnero.com', '123456',
                            const Color(0xFF059669)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoBtn(String label, String email, String pass, Color color) {
    return InkWell(
      onTap: () {
        _emailCtrl.text = email;
        _passCtrl.text = pass;
        _login();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
