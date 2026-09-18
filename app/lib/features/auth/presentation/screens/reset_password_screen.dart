import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// Shown by [AuthGate] in place of the normal app whenever
/// [passwordRecoveryProvider] is true — the user opened a password-recovery
/// link and holds a temporary session that should only be used to set a new
/// password, never to browse the app with the old one still active.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).updatePassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next is AsyncData<void> && previous is AsyncLoading<void>) {
        ref.read(passwordRecoveryProvider.notifier).clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Password updated.', style: TextStyle(color: Colors.white)),
          ),
        );
      }
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                error.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', ''),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NoSusTheme.s24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SET A NEW PASSWORD',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s8),
                  Text(
                    'Choose a new password for your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtle, fontSize: 13),
                  ),
                  const SizedBox(height: NoSusTheme.s32),
                  Container(
                    padding: const EdgeInsets.all(NoSusTheme.s24),
                    decoration: NoSusTheme.cardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          autofocus: true,
                          cursorColor: fg,
                          style: TextStyle(color: fg, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'NEW PASSWORD',
                            labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                            floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                            ),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 18,
                                color: subtle,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password is required';
                            if (value.length < 6) return 'Must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: NoSusTheme.s16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscure,
                          cursorColor: fg,
                          style: TextStyle(color: fg, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'CONFIRM PASSWORD',
                            labelStyle: TextStyle(color: subtle, fontSize: 10, letterSpacing: 1.0),
                            floatingLabelStyle: TextStyle(color: fg, fontSize: 11, letterSpacing: 1.0),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: fg.withValues(alpha: 0.15)),
                            ),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg)),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: NoSusTheme.s32),
                        Semantics(
                          button: true,
                          enabled: !authState.isLoading,
                          label: 'Update password',
                          child: GestureDetector(
                            onTap: authState.isLoading ? null : _submit,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(14)),
                              child: Center(
                                child: authState.isLoading
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: isDark ? Colors.black : Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'UPDATE PASSWORD',
                                        style: TextStyle(
                                          color: isDark ? Colors.black : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
