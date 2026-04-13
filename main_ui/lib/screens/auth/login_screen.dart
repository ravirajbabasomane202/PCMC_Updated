import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_ui/providers/auth_provider.dart';
import 'package:main_ui/utils/validators.dart';
import 'package:main_ui/l10n/app_localizations.dart';
import 'package:main_ui/widgets/custom_button.dart';
import 'package:main_ui/exceptions/auth_exception.dart';
import 'package:main_ui/services/api_service.dart'; // Assuming ApiService is available for direct API calls

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  String _name = '';
  String _email = '';
  String _password = '';
  String _address = '';
  String _phone = '';
  String _voterId = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await ref.read(authProvider.notifier)
            .loginWithEmail(_email, _password);
      } else {
        await ref.read(authProvider.notifier).register(
          _name,
          _email,
          _password,
          address: _address,
          phoneNumber: _phone,
          voterId: _voterId,
        );
      }

      final user = ref.read(authProvider);
      if (user != null) {
        Navigator.pushReplacementNamed(
          context,
          '/${user.role}/home',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.authenticationFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      String message = l10n.authenticationFailed;

      if (e is AuthException) {
        message = e.message; // 🔥 backend message
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            _isLogin ? l10n.loginFailed : l10n.registrationFailed,
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestPasswordReset(String email) async {
    try {
      // Call the forgot password API endpoint
      final response = await ApiService.post('/auth/forgot-password', {'email': email});
      
      // Close the dialog first
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Adjust check based on backend response format (e.g., {'message': 'Password reset email sent'})
      final data = response.data;
      final message = data['message'] ?? (data['error'] ?? 'Unknown response');
      final isSuccess = !message.toLowerCase().contains('error') && !message.toLowerCase().contains('failed');
      
      if (isSuccess) {
        // Success: Show message directing to web domain
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Password reset email sent successfully! Check your email for a link to reset your password on https://www.nivaran.co.in.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Error: Show failure message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure dialog closes on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => ForgotPasswordDialog(
        onSubmit: _requestPasswordReset,
      ),
    );
  }

  String? validatePhone(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.phoneNumberRequired;
    }
    if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(value)) {
      return l10n.invalidMobileNumber;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              Center(
                child: Text(
                  _isLogin ? l10n.login : l10n.register,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0076FD),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isLogin
                      ? l10n.welcomeBack
                      : l10n.createAccountPrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: l10n.name,
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: validateRequired,
                        onSaved: (v) => _name = v!,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: l10n.address,
                          prefixIcon: const Icon(Icons.home_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: validateRequired,
                        onSaved: (v) => _address = v!,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: l10n.phoneNumber,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => validatePhone(v, l10n),
                        onSaved: (v) => _phone = v!,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: l10n.voterId,
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: validateRequired,
                        onSaved: (v) => _voterId = v!,
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmail,
                      onSaved: (v) => _email = v!,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscurePassword,
                      validator: validateRequired,
                      onSaved: (v) => _password = v!,
                    ),

                    // Forgot Password link (only for login mode)
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            l10n.forgotPassword ?? 'Forgot Password?',
                            style: TextStyle(
                              color: const Color(0xFF0076FD),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    CustomButton(
                      text: _isLogin ? l10n.login : l10n.register,
                      onPressed: _isLoading ? null : _submit,
                      isLoading: _isLoading,
                      fullWidth: true,
                      backgroundColor: const Color(0xFF151a2f),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _isLogin
                                ? l10n.registerPrompt
                                : l10n.loginPrompt,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _formKey.currentState?.reset();
                            });
                          },
                          child: Text(
                            _isLogin ? l10n.register : l10n.login,
                            style: TextStyle(color: const Color(0xFF0076FD)),
                          ),
                        ),
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
}

// Simple StatefulWidget for Forgot Password Dialog (to manage TextEditingController)
class ForgotPasswordDialog extends StatefulWidget {
  final Function(String) onSubmit;

  const ForgotPasswordDialog({super.key, required this.onSubmit});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false; // Added loading state for the send button
  bool _isFormValid = false; // Track form validation state

  @override
  void initState() {
    super.initState();
    // Listen to form field changes to update validation state
    _emailController.addListener(_updateFormValidation);
  }

  void _updateFormValidation() {
    final isValid = _emailController.text.isNotEmpty && 
                    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text);
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.forgotPassword ?? 'Forgot Password?'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.forgotPasswordDescription ?? 'Enter your email address below. We\'ll send you a link to reset your password on our website.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.email_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.emailRequired ?? 'Email is required';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return l10n.invalidEmail ?? 'Please enter a valid email';
                }
                return null;
              },
              onFieldSubmitted: (value) {
                if (_isFormValid && !_isSending) {
                  _handleSubmit(value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending || !_isFormValid ? null : () {
            final email = _emailController.text.trim();
            if (email.isNotEmpty) {
              _handleSubmit(email);
            }
          },
          child: _isSending 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(l10n.send ?? 'Send Reset Link'),
        ),
      ],
    );
  }

  void _handleSubmit(String email) async {
    if (_isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      await widget.onSubmit(email);
      // Note: The dialog will be closed by the onSubmit function after success
    } catch (e) {
      // Error handling is done in the parent widget, but we need to re-enable the button
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    
    // Don't setState here if the dialog was already closed
    if (mounted && _isSending) {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateFormValidation);
    _emailController.dispose();
    super.dispose();
  }
}