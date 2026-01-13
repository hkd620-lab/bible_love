// lib/features/reading/chapter_reader_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChapterReaderPage extends StatelessWidget {
  static const routeName = '/chapter_reader';

  final String chapterId; // ex) prov_001
  const ChapterReaderPage({super.key, required this.chapterId});

  static const String kChapterCollection = 'bible_chapters';
  static const String kVersesSubcollection = 'verses';

  // archaicWord(modernWord) 패턴
  static final RegExp _archaicRe = RegExp(r'([A-Za-z]+)\(([^()]+)\)');

  List<InlineSpan> _buildEnSpans(BuildContext context, String en) {
    final spans = <InlineSpan>[];

    int last = 0;
    for (final m in _archaicRe.allMatches(en)) {
      // 앞의 일반 텍스트
      if (m.start > last) {
        spans.add(TextSpan(text: en.substring(last, m.start)));
      }

      final archaic = m.group(1) ?? '';
      final modern = m.group(2) ?? '';

      // archaic 강조 + modern은 작게 표시(괄호는 UI에서만)
      spans.add(
        TextSpan(
          text: archaic,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      spans.add(
        TextSpan(
          text: '($modern)',
          style: const TextStyle(fontSize: 12),
        ),
      );

      last = m.end;
    }

    if (last < en.length) {
      spans.add(TextSpan(text: en.substring(last)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final verseCol = FirebaseFirestore.instance
        .collection(kChapterCollection)
        .doc(chapterId)
        .collection(kVersesSubcollection);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter: $chapterId'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: verseCol.orderBy('verse').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No verses.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final v = (d['verse'] ?? '').toString();
              final en = (d['textEn'] ?? '').toString();
              final ko = (d['textKo'] ?? '').toString();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('V $v', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: _buildEnSpans(context, en),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(ko),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
