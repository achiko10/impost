import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/client_shell.dart';
import 'screens/inspector_shell.dart';
import 'screens/manager_operations_tabs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: const ImpostiApp(),
    ),
  );
}

class ImpostiApp extends StatelessWidget {
  const ImpostiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMPOSTI Maintenance System',
      debugShowCheckedModeBanner: false,
      theme: buildImpostiTheme(),
      home: const RootRouter(),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = appState.currentUser;
    if (user == null) {
      return const AuthScreen();
    }

    switch (user.role) {
      case 'manager':
        return const ManagerShell();
      case 'inspector':
        return const InspectorShell();
      case 'client':
      default:
        return const ClientShell();
    }
  }
}
