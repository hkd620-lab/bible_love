// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'features/dev/dev_parse_test_page.dart';
import 'features/reading/chapter_reader_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BibleLoveApp());
}

class BibleLoveApp extends StatelessWidget {
  const BibleLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bible_love',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const _HomePage(),
      routes: {
        DevParseTestPageRoute.path: (_) => const DevParseTestPage(),
      },
      onGenerateRoute: (settings) {
        // Reader route: /reader?chapterId=prov_001
        if (settings.name == ChapterReaderRoute.path) {
          final args = settings.arguments;
          final chapterId = (args is String && args.trim().isNotEmpty)
              ? args.trim()
              : 'prov_001';
          return MaterialPageRoute(
            builder: (_) => ChapterReaderPage(chapterId: chapterId),
          );
        }
        return null;
      },
    );
  }
}

/// Route constants (실수 방지용)
class DevParseTestPageRoute {
  static const String path = '/dev/parse';
}

class ChapterReaderRoute {
  static const String path = '/reader';
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _chapterIdController = TextEditingController(text: 'prov_001');

  @override
  void dispose() {
    _chapterIdController.dispose();
    super.dispose();
  }

  void _openDevParse() {
    Navigator.of(context).pushNamed(DevParseTestPageRoute.path);
  }

  void _openReader() {
    final id = _chapterIdController.text.trim();
    Navigator.of(context).pushNamed(
      ChapterReaderRoute.path,
      arguments: id.isEmpty ? 'prov_001' : id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('bible_love (dev home)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dev Tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _openDevParse,
              child: const Text('Open Dev Parse Test (KJV+KO)'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Reader',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chapterIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'chapterId (ex: prov_001)',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _openReader,
              child: const Text('Open Chapter Reader'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tip: 먼저 Dev Parse Test에서 SAVE OK 확인 후, Reader로 prov_001을 열면 바로 보입니다.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
