import 'package:flutter/material.dart';

import 'store/app_state.dart';
import 'ui/pages/clients_page.dart';
import 'ui/pages/filters_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/logs_page.dart';
import 'ui/pages/servers_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/theme.dart';

/// 全局状态，页面里直接引用
final appState = AppState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.init();
  runApp(const KumoApp());
}

class KumoApp extends StatelessWidget {
  const KumoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kumo',
      debugShowCheckedModeBanner: false,
      theme: KumoTheme.light(),
      darkTheme: KumoTheme.dark(),
      themeMode: ThemeMode.system,
      home: const RootGate(),
    );
  }
}

/// 没连服务器就进连接页，连上了进主框架
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: appState.connected ? const AppShell() : const ServersPage(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    LogsPage(),
    FiltersPage(),
    ClientsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '主页'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '日志'),
          NavigationDestination(icon: Icon(Icons.filter_alt_outlined), selectedIcon: Icon(Icons.filter_alt), label: '过滤器'),
          NavigationDestination(icon: Icon(Icons.devices_other_outlined), selectedIcon: Icon(Icons.devices_other), label: '客户端'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
