import 'package:equatable/equatable.dart';

class RobotEndpoint extends Equatable {
  const RobotEndpoint({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.baseUrl,
    required this.statusSocketUri,
    this.metadata = const {},
  });

  factory RobotEndpoint.fromJson(Map<String, dynamic> json) {
    final metadata = <String, String>{};
    final rawMetadata = json['metadata'];
    if (rawMetadata is Map) {
      for (final entry in rawMetadata.entries) {
        final key = entry.key?.toString();
        final value = entry.value?.toString();
        if (key != null && value != null) {
          metadata[key] = value;
        }
      }
    }

    final id = json['id']?.toString() ?? '${json['host']}:${json['port']}';
    final host = json['host']?.toString() ?? 'localhost';
    final port = int.tryParse(json['port']?.toString() ?? '') ?? 80;
    final baseUrl =
        json['baseUrl']?.toString() ??
        _buildBaseUrl(
          host: host,
          port: port,
          secure:
              json['secure'] == true || json['secure']?.toString() == 'true',
          basePath: json['basePath']?.toString(),
        );
    final statusSocketUrl =
        json['statusSocketUrl']?.toString() ??
        _buildStatusSocketUrl(
          host: host,
          port: int.tryParse(json['wsPort']?.toString() ?? '') ?? port,
          secure:
              json['secure'] == true || json['secure']?.toString() == 'true',
          wsPath: json['wsPath']?.toString(),
        );

    return RobotEndpoint(
      id: id,
      name: json['name']?.toString() ?? id,
      host: host,
      port: port,
      baseUrl: baseUrl,
      statusSocketUri: Uri.parse(statusSocketUrl),
      metadata: metadata,
    );
  }

  final String id;
  final String name;
  final String host;
  final int port;
  final String baseUrl;
  final Uri statusSocketUri;
  final Map<String, String> metadata;

  String get addressLabel => '$host:$port';

  RobotEndpoint copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? baseUrl,
    Uri? statusSocketUri,
    Map<String, String>? metadata,
  }) {
    return RobotEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      baseUrl: baseUrl ?? this.baseUrl,
      statusSocketUri: statusSocketUri ?? this.statusSocketUri,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [id, host, port, baseUrl, statusSocketUri];

  static String _buildBaseUrl({
    required String host,
    required int port,
    required bool secure,
    String? basePath,
  }) {
    final scheme = secure ? 'https' : 'http';
    final normalizedPath = _normalizePath(basePath ?? '/api/v1');
    return '$scheme://$host:$port$normalizedPath';
  }

  static String _buildStatusSocketUrl({
    required String host,
    required int port,
    required bool secure,
    String? wsPath,
  }) {
    final scheme = secure ? 'wss' : 'ws';
    final normalizedPath = _normalizePath(wsPath ?? '/ws/robot-status');
    return '$scheme://$host:$port$normalizedPath';
  }

  static String _normalizePath(String rawPath) {
    if (rawPath.isEmpty) return '';
    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }
}
