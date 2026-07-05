import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../models/sync_record.dart';

class OtsukueApiClient {
  final String baseUrl;
  String? _authToken;
  final http.Client _client;

  OtsukueApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      _log('healthCheck failed: $e');
      return false;
    }
  }

  Future<List<SyncRecord>> pullChanges(DateTime since) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/sync/pull?since=${since.toIso8601String()}'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((r) => SyncRecord.fromMap(r)).toList();
      }
      return [];
    } catch (e) {
      _log('pullChanges failed: $e');
      return [];
    }
  }

  Future<SyncResult> pushChanges(List<SyncRecord> records) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/sync/push'),
        headers: _headers,
        body: jsonEncode(records.map((r) => r.toMap()).toList()),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SyncResult(
          synced: data['synced'] as int,
          failed: data['failed'] as int,
          conflicts: (data['conflicts'] as List?)?.cast<String>() ?? [],
        );
      }
      return SyncResult(synced: 0, failed: records.length);
    } catch (e) {
      _log('pushChanges failed: $e');
      return SyncResult(synced: 0, failed: records.length);
    }
  }

  Future<List<Map<String, dynamic>>> getMessages({String? channelId, DateTime? since}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/messages').replace(
        queryParameters: {
          if (channelId != null) 'channel': channelId,
          if (since != null) 'since': since.toIso8601String(),
        },
      );
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      _log('getMessages failed: $e');
      return [];
    }
  }

  Future<bool> sendMessage(String channelId, String content) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/chat/messages'),
        headers: _headers,
        body: jsonEncode({'channel': channelId, 'content': content}),
      );
      return response.statusCode == 200;
    } catch (e) {
      _log('sendMessage failed: $e');
      return false;
    }
  }

  Future<String?> uploadFile(List<int> bytes, String fileName, String entityType, String entityId) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/files'));
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      request.fields['entity_type'] = entityType;
      request.fields['entity_id'] = entityId;
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        return jsonDecode(body)['file_id'] as String;
      }
      return null;
    } catch (e) {
      _log('uploadFile failed: $e');
      return null;
    }
  }

  void _log(String msg) {
    debugPrint('[OtsukueApi] $msg');
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final List<String> conflicts;

  const SyncResult({required this.synced, required this.failed, this.conflicts = const []});
}
