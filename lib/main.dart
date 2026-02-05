import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_screen.dart';

import 'package:media_store_plus/media_store_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediaStore.ensureInitialized();
  MediaStore.appFolder = 'DownloadVideos_App';

  runApp(
    const ProviderScope(
      child: DownloadVideosApp(),
    ),
  );
}

class DownloadVideosApp extends StatelessWidget {
  const DownloadVideosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurpleAccent,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'YouTube Downloader',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05050A),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF05050A),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: colorScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF12121A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.primary.withOpacity(0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 1.5,
            ),
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

