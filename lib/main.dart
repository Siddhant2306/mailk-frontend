import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme_controller.dart';
import 'core/theme/app_palette.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090D13),
      systemNavigationBarDividerColor: Color(0xFF202832),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const MalikApp());
}

class MalikApp extends StatelessWidget {
  const MalikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final isDark = appThemeController.themeMode == ThemeMode.dark;
        final systemUiStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark
              ? const Color(0xFF090D13)
              : const Color(0xFFF5F6F8),
          systemNavigationBarDividerColor: isDark
              ? const Color(0xFF202832)
              : const Color(0xFFDDE1E6),
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        );

        return MaterialApp(
          title: 'MALIK',
          debugShowCheckedModeBanner: false,
          themeMode: appThemeController.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFB21A),
              brightness: Brightness.light,
              surface: AppPalette.light.surface,
            ),
            scaffoldBackgroundColor: AppPalette.light.background,
            extensions: const [AppPalette.light],
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: Color(0xFFFFB21A),
              surface: AppPalette.dark.surface,
            ),
            scaffoldBackgroundColor: AppPalette.dark.background,
            extensions: const [AppPalette.dark],
            useMaterial3: true,
          ),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: systemUiStyle,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
