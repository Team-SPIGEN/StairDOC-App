import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth/auth_bloc.dart';
import '../providers/auth/auth_state.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/splash/splash_screen.dart';

class AppRouter {
  AppRouter(this.authBloc)
    : router = GoRouter(
        initialLocation: '/',
        refreshListenable: GoRouterRefreshStream(authBloc.stream),
        routes: [
          GoRoute(
            path: '/',
            name: 'splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            name: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/forgot-password',
            name: 'forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
        redirect: (context, state) {
          final authState = authBloc.state;
          final goingToSplash = state.matchedLocation == '/';
          final goingToAuthRoute = _authRoutes.contains(state.matchedLocation);

          if (authState is AuthLoading || authState is AuthInitial) {
            return null;
          }

          if (authState is AuthAuthenticated) {
            if (goingToSplash || goingToAuthRoute) {
              return '/dashboard';
            }
            return null;
          }

          if (authState is AuthUnauthenticated ||
              authState is AuthError ||
              authState is AuthPasswordResetEmailSent) {
            if (goingToAuthRoute) {
              return null;
            }
            return '/login';
          }

          return null;
        },
      );

  final AuthBloc authBloc;
  final GoRouter router;

  static const Set<String> _authRoutes = {
    '/login',
    '/register',
    '/forgot-password',
  };
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
    notifyListeners();
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
