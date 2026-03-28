import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/api_client.dart';
import 'verify_code_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _aceptaDatos = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.register(
        userName: _userNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VerifyCodeScreen(email: _emailController.text.trim()),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage = 'Error de conexión. Verifica que el servidor esté activo.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Crear Cuenta",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Hero(
                tag: 'logo',
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 70,
                  color: Color(0xFFB71C1C),
                ),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _userNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingresa un nombre de usuario' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || !val.contains('@') ? 'Ingresa un correo válido' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_open_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    val == null || val.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 25),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CheckboxListTile(
                  activeColor: const Color(0xFFB71C1C),
                  title: const Text(
                    "Acepto la política de tratamiento de datos personales de la UPB (Ley 1581 de 2012).",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _aceptaDatos,
                  onChanged: (val) => setState(() => _aceptaDatos = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: (_aceptaDatos && !_isLoading) ? _register : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "REGISTRARSE",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
