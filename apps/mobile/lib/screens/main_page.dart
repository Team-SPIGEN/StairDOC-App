import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth/auth_bloc.dart';
import '../providers/auth/auth_event.dart';
import '../providers/auth/auth_state.dart';
import '../utils/ui_constants.dart';
import '../widgets/custom_button.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Robot Controls',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.go('/robot-controls'),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                context.read<AuthBloc>().add(const LogoutRequested()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${state.user.name.split(' ').first}!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'You are logged in as ${state.user.role.toUpperCase()}. Manage deliveries, monitor robot vitals, and review access events.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Insets.md),
                      decoration: BoxDecoration(
                        borderRadius: CornerRadius.card,
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.local_shipping_outlined,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: Insets.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick Actions',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'Begin configuring delivery routes, monitoring robot telemetry, and reviewing access events.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.65),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          Wrap(
                            spacing: Insets.sm,
                            runSpacing: Insets.sm,
                            children: const [
                              _DashboardPill(label: 'Robot vitals'),
                              _DashboardPill(label: 'Delivery queue'),
                              _DashboardPill(label: 'Access logs'),
                              _DashboardPill(label: 'Voice control'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    CustomButton(
                      label: 'Robot Controls',
                      onPressed: () => context.go('/robot-controls'),
                    ),
                    const SizedBox(height: Insets.sm),
                    CustomButton(
                      label: 'Log out',
                      variant: CustomButtonVariant.secondary,
                      onPressed: () =>
                          context.read<AuthBloc>().add(const LogoutRequested()),
                    ),
                  ],
                );
              }

              return Center(
                child: CustomButton(
                  label: 'Back to Sign In',
                  onPressed: () =>
                      context.read<AuthBloc>().add(const LogoutRequested()),
                  variant: CustomButtonVariant.primary,
                  size: CustomButtonSize.auto,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardPill extends StatelessWidget {
  const _DashboardPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
