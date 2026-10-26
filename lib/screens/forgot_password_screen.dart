import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth.dart';
import '../widgets/auth_input.dart';

/// Recuperar la contraseña en dos pasos: pedir un código por email y luego
/// escribirlo con la nueva contraseña. Al terminar, la sesión queda iniciada
/// y el router lleva a la app.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Email que ya se había escrito en el login, si había alguno.
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {bool validate = true}) async {
    if (validate && !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Al reenviar, el email ya está validado (y el código aún vacío no debe impedirlo)
  Future<void> _sendCode() => _run(validate: !_codeSent, () async {
        await ref.read(authProvider).forgotPassword(_emailController.text);
        if (!mounted) return;
        setState(() {
          _codeSent = true;
          _codeController.clear();
          _info = 'Si hay una cuenta con ${_emailController.text.trim()}, te hemos enviado '
              'un código de 6 cifras. Revisa también la carpeta de spam.';
        });
      });

  // Al cambiarla se inicia sesión y el router lleva solo a la app
  Future<void> _resetPassword() => _run(() => ref.read(authProvider).resetPassword(
        _emailController.text,
        _codeController.text,
        _passwordController.text,
      ));

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _codeSent
                          ? 'Escribe el código que te hemos enviado y elige una contraseña nueva.'
                          : 'Escribe el email de tu cuenta y te enviaremos un código para '
                              'cambiar la contraseña.',
                      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_codeSent,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _codeSent ? null : _sendCode(),
                      decoration: authInputDecoration('Email', Icons.email_outlined),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Introduce tu email';
                        if (!email.contains('@') || !email.contains('.')) return 'Email no válido';
                        return null;
                      },
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(letterSpacing: 6, fontSize: 18),
                        decoration: authInputDecoration('Código de 6 cifras', Icons.pin_outlined),
                        validator: (value) =>
                            (value ?? '').length == 6 ? null : 'El código tiene 6 cifras',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _resetPassword(),
                        decoration: authInputDecoration('Contraseña nueva', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) =>
                            (value ?? '').length >= 8 ? null : 'Mínimo 8 caracteres',
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 16),
                      Text(_info!, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : (_codeSent ? _resetPassword : _sendCode),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_codeSent ? 'Cambiar contraseña' : 'Enviar código'),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                      _codeSent = false;
                                      _error = null;
                                      _info = null;
                                    }),
                            child: Text('Cambiar email', style: TextStyle(color: primary)),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _sendCode,
                            child: Text('Reenviar código', style: TextStyle(color: primary)),
                          ),
                        ],
                      ),
                    ],
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
