import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChapterReaderPage extends StatelessWidget {
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
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Tooltip(
              message: modern, // 마우스 올리면 modern만 뜸 (macOS에서 특히 유용)
              child: Text(
                '($modern)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontSize: 11,
                    ),
              ),
            ),
          ),
        ),
      );

      last = m.end;
    }

    // 뒤의 일반 텍스트
    if (last < en.length) {
      spans.add(TextSpan(text: en.substring(last)));
    }

    // 매치가 하나도 없으면 plain
    if (spans.isEmpty) return [TextSpan(text: en)];
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final chapterRef =
        FirebaseFirestore.instance.collection(kChapterCollection).doc(chapterId);
    final versesQuery = chapterRef
        .collection(kVersesSubcollection)
        .orderBy('n', descending: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reader: $chapterId'),
      ),
      body: Column(
        children: [
          // (A) Chapter meta
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: chapterRef.get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('META ERROR: ${snap.error}'),
                );
              }
              final data = snap.data?.data();
              if (data == null) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('META: not found'),
                );
              }

              final titleKo = (data['titleKo'] ?? '').toString();
              final titleEn = (data['titleEn'] ?? '').toString();
              final verseCount = (data['verseCount'] ?? 0).toString();

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleKo,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(titleEn,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('verses: $verseCount',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Divider(height: 18),
                  ],
                ),
              );
            },
          ),

          // (B) Verses list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: versesQuery.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('VERSES ERROR: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No verses.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 18),
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final n = (m['n'] ?? 0).toString();
                    final en = (m['en'] ?? '').toString();
                    final ko = (m['ko'] ?? '').toString();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),

                        // ✅ EN: archaicWord(modernWord) 강조 표시
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: _buildEnSpans(context, en),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // KO
                        Text(
                          ko,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
