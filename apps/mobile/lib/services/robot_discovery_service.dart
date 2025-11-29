import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../models/robot_endpoint.dart';
import '../utils/api_endpoints.dart';
import 'api_client.dart';

class RobotDiscoveryService {
  RobotDiscoveryService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static const String _serviceName = '_stairdoc-robot._tcp';
  static const Duration _defaultTimeout = Duration(seconds: 4);
  static const bool _httpFallbackEnabled = bool.fromEnvironment(
    'ENABLE_DISCOVERY_HTTP_FALLBACK',
    defaultValue: true,
  );
  static const bool _mockDiscoveryEnabled = bool.fromEnvironment(
    'ENABLE_MOCK_ROBOT_DISCOVERY',
    defaultValue: false,
  );

  final ApiClient _apiClient;

  Future<List<RobotEndpoint>> discoverRobots({Duration? timeout}) async {
    if (_mockDiscoveryEnabled) {
      return _mockEndpoints;
    }

    if (kIsWeb && !_httpFallbackEnabled) {
      throw UnsupportedError(
        'Robot discovery is not available on web builds when HTTP fallback is disabled.',
      );
    }

    final collected = <String, RobotEndpoint>{};
    final mdnsTimeout = timeout ?? _defaultTimeout;

    if (!kIsWeb) {
      final client = MDnsClient();

      try {
        await client.start();

        final ptrRecords = await _collectRecords<PtrResourceRecord>(
          client.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceName),
          ),
          mdnsTimeout,
        );

        for (final ptr in ptrRecords) {
          final srvRecords = await _collectRecords<SrvResourceRecord>(
            client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            ),
            mdnsTimeout,
          );

          final txtRecords = await _collectRecords<TxtResourceRecord>(
            client.lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName),
            ),
            mdnsTimeout,
          );

          for (final srv in srvRecords) {
            final host = await _resolveHost(client, srv.target, mdnsTimeout);
            final metadata = _mergeMetadata(txtRecords);
            final endpoint = _buildEndpoint(
              ptr: ptr,
              srv: srv,
              host: host,
              metadata: metadata,
            );
            collected[endpoint.id] = endpoint;
          }
        }
      } catch (_) {
        // Ignore mDNS errors and rely on fallback.
      } finally {
        try {
          client.stop();
        } catch (_) {
          // ignore stopping errors
        }
      }
    }

    if (collected.isEmpty && _httpFallbackEnabled) {
      final fallback = await _fetchDiscoveryFromApi();
      for (final endpoint in fallback) {
        collected.putIfAbsent(endpoint.id, () => endpoint);
      }
    }

    return collected.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<T>> _collectRecords<T>(Stream<T> stream, Duration timeout) async {
    final results = <T>[];
    try {
      await for (final record in stream.timeout(
        timeout,
        onTimeout: (sink) => sink.close(),
      )) {
        results.add(record);
      }
    } catch (_) {
      // Ignore stream errors for individual lookups.
    }
    return results;
  }

  Future<String> _resolveHost(
    MDnsClient client,
    String target,
    Duration timeout,
  ) async {
    final ipv4Records = await _collectRecords<IPAddressResourceRecord>(
      client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(target),
      ),
      timeout,
    );

    if (ipv4Records.isNotEmpty) {
      return ipv4Records.first.address.address;
    }

    final ipv6Records = await _collectRecords<IPAddressResourceRecord>(
      client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv6(target),
      ),
      timeout,
    );

    if (ipv6Records.isNotEmpty) {
      return ipv6Records.first.address.address;
    }

    return target;
  }

  Map<String, String> _mergeMetadata(List<TxtResourceRecord> txtRecords) {
    final metadata = <String, String>{};
    for (final txt in txtRecords) {
      final dynamic raw = txt.text;
      final values = <String>[];

      if (raw is Iterable) {
        for (final entry in raw) {
          values.add(entry.toString());
        }
      } else if (raw is String) {
        values.addAll(raw.split(RegExp(r'\s+')));
      }

      for (final value in values) {
        if (value.isEmpty) continue;
        final parts = value.split('=');
        if (parts.length == 2) {
          metadata[parts[0]] = parts[1];
        }
      }
    }
    return metadata;
  }

  RobotEndpoint _buildEndpoint({
    required PtrResourceRecord ptr,
    required SrvResourceRecord srv,
    required String host,
    required Map<String, String> metadata,
  }) {
    final id = metadata['id'] ?? '$host:${srv.port}';
    final name = metadata['name'] ?? ptr.domainName.split('.').first;
    final secureFlag = metadata['secure'] == 'true';
    final basePath = metadata['basePath'] ?? '/api/v1';
    final wsPath = metadata['wsPath'] ?? '/ws/robot-status';
    final wsPort = int.tryParse(metadata['wsPort'] ?? '') ?? srv.port;

    final scheme = secureFlag ? 'https' : 'http';
    final wsScheme = secureFlag ? 'wss' : 'ws';

    final normalizedBasePath = _normalizePath(basePath);
    final normalizedWsPath = _normalizePath(wsPath);

    final baseUrl = '$scheme://$host:${srv.port}$normalizedBasePath';
    final statusSocket = Uri.parse(
      '$wsScheme://$host:$wsPort$normalizedWsPath',
    );

    return RobotEndpoint(
      id: id,
      name: name,
      host: host,
      port: srv.port,
      baseUrl: baseUrl,
      statusSocketUri: statusSocket,
      metadata: metadata,
    );
  }

  Future<List<RobotEndpoint>> _fetchDiscoveryFromApi() async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiEndpoints.resolve(ApiEndpoints.robotDiscovery),
            options: Options(receiveTimeout: const Duration(seconds: 5)),
          )
          .timeout(const Duration(seconds: 3));

      final data = response.data;
      if (data is List) {
        final endpoints = <RobotEndpoint>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            endpoints.add(RobotEndpoint.fromJson(item));
          } else if (item is Map) {
            endpoints.add(
              RobotEndpoint.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            );
          }
        }
        return endpoints;
      }
    } catch (_) {
      // Ignore REST discovery errors; caller will handle empty list.
    }
    return const [];
  }
}

String _normalizePath(String rawPath) {
  if (rawPath.isEmpty) return '';
  return rawPath.startsWith('/') ? rawPath : '/$rawPath';
}

final List<RobotEndpoint> _mockEndpoints = List.unmodifiable([
  RobotEndpoint(
    id: 'mock-stairdoc-lab',
    name: 'Mock StairDoc (lab)',
    host: '127.0.0.1',
    port: 8000,
    baseUrl: 'http://127.0.0.1:8000/api/v1',
    statusSocketUri: Uri.parse('ws://127.0.0.1:8000/ws/robot-status'),
    metadata: const {'source': 'mock'},
  ),
]);
