// lib/main.dart

import 'package:flutter/material.dart';
import 'features/reading/verse_play_page.dart';

void main() {
  runApp(const BibleLoveApp());
}

class BibleLoveApp extends StatelessWidget {
  const BibleLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'bible_love',
      theme: ThemeData(
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const HomePage(),

        // ✅ FIX: verseId 파라미터 제거, VersePlayPage 새 생성자에 맞춤
        '/verse_play': (_) => const VersePlayPage(
              title: '1 Thessalonians 1:8 (NIV)',
              textEn:
                  "The Lord's message rang out from you not only in Macedonia and Achaia—your faith in God has become known everywhere.",
              textKo: '주님의 말씀이 ...', // 임시
              audioUrl:
                  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            ),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('bible_love')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.pushNamed(context, '/verse_play'),
          child: const Text('Open VersePlayPage'),
        ),
      ),
    );
  }
}
