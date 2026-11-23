import 'package:flutter/material.dart';

import '../../agh/agh_client.dart';
import '../../agh/models.dart';
import '../../main.dart';
import '../widgets.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _search = TextEditingController();
  List<QueryLogEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  bool _onlyBlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await appState.api.queryLog(limit: 200, search: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _entries = _onlyBlocked ? list.where((e) => e.blocked).toList() : list;
        _loading = false;
      });
    } on AghException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
            child: KsuHeader(
              title: '日志',
              actions: [
                IconButton(
                  onPressed: () => setState(() => _onlyBlocked = !_onlyBlocked),
                  icon: Icon(_onlyBlocked ? Icons.filter_alt : Icons.filter_alt_outlined),
                  tooltip: '只看被拦截',
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: '搜索域名、客户端',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: _error != null
                ? EmptyBox(_error!, icon: Icons.error_outline)
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? const EmptyBox('没有查询记录')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final e = _entries[i];
                                return KsuCard(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 3),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: (e.blocked ? scheme.error : scheme.primary)
                                              .withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          e.blocked ? Icons.block : Icons.check,
                                          size: 16,
                                          color: e.blocked ? scheme.error : scheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.question.isEmpty ? '（无域名）' : e.question,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${e.client} · ${e.status.isEmpty ? '—' : e.status}'
                                              '${e.elapsedMs > 0 ? ' · ${e.elapsedMs.toStringAsFixed(1)}ms' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                            if (e.answer.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 3),
                                                child: Text(
                                                  e.answer,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: scheme.onSurfaceVariant.withOpacity(0.8),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _time(e.time),
                                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _time(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }
}
