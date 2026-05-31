import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const H1CoreApp());
}

class H1CoreApp extends StatelessWidget {
  const H1CoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '販売アシスト1号 コア',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}
