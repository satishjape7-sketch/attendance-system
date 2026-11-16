import 'package:flutter/material.dart';
import 'app_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/account_screen.dart';
import '../features/attendance/today_screen.dart';
import '../features/attendance/history_screen.dart';
import '../features/users/users_screen.dart';
import '../shared/widgets.dart';

class AttendanceApp extends StatelessWidget {
  final AppController controller;
  const AttendanceApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller, builder: (context, _) => MaterialApp(
      title: 'Attend', debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245C48)),
        scaffoldBackgroundColor: const Color(0xFFF6F8F5),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
      home: controller.initializing
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : controller.startupError != null
          ? Scaffold(body: ErrorPanel(retry: controller.initialize, message: controller.startupError!))
          : controller.user == null ? LoginScreen(controller: controller)
          : HomeScreen(key: ValueKey(controller.user!.id), controller: controller),
    ));
}
class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final admin = widget.controller.user!.isAdmin;
    final pages = <Widget>[
      TodayScreen(controller: widget.controller),
      HistoryScreen(controller: widget.controller),
      if (admin) HistoryScreen(controller: widget.controller, report: true, key: const ValueKey('report')),
      if (admin) UsersScreen(controller: widget.controller),
      AccountScreen(controller: widget.controller),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Attend'),
        actions: [Padding(padding: const EdgeInsets.all(16), child: Text(admin ? 'ADMIN' : 'EMPLOYEE'))]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900), child: pages[_index]))),
      bottomNavigationBar: NavigationBar(selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Today'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          if (admin) const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
          if (admin) const NavigationDestination(icon: Icon(Icons.people_outline), label: 'Team'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ]),
    );
  }
}
