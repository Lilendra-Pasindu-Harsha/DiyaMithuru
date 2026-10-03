import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const DiyaMithuruApp());

class DiyaMithuruApp extends StatelessWidget {
  const DiyaMithuruApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E9BF0);
    return MaterialApp(
      title: 'DiyaMithuru',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
