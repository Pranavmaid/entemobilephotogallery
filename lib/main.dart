import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/gallery_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 400
    ..maximumSizeBytes = 320 << 20;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0A0A0A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const EnteGalleryApp());
}

class EnteGalleryApp extends StatelessWidget {
  const EnteGalleryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ente Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0A0A0A),
          primary: Color(0xFF7DDCC9),
          secondary: Color(0xFF7DDCC9),
        ),
        textTheme: const TextTheme()
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const GalleryPage(),
    );
  }
}
