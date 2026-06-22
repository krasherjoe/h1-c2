import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'debug_console.dart';

class MattermostPollingService {
  static final MattermostPollingService _instance = MattermostPollingService._internal();
  factory MattermostPollingService() => _instance;
  MattermostPollingService._internal();

  final Logger _logger = Logger();
  Timer? _pollingTimer;
  bool _isRunning = false;
  String? _pat;
  String? _channelId;
  String? _baseUrl;
  DateTime? _lastMessageTime;
  
  // 双方向通信用: agentからのメッセージ待ち受け
  final Map<String, Completer<String>> _pendingRequests = {};
  static const String _commandPrefix = '!opencode';
  static const String _agentPrefix = '!agent';
  static const String _prefsKeyPat = 'mattermost_pat';
  static const String _prefsKeyChannelId = 'mattermost_channel_id';
  static const String _prefsKeyBaseUrl = 'mattermost_base_url';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _pat = prefs.getString(_prefsKeyPat);
    _channelId = prefs.getString(_prefsKeyChannelId);
    _baseUrl = prefs.getString(_prefsKeyBaseUrl);
    
    if (_pat != null && _pat!.isNotEmpty) {
      _logger.i('[MattermostPolling] Initialized with PAT');
    }
  }

  Future<void> setCredentials(String pat, String channelId, String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPat, pat);
    await prefs.setString(_prefsKeyChannelId, channelId);
    await prefs.setString(_prefsKeyBaseUrl, baseUrl);
    
    _pat = pat;
    _channelId = channelId;
    _baseUrl = baseUrl;
    _logger.i('[MattermostPolling] Credentials saved');
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyPat);
    await prefs.remove(_prefsKeyChannelId);
    await prefs.remove(_prefsKeyBaseUrl);
    
    _pat = null;
    _channelId = null;
    _baseUrl = null;
    _logger.i('[MattermostPolling] Credentials cleared');
  }

  bool get isConfigured => _pat != null && _pat!.isNotEmpty && _channelId != null && _baseUrl != null;

  void startForegroundPolling() {
    if (!isConfigured) {
      _logger.w('[MattermostPolling] Not configured, skipping');
      return;
    }
    
    if (_isRunning) {
      _logger.w('[MattermostPolling] Already running');
      return;
    }

    _isRunning = true;
    _logger.i('[MattermostPolling] Started foreground polling');
    
    // 即時実行
    _poll();
    
    // 15秒間隔でポーリング
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  void stopForegroundPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
    _logger.i('[MattermostPolling] Stopped foreground polling');
  }

  Future<void> _poll() async {
    if (!isConfigured) return;

    try {
      final messages = await _fetchMessages();
      if (messages == null) return;

      final newMessages = _filterNewMessages(messages);
      
      for (final msg in newMessages) {
        await _processMessage(msg);
      }

      if (messages.isNotEmpty) {
        _lastMessageTime = DateTime.parse(messages.last['create_at'] as String);
      }
    } catch (e) {
      _logger.e('[MattermostPolling] Polling error: $e');
    }
  }

  Future<List<dynamic>?> _fetchMessages() async {
    if (_baseUrl == null || _channelId == null || _pat == null) return null;

    final url = Uri.parse('$_baseUrl/api/v4/channels/$_channelId/posts');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $_pat'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final posts = data['posts'] as Map<String, dynamic>;
      final order = data['order'] as List<dynamic>;
      
      return order.map((id) => posts[id as String]).toList();
    } else {
      _logger.e('[MattermostPolling] Fetch failed: ${response.statusCode}');
      return null;
    }
  }

  List<dynamic> _filterNewMessages(List<dynamic> messages) {
    if (_lastMessageTime == null) {
      return messages;
    }

    return messages.where((msg) {
      final createdAt = DateTime.parse(msg['create_at'] as String);
      return createdAt.isAfter(_lastMessageTime!);
    }).toList();
  }

  Future<void> _processMessage(Map<String, dynamic> message) async {
    final content = message['message'] as String? ?? '';
    final messageId = message['id'] as String;
    
    // !opencode コマンド処理
    if (content.startsWith(_commandPrefix)) {
      final commandText = content.substring(_commandPrefix.length).trim();
      final parts = commandText.split(' ');
      final command = parts.isNotEmpty ? parts[0] : '';
      final args = parts.length > 1 ? parts.sublist(1) : <String>[];

      _logger.i('[MattermostPolling] Processing command: $command with args: $args');

      // DebugConsole経由でコマンド実行
      final result = await _executeCommand(command, args);
      
      // 結果をMattermostに投稿
      await _postResult(messageId, result);
    }
    // !agent レスポンス処理（双方向通信用）
    else if (content.startsWith(_agentPrefix)) {
      final responseText = content.substring(_agentPrefix.length).trim();
      _logger.i('[MattermostPolling] Received agent response: $responseText');
      
      // 待ち受け中のリクエストに応答
      final completer = _pendingRequests[messageId];
      if (completer != null) {
        completer.complete(responseText);
        _pendingRequests.remove(messageId);
      }
    }
  }

  Future<String> _executeCommand(String command, List<String> args) async {
    try {
      final result = await DebugConsole.call(command, args);
      return result;
    } catch (e) {
      _logger.e('[MattermostPolling] Command execution error: $e');
      return 'Error: $e';
    }
  }

  Future<void> _postResult(String postId, String result) async {
    if (_baseUrl == null || _channelId == null || _pat == null) return;

    final url = Uri.parse('$_baseUrl/api/v4/posts');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_pat',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'channel_id': _channelId,
        'root_id': postId,
        'message': result,
      }),
    );

    if (response.statusCode == 201) {
      _logger.i('[MattermostPolling] Result posted');
    } else {
      _logger.e('[MattermostPolling] Post failed: ${response.statusCode}');
    }
  }

  // agentからのメッセージを送信し、応答を待つ
  Future<String> sendAgentMessage(String message, {Duration timeout = const Duration(minutes: 5)}) async {
    if (!isConfigured) {
      throw Exception('Mattermost not configured');
    }

    final url = Uri.parse('$_baseUrl/api/v4/posts');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_pat',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'channel_id': _channelId,
        'message': '$_agentPrefix $message',
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to send agent message: ${response.statusCode}');
    }

    final responseData = jsonDecode(response.body);
    final messageId = responseData['id'] as String;
    
    // 応答を待ち受け
    final completer = Completer<String>();
    _pendingRequests[messageId] = completer;
    
    try {
      final result = await completer.future.timeout(timeout);
      return result;
    } catch (e) {
      _pendingRequests.remove(messageId);
      throw Exception('Agent response timeout: $e');
    }
  }
}
