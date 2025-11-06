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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        LoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        } else if (state is AuthPasswordResetEmailSent) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
        } else if (state is AuthUnauthenticated) {
          if (state.message != null) {
            setState(() => _errorMessage = state.message);
          }
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
            appBar: AppBar(automaticallyImplyLeading: false),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Icon(
                              Icons.smart_toy_outlined,
                              size: 40,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            'Delivery Robot Control',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'Sign in to orchestrate secure document deliveries.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    if (_errorMessage != null) ...[
                      AnimatedOpacity(
                        opacity: _errorMessage != null ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
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
                        children: [
                          CustomTextField(
                            label: 'Email',
                            hintText: 'name@company.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: Insets.md),
                          CustomTextField(
                            label: 'Password',
                            hintText: 'Enter your password',
                            controller: _passwordController,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.lock_outline,
                            validator: Validators.validatePassword,
                            isPassword: true,
                            enableObscureToggle: true,
                          ),
                          const SizedBox(height: Insets.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () =>
                                    setState(() => _rememberMe = !_rememberMe),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) => setState(
                                          () => _rememberMe = value ?? false,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Remember me',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/forgot-password'),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          CustomButton(
                            label: 'Sign In',
                            isLoading: isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          children: [
                            TextSpan(
                              text: 'Register',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.go('/register'),
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
