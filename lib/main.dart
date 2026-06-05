// =============================================================================
// Uellow Reviewers — standalone specialists companion app (v1.0.0).
// =============================================================================
import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'fcm_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

const kDark = Color(0xFF1D2733);     // reviewers navy (distinct identity)
const kAccent = Color(0xFF34495E);
const kGold = Color(0xFFF5C320);
const kGoldLight = Color(0xFFFFD75E);
const kBg = Color(0xFFF2F5F8);
const kGreen = Color(0xFF1F8A40);
const kRed = Color(0xFFC0392B);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RevApi.instance.init();
  unawaited(FcmService.instance.init());
  runApp(const ReviewersApp());
}

class ReviewersApp extends StatefulWidget {
  const ReviewersApp({super.key});
  static _ReviewersAppState? of(BuildContext c) =>
      c.findAncestorStateOfType<_ReviewersAppState>();
  @override
  State<ReviewersApp> createState() => _ReviewersAppState();
}

class _ReviewersAppState extends State<ReviewersApp> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    return MaterialApp(
      title: 'Uellow Reviewers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
            seedColor: kGold, primary: kDark, secondary: kGold),
        appBarTheme: const AppBarTheme(
          backgroundColor: kDark, foregroundColor: kGoldLight,
          elevation: 0, centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGold, foregroundColor: kDark,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.w900),
          ),
        ),
      ),
      builder: (c, child) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: RevApi.instance.signedIn
          ? const HomeScreen() : const LoginScreen(),
    );
  }
}
