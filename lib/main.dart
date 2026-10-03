import 'package:flutter/material.dart';

import 'data/local_repository.dart';
import 'data/settings.dart';
import 'pages/body_page.dart';
import 'pages/history_page.dart';
import 'pages/me_page.dart';
import 'pages/plans_page.dart';
import 'pages/today_page.dart';
import 'scope.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings();
  await settings.load();
  final repo = SqfliteRepository();
  runApp(FitnessApp(repo: repo, settings: settings));
}

class FitnessApp extends StatelessWidget {
  final SqfliteRepository repo;
  final Settings settings;

  const FitnessApp({super.key, required this.repo, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      settings: settings,
      child: MaterialApp(
        title: '训练台',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        themeMode: ThemeMode.light,
        home: const AppShell(),
      ),
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

  static const _pages = [
    TodayPage(),
    PlansPage(),
    HistoryPage(),
    BodyPage(),
    MePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: '计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.straighten_outlined),
            selectedIcon: Icon(Icons.straighten_rounded),
            label: '身体',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
