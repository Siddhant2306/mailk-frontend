import 'package:flutter/material.dart';
import 'Screens/splash_screen.dart';

void main() {
  runApp(const MalikApp());
}

class MalikApp extends StatelessWidget {
  const MalikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MALIK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080808),
      ),
      home: const SplashScreen(),
    );
  }
}