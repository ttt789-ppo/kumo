import 'dart:convert';

/// 一台 AdGuard Home 服务器的连接配置
class ServerConfig {
  String id;
  String name;
  /// http 或 https
  String scheme;
  String host;
  /// 例如 /agh（部署在子路径时填），留空表示根路径
  String path;
  int port;
  String user;
  String password;

  ServerConfig({
    required this.id,
    required this.name,
    this.scheme = 'http',
    required this.host,
    this.path = '',
    this.port = 3000,
    this.user = 'admin',
    this.password = '',
  });

  Uri get baseUri {
    final p = path.trim();
    final normalized = (p.isEmpty || p == '/')
        ? '/'
        : '/${p.replaceAll(RegExp(r'^/+|/+$'), '')}/';
    return Uri(scheme: scheme, host: host, port: port, path: normalized);
  }

  String get label => '$scheme://$host:$port${path.isEmpty ? '' : path}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'scheme': scheme,
        'host': host,
        'path': path,
        'port': port,
        'user': user,
        'password': password,
      };

  static ServerConfig fromJson(Map<String, dynamic> j) => ServerConfig(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        scheme: (j['scheme'] ?? 'http').toString(),
        host: (j['host'] ?? '').toString(),
        path: (j['path'] ?? '').toString(),
        port: int.tryParse('${j['port'] ?? 3000}') ?? 3000,
        user: (j['user'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
      );

  ServerConfig copy() => ServerConfig.fromJson(jsonDecode(jsonEncode(toJson())));
}

/// /control/status
class AghStatus {
  final bool running;
  final bool protectionEnabled;
  final String version;
  final List<String> dnsAddresses;
  final int dnsPort;
  final int httpPort;
  final String language;

  AghStatus({
    required this.running,
    required this.protectionEnabled,
    required this.version,
    required this.dnsAddresses,
    required this.dnsPort,
    required this.httpPort,
    required this.language,
  });

  factory AghStatus.fromJson(Map<String, dynamic> j) => AghStatus(
        running: j['running'] == true,
        protectionEnabled: j['protection_enabled'] == true,
        version: (j['version'] ?? '—').toString(),
        dnsAddresses: ((j['dns_addresses'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        dnsPort: int.tryParse('${j['dns_port'] ?? 53}') ?? 53,
        httpPort: int.tryParse('${j['http_port'] ?? 0}') ?? 0,
        language: (j['language'] ?? '').toString(),
      );
}

/// /control/stats（只取用得到的部分）
class AghStats {
  final int totalQueries;
  final int blocked;
  final double avgProcessingMs;
  final List<int> querySeries;
  final List<int> blockedSeries;
  final List<KeyValue> topClients;

  AghStats({
    required this.totalQueries,
    required this.blocked,
    required this.avgProcessingMs,
    required this.querySeries,
    required this.blockedSeries,
    required this.topClients,
  });

  int get sumQueries => querySeries.fold(0, (a, b) => a + b);
  int get sumBlocked => blockedSeries.fold(0, (a, b) => a + b);

  /// 统一成 0~24 个点，便于画图
  List<double> get normalizedQueries {
    final v = querySeries.map((e) => e.toDouble()).toList();
    return _resample(v, 24);
  }

  List<double> get normalizedBlocked {
    final v = blockedSeries.map((e) => e.toDouble()).toList();
    return _resample(v, 24);
  }

  static List<double> _resample(List<double> src, int n) {
    if (src.isEmpty) return List.filled(n, 0);
    if (src.length == n) return src;
    final out = <double>[];
    for (var i = 0; i < n; i++) {
      final pos = i * (src.length - 1) / (n - 1);
      final lo = pos.floor();
      final hi = pos.ceil();
      if (lo == hi) {
        out.add(src[lo]);
      } else {
        final t = pos - lo;
        out.add(src[lo] * (1 - t) + src[hi] * t);
      }
    }
    return out;
  }

  factory AghStats.fromJson(Map<String, dynamic> j) {
    int sum(List<dynamic>? l) =>
        (l ?? const []).fold<int>(0, (a, b) => a + (int.tryParse('$b') ?? 0));
    final q = ((j['dns_queries'] as List?) ?? const []).map((e) => int.tryParse('$e') ?? 0).toList();
    final b = ((j['blocked_filtering'] as List?) ?? const []).map((e) => int.tryParse('$e') ?? 0).toList();
    final top = <KeyValue>[];
    final tc = j['top_clients'];
    if (tc is List) {
      for (final e in tc) {
        if (e is Map && e['name'] != null) {
          top.add(KeyValue('${e['name']}', int.tryParse('${e['count']}') ?? 0));
        } else if (e is String) {
          top.add(KeyValue(e, 0));
        }
      }
    }
    return AghStats(
      totalQueries: sum(j['dns_queries'] as List?),
      blocked: sum(j['blocked_filtering'] as List?),
      avgProcessingMs: double.tryParse('${j['avg_processing_time'] ?? 0}') != null
          ? (double.tryParse('${j['avg_processing_time'] ?? 0}')! * 1000)
          : 0,
      querySeries: q,
      blockedSeries: b,
      topClients: top,
    );
  }
}

class KeyValue {
  final String name;
  final int count;
  KeyValue(this.name, this.count);
}

/// 过滤器订阅
class FilterEntry {
  final String url;
  final String name;
  final int rulesCount;
  bool enabled;
  final bool whitelist;
  final String lastUpdated;

  FilterEntry({
    required this.url,
    required this.name,
    required this.rulesCount,
    required this.enabled,
    this.whitelist = false,
    this.lastUpdated = '',
  });

  factory FilterEntry.fromJson(Map<String, dynamic> j, {bool whitelist = false}) => FilterEntry(
        url: (j['url'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        rulesCount: int.tryParse('${j['rules_count'] ?? 0}') ?? 0,
        enabled: j['enabled'] == true,
        whitelist: whitelist,
        lastUpdated: (j['last_updated'] ?? '').toString(),
      );
}

/// 查询日志条目
class QueryLogEntry {
  final String question;
  final String answer;
  final String client;
  final String status;
  final String time;
  final String upstream;
  final double elapsedMs;
  final List<String> rules;

  QueryLogEntry({
    required this.question,
    required this.answer,
    required this.client,
    required this.status,
    required this.time,
    required this.upstream,
    required this.elapsedMs,
    required this.rules,
  });

  bool get blocked => status.toUpperCase().contains('BLOCK') ||
      status.toUpperCase().contains('FILTERED') ||
      status.toUpperCase().contains('SAFE');

  factory QueryLogEntry.fromJson(Map<String, dynamic> j) {
    final q = j['question'];
    String question = '';
    if (q is Map) question = (q['name'] ?? '').toString();
    final ans = j['answer'];
    String answer = '';
    if (ans is Map) {
      final v = ans['value'];
      if (v is String) {
        answer = v;
      } else if (v is List) {
        answer = v.map((e) => e is Map ? (e['value'] ?? '').toString() : '$e').join(', ');
      }
    }
    final client = j['client'];
    String clientStr = '';
    if (client is Map) {
      clientStr = (client['name'] ?? client['IP'] ?? client['ip'] ?? '').toString();
      if (clientStr.isEmpty) clientStr = (client['ids'] ?? '').toString();
    } else if (client is String) {
      clientStr = client;
    }
    final rules = <String>[];
    final r = j['rules'];
    if (r is List) {
      for (final e in r) {
        if (e is Map && e['text'] != null) rules.add('${e['text']}');
      }
    }
    return QueryLogEntry(
      question: question,
      answer: answer,
      client: clientStr.isEmpty ? '—' : clientStr,
      status: (j['status'] ?? '').toString(),
      time: (j['time'] ?? '').toString(),
      upstream: (j['upstream'] ?? '').toString(),
      elapsedMs: (double.tryParse('${j['elapsedMs'] ?? 0}') ?? 0),
      rules: rules,
    );
  }
}

/// /control/clients 里的条目
class ClientEntry {
  final String name;
  final String ids;
  final bool blocked;
  final bool persistent;
  final bool auto;

  ClientEntry({
    required this.name,
    required this.ids,
    required this.blocked,
    required this.persistent,
    this.auto = false,
  });

  factory ClientEntry.fromJson(Map<String, dynamic> j, {bool auto = false}) => ClientEntry(
        name: (j['name'] ?? '(未命名)').toString(),
        ids: ((j['ids'] as List?) ?? const []).map((e) => '$e').join('，'),
        blocked: (j['blocked_services'] as List?)?.isNotEmpty == true,
        persistent: j['ids'] != null,
        auto: auto,
      );
}

/// /control/rewrite/list
class DnsRewrite {
  final String domain;
  final String answer;
  DnsRewrite(this.domain, this.answer);
  factory DnsRewrite.fromJson(Map<String, dynamic> j) =>
      DnsRewrite((j['domain'] ?? '').toString(), (j['answer'] ?? '').toString());
}
