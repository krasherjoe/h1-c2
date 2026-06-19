import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// SSHポートフォワードソケット — 前方けチャネルをSSHソケットとしてラップ
class _ForwardSocket implements SSHSocket {
  final SSHForwardChannel channel;
  final StreamController<Uint8List> _streamController;

  _ForwardSocket(this.channel)
      : _streamController = StreamController<Uint8List>() {
    channel.stream.listen(
      _streamController.add,
      onError: _streamController.addError,
      onDone: _streamController.close,
    );
  }

  @override
  Stream<Uint8List> get stream => _streamController.stream;

  @override
  StreamSink<List<int>> get sink => channel.sink;

  @override
  Future<void> get done => channel.done;

  @override
  Future<void> close() async {
    await _streamController.close();
    channel.close();
  }

  @override
  void destroy() {
    _streamController.close();
    channel.close();
  }
}

/// SSHポートフォワードサービス（可変長ProxyJumpチェーン対応）
class SshTunnelService {
  static final SshTunnelService instance = SshTunnelService._();
  SshTunnelService._();

  // 各ホップのSSHクライアント（可変長）
  final List<SSHClient> _clients = [];

  // ポートフォワード（Android:8080 → 最終ホスト:8080）
  SSHRemoteForward? _forward;

  /// SSH設定テキストと秘密鍵テキスト
  String? configText;
  String? keyText;

  final ValueNotifier<bool> onlineNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusNotifier = ValueNotifier('');
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  bool get isConnected => _clients.isNotEmpty && !_clients.last.isClosed;

  /// 最終ホスト（接続先）のクライアント
  SSHClient? get lastClient => _clients.isEmpty ? null : _clients.last;

  /// SSH configテキストをパースしてホスト情報を取得
  Map<String, SshHostEntry> _parseConfig(String text) {
    final entries = <String, SshHostEntry>{};
    final lines = text.split('\n');
    SshHostEntry? current;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;

      final key = parts[0].toLowerCase();
      final value = parts.skip(1).join(' ').trim();

      if (key == 'host') {
        // 複数のホスト名に対応（スペース区切り）
        for (final hostName in parts.skip(1)) {
          entries[hostName.toLowerCase()] = SshHostEntry(alias: hostName);
        }
        current = entries.entries.last.value;
      } else if (current != null) {
        switch (key) {
          case 'hostname':
            current.resolvedHostname = value;
            break;
          case 'port':
            current.port = int.tryParse(value) ?? 22;
            break;
          case 'user':
          case 'username':
            current.username = value;
            break;
          case 'proxyjump':
            current.proxyJump = value;
            break;
        }
      }
    }

    return entries;
  }

  /// ProxyJumpチェーンを逆順で解決（最終ホスト → 中継 → 最外側）
  List<SshHostEntry> _resolveJumpChain(
    Map<String, SshHostEntry> entries,
    String target,
  ) {
    final chain = <SshHostEntry>[];
    String? current = target.toLowerCase();

    while (current != null) {
      final entry = entries[current];
      if (entry == null) {
        throw StateError('ホストが見つかりません: $current');
      }
      chain.add(entry);
      current = entry.proxyJump;
    }

    // 逆順（最外側 → ... → 最終ホスト）
    return chain.reversed.toList();
  }

  /// 秘密鍵をパース
  List<SSHKeyPair> _parseKey(String keyText) {
    final pem = keyText.trim();
    if (pem.isEmpty) throw StateError('秘密鍵が空です');

    try {
      final pairs = SSHKeyPair.fromPem(pem);
      if (pairs.isEmpty) throw StateError('秘密鍵からキーペアを取得できません');
      return pairs;
    } catch (e) {
      throw StateError('秘密鍵のパースに失敗しました: $e');
    }
  }

  /// 単一ホップに接続
  Future<SSHClient> _connectHop({
    required String hostname,
    required int port,
    required String username,
    required List<SSHKeyPair> keyPairs,
    SSHSocket? socket,
  }) async {
    debugPrint('[SshTunnel] Connecting to $hostname:$port as $username');

    final sshSocket = socket ?? await SSHSocket.connect(hostname, port);

    final client = SSHClient(
      sshSocket,
      username: username,
      identities: keyPairs,
      disableHostkeyVerification: true,
      printDebug: (msg) => debugPrint('[SshTunnel] $msg'),
    );

    // 認証待ち（タイムアウト30秒）
    await client.authenticated.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        client.close();
        throw StateError('認証タイムアウト: $hostname');
      },
    );

    debugPrint('[SshTunnel] Connected to $hostname:$port');
    return client;
  }

  /// ProxyJumpチェーン経由で最終ホストに接続（可変長）
  Future<void> connect() async {
    // 既に接続済みなら切断
    if (isConnected) {
      await disconnect();
    }

    try {
      errorNotifier.value = null;

      // 入力検証
      if (configText == null || configText!.trim().isEmpty) {
        throw StateError('SSH configが設定されていません');
      }
      if (keyText == null || keyText!.trim().isEmpty) {
        throw StateError('秘密鍵が設定されていません');
      }

      // Configパース
      final entries = _parseConfig(configText!);
      debugPrint('[SshTunnel] Parsed ${entries.length} host entries');

      // キーパース
      final keyPairs = _parseKey(keyText!);
      debugPrint('[SshTunnel] Loaded ${keyPairs.length} key pair(s)');

      // ProxyJumpチェーン解決（最終ホストから逆順に全中間ホップを取得）
      final target = entries.keys.isNotEmpty ? entries.keys.last.toLowerCase() : 'gui1';
      final chain = _resolveJumpChain(entries, target);
      debugPrint('[SshTunnel] Jump chain: ${chain.map((e) => e.resolvedHostname).join(' → ')}');

      if (chain.isEmpty) {
        throw StateError('接続先ホストが見つかりません');
      }

      // 各ホップに接続
      for (var i = 0; i < chain.length; i++) {
        final hop = chain[i];
        statusNotifier.value = '${hop.resolvedHostname} に接続中...';

        SSHSocket? nextSocket;

        if (i > 0) {
          // プロキシ経由：前のクライアントでforwardLocal
          final prevClient = _getClient(i - 1);
          debugPrint('[SshTunnel] Forwarding via ${chain[i - 1].connectTarget} → ${hop.connectTarget}:${hop.port}');

          final channel = await prevClient.forwardLocal(
            hop.connectTarget,
            hop.port,
          );
          nextSocket = _ForwardSocket(channel);
        }

       final client = await _connectHop(
          hostname: hop.connectTarget,
          port: hop.port,
          username: hop.username ?? 'root',
          keyPairs: keyPairs,
          socket: nextSocket,
        );

        // クライアントを保存
        _clients.add(client);
      }

      // ポートフォワード: gui1:8080 → Android:8080 (ICE API)
      statusNotifier.value = 'ポートフォワード設定中...';
      if (lastClient != null) {
        _forward = await lastClient!.forwardRemote(
          host: '0.0.0.0',
          port: 8080, // ICE API Server
        );
        debugPrint('[SshTunnel] Remote forward set up: ${chain.last.resolvedHostname}:0.0.0.0:8080 → Android');
      }

      // ONLINE状態
      onlineNotifier.value = true;
      statusNotifier.value = '接続済み (${lastClient?.remoteVersion ?? ''})';
      debugPrint('[SshTunnel] Connected! ${chain.last.resolvedHostname}:8080 → Android ICE API');

    } catch (e) {
      errorNotifier.value = e.toString();
      onlineNotifier.value = false;
      statusNotifier.value = '接続失敗';
      debugPrint('[SshTunnel] Connection failed: $e');
      // 部分的に接続済みの場合は切断
      await _disconnectInternal();
    }
  }

  /// インデックスのクライアントを取得
  SSHClient _getClient(int index) {
    if (index < 0 || index >= _clients.length) {
      throw StateError('不明なインデックス: $index');
    }
    return _clients[index];
  }

  /// 切断
  Future<void> disconnect() async {
    statusNotifier.value = '切断中...';
    await _disconnectInternal();
    onlineNotifier.value = false;
    statusNotifier.value = '切断済み';
    debugPrint('[SshTunnel] Disconnected');
  }

  /// 内部切断処理
  Future<void> _disconnectInternal() async {
    try {
      _forward?.close();
      _forward = null;
    } catch (_) {}

    for (final client in List.from(_clients)) {
      try {
        if (!client.isClosed) {
          client.close();
        }
      } catch (_) {}
    }

    _clients.clear();
  }

  /// dispose（リソース解放）
  void dispose() {
    disconnect();
    onlineNotifier.dispose();
    statusNotifier.dispose();
    errorNotifier.dispose();
  }
}

/// SSH configのホストエントリ
class SshHostEntry {
  /// Host行のエイリアス（pve1, labo, gui1など）
  final String alias;

  /// 解決済みホスト名（configのHostname値、なければalias）
  String? resolvedHostname;

  int port = 22;
  String? username;
  String? proxyJump;

  SshHostEntry({required this.alias});

  /// 実際に接続するホスト名
  String get connectTarget => resolvedHostname ?? alias;
}
