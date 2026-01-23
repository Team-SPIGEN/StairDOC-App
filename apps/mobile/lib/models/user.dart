/// Represents an authenticated user in the StairDOC system.
///
/// Contains identity information and role-based access control data.
/// Used throughout the app for displaying user info and authorization checks.
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  /// Unique identifier for the user.
  final String id;

  /// User's display name.
  final String name;

  /// User's email address (used for login).
  final String email;

  /// User's role determining access permissions (e.g., 'operator', 'recipient', 'admin').
  final String role;

  /// Optional phone number for contact purposes.
  final String? phone;

  /// Creates a [User] instance from a JSON map.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'operator',
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
    }..removeWhere((_, value) => value == null);
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
    );
  }
}
