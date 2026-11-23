import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class AghException implements Exception {
  final String message;
  final int? statusCode;
  AghException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// AdGuard Home HTTP API 客户端
///
/// 全部请求走 Basic Auth（与官方 Web 面板一致），不依赖会话 Cookie，
/// 因此不会出现「首页能刷、别的页面 401」这种会话不同步问题。
class AghClient {
  final Uri base;
  final String? _authorization;
  final http.Client _http;
  static const _timeout = Duration(seconds: 20);

  AghClient({
    required this.base,
    String? user,
    String? password,
    http.Client? client,
  })  : _authorization = (user == null || user.isEmpty)
            ? null
            : 'Basic ${base64Encode(utf8.encode('$user:${password ?? ''}'))}',
        _http = client ?? http.Client();

  factory AghClient.fromConfig(ServerConfig c) =>
      AghClient(base: c.baseUri, user: c.user, password: c.password);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_authorization != null) 'Authorization': _authorization!,
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '$p$path',
      queryParameters: query?.isEmpty == true ? null : query,
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() run, String what) async {
    http.Response resp;
    try {
      resp = await run().timeout(_timeout);
    } on TimeoutException {
      throw AghException('$what 超时（20 秒），检查地址与端口');
    } on http.ClientException catch (e) {
      throw AghException('$what 连接失败：${e.message}');
    } catch (e) {
      throw AghException('$what 请求异常：$e');
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw AghException('认证失败（HTTP ${resp.statusCode}），用户名或密码不对', resp.statusCode);
    }
    if (resp.statusCode >= 400) {
      throw AghException('$what 返回 HTTP ${resp.statusCode}', resp.statusCode);
    }
    if (resp.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send(() => _http.get(_uri(path, query), headers: _headers), 'GET $path');

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(
        () => _http.post(
          _uri(path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body ?? const {}),
        ),
        'POST $path',
      );

  // ---------- 状态 ----------

  Future<AghStatus> status() async {
    final j = await get('/control/status');
    return AghStatus.fromJson((j as Map).cast<String, dynamic>());
  }

  Future<AghStats> stats() async {
    final j = await get('/control/stats');
    return AghStats.fromJson((j as Map).cast<String, dynamic>());
  }

  Future<bool> setProtection(bool enabled) async {
    final r = await post('/control/protection', {'enabled': enabled});
    if (r is Map && r['protection_enabled'] is bool) return r['protection_enabled'] as bool;
    return enabled;
  }

  /// 用于「测试连接」：能拿到 status 就算通过
  Future<AghStatus> ping() => status();

  // ---------- DNS 配置 ----------

  Future<Map<String, dynamic>> dnsInfo() async {
    final j = await get('/control/dns_info');
    return (j as Map).cast<String, dynamic>();
  }

  Future<List<String>> upstreams() async {
    final j = await dnsInfo();
    return ((j['upstream_dns'] as List?) ?? const []).map((e) => '$e').toList();
  }

  // ---------- 过滤器 ----------

  Future<({List<FilterEntry> filters, List<FilterEntry> whitelist, List<String> userRules, int interval})>
      filteringStatus() async {
    final j = (await get('/control/filtering/status') as Map).cast<String, dynamic>();
    final filters = ((j['filters'] as List?) ?? const [])
        .map((e) => FilterEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final white = ((j['whitelist_filters'] as List?) ?? const [])
        .map((e) => FilterEntry.fromJson((e as Map).cast<String, dynamic>(), whitelist: true))
        .toList();
    final rules = ((j['user_rules'] as List?) ?? const []).map((e) => '$e').toList();
    return (
      filters: filters,
      whitelist: white,
      userRules: rules,
      interval: int.tryParse('${j['interval'] ?? 24}') ?? 24,
    );
  }

  Future<void> setFilterEnabled(FilterEntry f, bool enabled) => post('/control/filtering/set_url', {
        'url': f.url,
        'whitelist': f.whitelist,
        'data': {'name': f.name, 'url': f.url, 'enabled': enabled},
      });

  Future<void> addFilter(String url, String name, {bool whitelist = false}) =>
      post('/control/filtering/add_url', {'url': url, 'name': name, 'whitelist': whitelist});

  Future<void> removeFilter(FilterEntry f) =>
      post('/control/filtering/remove_url', {'url': f.url, 'whitelist': f.whitelist});

  Future<void> setUserRules(List<String> rules) =>
      post('/control/filtering/set_rules', {'rules': rules});

  Future<void> refreshFilters() => post('/control/filtering/refresh', {'whitelist': false});

  Future<void> setFilteringEnabled(bool enabled) =>
      post('/control/filtering/config', {'enabled': enabled, 'interval': 24});

  // ---------- 查询日志 ----------

  /// piece 结构在不同版本间有差异，两种都兼容
  Future<List<QueryLogEntry>> queryLog({int limit = 100, String search = ''}) async {
    final raw = await get('/control/querylog', {
      'limit': '$limit',
      'search': search,
      if (search.isEmpty) 'response_status': 'all',
    });
    List<dynamic> list = const [];
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      }
    } else if (raw is List) {
      list = raw;
    }
    return list
        .whereType<Map>()
        .map((e) => QueryLogEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> clearQueryLog() => post('/control/querylog_clear');

  // ---------- 客户端 ----------

  Future<List<ClientEntry>> clients() async {
    final j = (await get('/control/clients') as Map).cast<String, dynamic>();
    final out = <ClientEntry>[];
    for (final e in (j['clients'] as List?) ?? const []) {
      if (e is Map) out.add(ClientEntry.fromJson(e.cast<String, dynamic>()));
    }
    for (final e in (j['auto_clients'] as List?) ?? const []) {
      if (e is Map) out.add(ClientEntry.fromJson(e.cast<String, dynamic>(), auto: true));
    }
    return out;
  }

  // ---------- DNS 重写 ----------

  Future<List<DnsRewrite>> rewrites() async {
    final j = await get('/control/rewrite/list');
    if (j is! List) return const [];
    return j.whereType<Map>().map((e) => DnsRewrite.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<void> addRewrite(String domain, String answer) =>
      post('/control/rewrite/add', {'domain': domain, 'answer': answer});

  Future<void> deleteRewrite(DnsRewrite r) =>
      post('/control/rewrite/delete', {'domain': r.domain, 'answer': r.answer});

  // ---------- 其他开关 ----------

  Future<bool> safebrowsingStatus() async {
    final j = await get('/control/safebrowsing/status');
    return j is Map && j['enabled'] == true;
  }

  Future<void> setSafebrowsing(bool enabled) =>
      post(enabled ? '/control/safebrowsing/enable' : '/control/safebrowsing/disable');

  Future<bool> parentalStatus() async {
    final j = await get('/control/parental/status');
    return j is Map && j['enabled'] == true;
  }

  Future<bool> safeSearchStatus() async {
    final j = await get('/control/safesearch/status');
    return j is Map && j['enabled'] == true;
  }

  void close() => _http.close();
}
