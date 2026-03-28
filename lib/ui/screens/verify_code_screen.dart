import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/api_client.dart';
import 'login_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) {
      setState(() => _errorMessage = 'Ingresa los 6 dígitos del código');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.verifyEmail(email: widget.email, code: _code);

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('¡Cuenta verificada!'),
          content: const Text('Tu correo ha sido verificado. Ya puedes iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // cierra el dialog
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Iniciar sesión'),
            ),
          ],
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

  Future<void> _resend() async {
    try {
      await AuthService.resendVerification(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código reenviado a tu correo')),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reenviar el código')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: Color(0xFFB71C1C),
            ),
            const SizedBox(height: 30),
            const Text(
              "Verifica tu correo",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Text(
              "Hemos enviado un código de 6 dígitos a ${widget.email}. Tienes 1 hora para ingresarlo.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => _codeBox(i)),
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

            const SizedBox(height: 40),
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
                onPressed: _isLoading ? null : _verify,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text("VERIFICAR CÓDIGO"),
              ),
            ),
            TextButton(
              onPressed: _resend,
              child: const Text(
                "¿No recibiste el código? Reenviar",
                style: TextStyle(color: Color(0xFFB71C1C)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}
