import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'screens/player_screen.dart';
import 'services/font_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version;
  final appTitle = 'SubStitcher $version';
    
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = WindowOptions(
      title: appTitle,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle(appTitle);
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  await CustomFontLoader.loadFonts();
  
  runApp(MyApp(title: appTitle));
}

class MyApp extends StatelessWidget {
  final String title;
  
  const MyApp({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF2A2A2A),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          contentTextStyle: TextStyle(color: Colors.white),
          actionTextColor: Colors.lightBlue,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
          waitDuration: const Duration(milliseconds: 500),
        ),
      ),
      home: const PlayerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}