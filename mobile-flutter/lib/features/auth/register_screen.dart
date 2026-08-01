import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mudbase_exception.dart';
import '../../core/rbac.dart';
import 'auth_controller.dart';

/// Real signup, choosing a role - mirrors the web app's `RegisterForm.tsx`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = AppRole.client;
  bool _agreedToTerms = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      setState(
        () => _errorMessage =
            'You must agree to the Terms of Service and Privacy Policy.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            role: _role,
            agreedToTerms: _agreedToTerms,
          );
      if (mounted) {
        context
            .go(_role == AppRole.client ? '/listings/mine' : '/proposals/mine');
      }
    } on MudbaseException catch (error) {
      setState(() => _errorMessage = error.message);
    } on FormatException {
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Choose whether you're hiring or looking for work.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                if (errorMessage != null) ...[
                  Text(
                    errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _RoleOption(
                        label: 'Hire freelancers',
                        selected: _role == AppRole.client,
                        onTap: () => setState(() => _role = AppRole.client),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RoleOption(
                        label: 'Find work',
                        selected: _role == AppRole.freelancer,
                        onTap: () => setState(() => _role = AppRole.freelancer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration:
                            const InputDecoration(labelText: 'First name'),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'First name is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration:
                            const InputDecoration(labelText: 'Last name'),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Last name is required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (!trimmed.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) {
                    if ((value ?? '').length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _agreedToTerms,
                  onChanged: (value) =>
                      setState(() => _agreedToTerms = value ?? false),
                  title: const Text(
                    'I agree to the Terms of Service and Privacy Policy.',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: _submitting ? null : () => context.pop(),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? colorScheme.secondaryContainer : null,
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
