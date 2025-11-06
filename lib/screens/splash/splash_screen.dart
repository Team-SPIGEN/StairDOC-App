import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth/auth_bloc.dart';
import '../../providers/auth/auth_event.dart';
import '../../providers/auth/auth_state.dart';
import '../../utils/ui_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  String _targetRoute = '/login';

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthAppStarted());
    _timer = Timer(const Duration(seconds: 2), _navigateNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateNext() {
    if (!mounted) return;
    context.go(_targetRoute);
  }

  void _resolveNext(AuthState state) {
    if (state is AuthAuthenticated) {
      _targetRoute = '/dashboard';
    } else {
      _targetRoute = '/login';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _resolveNext(state);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                Semantics(
                  label: 'Delivery Robot Control splash graphic',
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 52,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  'Delivery Robot Control',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Managing autonomous stair-climbing deliveries with confidence.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Column(
                  children: [
                    const SizedBox(height: Insets.md),
                    Semantics(
                      label: 'Loading',
                      child: SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Preparing systems…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
