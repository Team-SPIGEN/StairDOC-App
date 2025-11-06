import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth/auth_bloc.dart';
import '../../providers/auth/auth_event.dart';
import '../../providers/auth/auth_state.dart';
import '../../utils/ui_constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'operator';
  bool _acceptedTerms = false;
  String? _errorMessage;
  double _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController
      ..removeListener(_updatePasswordStrength)
      ..dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final strength = Validators.passwordStrength(_passwordController.text);
    setState(() => _passwordStrength = strength);
  }

  void _handleRegister() {
    FocusScope.of(context).unfocus();
    if (!_acceptedTerms) {
      setState(
        () => _errorMessage =
            'You must accept the Terms & Conditions to continue.',
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        RegisterRequested(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        ),
      );
    }
  }

  Color _passwordStrengthColor(ColorScheme colorScheme) {
    if (_passwordStrength >= 0.75) {
      return Colors.green.shade600;
    }
    if (_passwordStrength >= 0.5) {
      return colorScheme.primary;
    }
    if (_passwordStrength > 0) {
      return Colors.orange.shade600;
    }
    return colorScheme.surfaceContainerHighest;
  }

  String _passwordStrengthLabel() {
    if (_passwordStrength >= 0.75) return 'Strong';
    if (_passwordStrength >= 0.5) return 'Good';
    if (_passwordStrength > 0.25) return 'Weak';
    if (_passwordStrength > 0) return 'Very weak';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        } else if (state is AuthAuthenticated) {
          setState(() => _errorMessage = null);
          context.go('/dashboard');
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return LoadingOverlay(
          isLoading: isLoading,
          message: isLoading ? state.message : null,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.go('/login'),
              ),
              title: const Text('Create Account'),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register for Delivery Robot Control',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Configure account permissions to match your role before dispatching autonomous jobs.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    if (_errorMessage != null) ...[
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: 1,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Insets.sm),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withValues(alpha: 0.08),
                            borderRadius: CornerRadius.card,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: Insets.xs),
                              Expanded(
                                child: Text(
                                  _errorMessage ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _errorMessage = null),
                                icon: Icon(
                                  Icons.close,
                                  color: colorScheme.error,
                                ),
                                tooltip: 'Dismiss',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                    Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            label: 'Full name',
                            hintText: 'Enter your full name',
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.person_outline,
                            validator: Validators.validateName,
                          ),
                          const SizedBox(height: Insets.md),
                          CustomTextField(
                            label: 'Email',
                            hintText: 'you@organization.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: Insets.md),
                          CustomTextField(
                            label: 'Phone (optional)',
                            hintText: '+1 234 567 8910',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.phone_outlined,
                            validator: Validators.validatePhone,
                          ),
                          const SizedBox(height: Insets.md),
                          CustomTextField(
                            label: 'Password',
                            hintText: 'Minimum 8 characters',
                            controller: _passwordController,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.lock_outline,
                            validator: Validators.validatePassword,
                            isPassword: true,
                            enableObscureToggle: true,
                          ),
                          const SizedBox(height: Insets.xs),
                          Semantics(
                            label: 'Password strength indicator',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    minHeight: 6,
                                    value: _passwordStrength.clamp(0, 1),
                                    backgroundColor: colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.4),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _passwordStrengthColor(colorScheme),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Insets.xs),
                                Text(
                                  _passwordStrengthLabel(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _passwordStrengthColor(colorScheme),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          CustomTextField(
                            label: 'Confirm password',
                            hintText: 'Re-enter password',
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.lock_reset_outlined,
                            validator: (value) =>
                                Validators.validateConfirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                            isPassword: true,
                            enableObscureToggle: true,
                          ),
                          const SizedBox(height: Insets.md),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'operator',
                                child: Text('Operator'),
                              ),
                              DropdownMenuItem(
                                value: 'recipient',
                                child: Text('Recipient'),
                              ),
                            ],
                            onChanged: (role) => setState(
                              () => _selectedRole = role ?? 'operator',
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          CheckboxListTile(
                            value: _acceptedTerms,
                            onChanged: (value) =>
                                setState(() => _acceptedTerms = value ?? false),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: theme.textTheme.bodyMedium,
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: ' and privacy policy.'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Insets.lg),
                          CustomButton(
                            label: 'Create Account',
                            isLoading: isLoading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.go('/login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
