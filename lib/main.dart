// lib/main.dart
import 'package:flutter/material.dart';

import 'core/firebase/firebase_init.dart';
import 'features/dev/dev_parse_test_page.dart';
import 'features/reading/chapter_reader_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInit.init();
  runApp(const BibleLoveApp());
}

class BibleLoveApp extends StatelessWidget {
  const BibleLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bible_love',
      debugShowCheckedModeBanner: false,
      initialRoute: DevParseTestPage.routeName,
      routes: {
        DevParseTestPage.routeName: (_) => const DevParseTestPage(),
        // ⚠️ ChapterReaderPage는 required chapterId 때문에 routes에 두면 안 됨
      },
      onGenerateRoute: (settings) {
        if (settings.name == ChapterReaderPage.routeName) {
          final arg = settings.arguments;
          final chapterId = arg is String ? arg : 'prov_001'; // 안전 기본값
          return MaterialPageRoute(
            builder: (_) => ChapterReaderPage(chapterId: chapterId),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
