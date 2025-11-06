import 'user.dart';

class AuthResponse {
  const AuthResponse({required this.token, required this.user});

  final String token;
  final User user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final tokenValue = json['token']?.toString() ?? '';
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return AuthResponse(token: tokenValue, user: User.fromJson(userJson));
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'user': user.toJson()};
  }
}
