import 'package:flutter/material.dart';

const forest = Color(0xFF205C45);
const leaf = Color(0xFF4D8B62);
const pale = Color(0xFFE8F2E8);
const background = Color(0xFFF5F7F3);
const ink = Color(0xFF20332A);
const muted = Color(0xFF66756D);
const border = Color(0xFFE2E8E2);
const warnBg = Color(0xFFFFF4DB);
const warnBorder = Color(0xFFEBD49B);
const warnInk = Color(0xFF6D4E10);

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: pale,
      ),
    );
