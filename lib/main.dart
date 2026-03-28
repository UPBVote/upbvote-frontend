import 'dart:ui';
import 'package:flutter/material.dart';
import 'ui/screens/login_screen.dart';

void main() {
  // 1) Errores dentro de callbacks de Flutter (build, layout, paint)
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('_dependents.isEmpty')) return;
    FlutterError.presentError(details);
  };
  // 2) Errores durante la fase build — reemplaza la pantalla roja
  ErrorWidget.builder = (details) {
    if (details.exceptionAsString().contains('_dependents.isEmpty')) {
      return const SizedBox.shrink();
    }
    return ErrorWidget(details.exception);
  };
  // 3) Errores fuera de los callbacks de Flutter (zona Dart)
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('_dependents.isEmpty')) return true;
    return false;
  };
  runApp(const UPBVoteApp());
}

class UPBVoteApp extends StatelessWidget {
  const UPBVoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UPBVote',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFB71C1C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          primary: const Color(0xFFB71C1C),
          secondary: const Color(0xFF263238),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          elevation: 14,
          backgroundColor: Colors.white,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
