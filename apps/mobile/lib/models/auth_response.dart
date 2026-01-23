import 'user.dart';

/// Response returned from authentication endpoints (login/register).
///
/// Contains the JWT token for API authorization and the authenticated user's profile.
class AuthResponse {
  const AuthResponse({required this.token, required this.user});

  /// JWT access token for authenticating subsequent API requests.
  final String token;

  /// The authenticated user's profile data.
  final User user;

  /// Creates an [AuthResponse] from a JSON map.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final tokenValue = json['token']?.toString() ?? '';
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return AuthResponse(token: tokenValue, user: User.fromJson(userJson));
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'user': user.toJson()};
  }
}
