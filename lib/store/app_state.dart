import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../agh/agh_client.dart';
import '../agh/models.dart';

/// 服务器列表 + 当前连接，全局单例用 AppState 暴露
class ServerStore extends ChangeNotifier {
  static const _keyServers = 'kumo.servers';
  static const _keyActive = 'kumo.active';

  final List<ServerConfig> servers = [];
  String? activeId;
  AghClient? client;

  bool get hasActive => client != null;
  ServerConfig? get active {
    for (final s in servers) {
      if (s.id == activeId) return s;
    }
    return null;
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_keyServers);
    servers.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            if (e is Map) servers.add(ServerConfig.fromJson(e.cast<String, dynamic>()));
          }
        }
      } catch (_) {}
    }
    activeId = sp.getString(_keyActive);
    final a = active;
    if (a != null) client = AghClient.fromConfig(a);
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyServers, jsonEncode(servers.map((e) => e.toJson()).toList()));
    if (activeId != null) {
      await sp.setString(_keyActive, activeId!);
    } else {
      await sp.remove(_keyActive);
    }
  }

  Future<void> upsert(ServerConfig cfg) async {
    final i = servers.indexWhere((e) => e.id == cfg.id);
    if (i >= 0) {
      servers[i] = cfg;
    } else {
      servers.add(cfg);
    }
    if (activeId == null) activeId = cfg.id;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(ServerConfig cfg) async {
    servers.removeWhere((e) => e.id == cfg.id);
    if (activeId == cfg.id) {
      activeId = servers.isEmpty ? null : servers.first.id;
      client = active == null ? null : AghClient.fromConfig(active!);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActive(ServerConfig cfg) async {
    activeId = cfg.id;
    client = AghClient.fromConfig(cfg);
    await _persist();
    notifyListeners();
  }

  Future<void> disconnect() async {
    activeId = null;
    client = null;
    await _persist();
    notifyListeners();
  }
}

/// 全局状态：服务器列表 + 轻量刷新信号
class AppState extends ChangeNotifier {
  final ServerStore store = ServerStore();
  int _tick = 0;
  int get tick => _tick;

  Future<void> init() => store.load();

  void bump() {
    _tick++;
    notifyListeners();
  }

  AghClient get api {
    final c = store.client;
    if (c == null) throw AghException('还没有连接服务器');
    return c;
  }

  bool get connected => store.client != null;
}
