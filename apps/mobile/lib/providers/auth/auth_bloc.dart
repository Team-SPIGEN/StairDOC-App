import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthService authService,
    required StorageService storageService,
  }) : _authService = authService,
       _storageService = storageService,
       super(const AuthInitial()) {
    on<AuthAppStarted>(_onAppStarted, transformer: _sequential());
    on<LoginRequested>(_onLoginRequested, transformer: _sequential());
    on<RegisterRequested>(_onRegisterRequested, transformer: _sequential());
    on<ForgotPasswordRequested>(
      _onForgotPasswordRequested,
      transformer: _sequential(),
    );
    on<LogoutRequested>(_onLogoutRequested, transformer: _sequential());
  }

  final AuthService _authService;
  final StorageService _storageService;

  EventTransformer<E> _sequential<E extends AuthEvent>() {
    return (events, mapper) => events.asyncExpand(mapper);
  }

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Checking session…'));
    try {
      final token = await _storageService.readToken();
      final userData = await _storageService.readUser();
      final rememberMe = await _storageService.readRememberMe();

      if (token != null && token.isNotEmpty && userData != null) {
        final user = User.fromJson(userData);
        emit(
          AuthAuthenticated(user: user, token: token, rememberMe: rememberMe),
        );
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Signing you in…'));
    try {
      final response = await _authService.login(
        email: event.email,
        password: event.password,
      );

      await _storageService.persistSession(
        token: response.token,
        user: response.user.toJson(),
        rememberUser: event.rememberMe,
      );

      emit(
        AuthAuthenticated(
          user: response.user,
          token: response.token,
          rememberMe: event.rememberMe,
        ),
      );
    } on AuthException catch (error) {
      emit(AuthError(error.message, code: error.code));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again later.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Creating your account…'));
    try {
      final response = await _authService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        role: event.role,
        phone: event.phone,
      );

      await _storageService.persistSession(
        token: response.token,
        user: response.user.toJson(),
        rememberUser: true,
      );

      emit(
        AuthAuthenticated(
          user: response.user,
          token: response.token,
          rememberMe: true,
        ),
      );
    } on AuthException catch (error) {
      emit(AuthError(error.message, code: error.code));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again later.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onForgotPasswordRequested(
    ForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Sending reset link…'));
    try {
      final message = await _authService.forgotPassword(email: event.email);
      emit(AuthPasswordResetEmailSent(message));
      emit(const AuthUnauthenticated());
    } on AuthException catch (error) {
      emit(AuthError(error.message, code: error.code));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again later.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _storageService.clearSession();
    emit(const AuthUnauthenticated());
  }
}
