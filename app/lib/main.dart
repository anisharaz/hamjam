import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/home_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Palette.bgBottom,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const HamJamApp());
}

class HamJamApp extends StatelessWidget {
  const HamJamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HamJam',
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        theme: buildTheme(),
        home: const HomePage(),
      );
}
