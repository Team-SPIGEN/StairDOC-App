import 'package:equatable/equatable.dart';

import '../../models/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.user,
    required this.token,
    this.rememberMe = false,
  });

  final User user;
  final String token;
  final bool rememberMe;

  @override
  List<Object?> get props => [user, token, rememberMe];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  const AuthError(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class AuthPasswordResetEmailSent extends AuthState {
  const AuthPasswordResetEmailSent(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
