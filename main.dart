import 'package:flutter/material.dart';
import 'storage.dart';
import 'notification_service.dart';
import 'screens/plan_screen.dart';
import 'screens/subjects_screen.dart';
import 'screens/alarms_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  await NotificationService.init();
  runApp(const BcsPlannerApp());
}

class BcsPlannerApp extends StatelessWidget {
  const BcsPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0F1E33);
    const gold = Color(0xFFB8863B);
    return MaterialApp(
      title: 'BCS Prep Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          primary: ink,
          secondary: gold,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F3EC),
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _screens = const [
    PlanScreen(),
    SubjectsScreen(),
    AlarmsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.alarm), label: 'Alarms'),
        ],
      ),
    );
  }
}
