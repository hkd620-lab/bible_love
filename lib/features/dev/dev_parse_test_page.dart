import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/bible_text_parser.dart';

class DevParseTestPage extends StatefulWidget {
  static const routeName = '/dev_parse_test';

  const DevParseTestPage({super.key});

  @override
  State<DevParseTestPage> createState() => _DevParseTestPageState();
}

class _DevParseTestPageState extends State<DevParseTestPage> {
  final _controller = TextEditingController();
  String _log = '';
  bool _saving = false;

  // 충돌 방지: 기존 앱에서 chapters 컬렉션을 이미 쓰고 있다면
  // 아래 컬렉션명으로 분리하는 것이 안전합니다.
  static const String kChapterCollection = 'bible_chapters';
  static const String kVersesSubcollection = 'verses';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _append(String s) {
    setState(() => _log += '$s\n');
    debugPrint(s);
  }

  void _clear() {
    setState(() {
      _log = '';
      _controller.clear();
    });
  }

  void _fillSample() {
    const sample = '''
#BOOK=Proverbs|BOOKCODE=prov|CHAPTER=1|VERSION=KJV|LANGPAIR=EN-KO|ARCHAIC=INLINE_PARENS
T|EN=Proverbs 1|KO=잠언 1장
V|N=1|EN=The proverbs of Solomon the son of David, king of Israel;|KO=다윗의 아들 이스라엘 왕 솔로몬의 잠언이라.
V|N=2|EN=To know wisdom and instruction; to perceive the words of understanding;|KO=지혜와 훈계를 알게 하며 명철의 말씀을 깨닫게 하려는 것이라.
V|N=3|EN=To receive the instruction of wisdom, justice, and judgment, and equity;|KO=지혜의 훈계를 받아 의와 공평과 정직을 얻게 하려는 것이라.
''';
    setState(() {
      _controller.text = sample.trim();
      _log = 'Sample inserted.\n';
    });
  }

  dynamic _parseOrThrow() {
    final input = _controller.text;
    if (input.trim().isEmpty) {
      throw const FormatException('Input is empty.');
    }
    return BibleTextParser.parseChapter(input);
  }

  void _runParseTest() {
    setState(() => _log = '');
    try {
      final parsed = _parseOrThrow();

      _append('OK: header');
      _append('  BOOK=${parsed.header.book}');
      _append('  BOOKCODE=${parsed.header.bookCode}');
      _append('  CHAPTER=${parsed.header.chapter}');
      _append('  VERSION=${parsed.header.version}');
      _append('  LANGPAIR=${parsed.header.langPair}');
      _append('OK: title');
      _append('  EN=${parsed.titleEn}');
      _append('  KO=${parsed.titleKo}');
      _append('OK: verses=${parsed.verses.length}');

      if (parsed.verses.isNotEmpty) {
        final first = parsed.verses.first;
        final last = parsed.verses.last;
        _append(
          'first: N=${first.number} id=${BibleTextParser.verseId(bookCode: parsed.header.bookCode, chapter: parsed.header.chapter, verse: first.number)}',
        );
        _append(
          'last : N=${last.number} id=${BibleTextParser.verseId(bookCode: parsed.header.bookCode, chapter: parsed.header.chapter, verse: last.number)}',
        );
      }
    } catch (e, st) {
      _append('PARSE ERROR: $e');
      _append(st.toString());
    }
  }

  Future<void> _saveToFirestore() async {
    setState(() => _log = '');
    setState(() => _saving = true);

    try {
      final parsed = _parseOrThrow();
      final firestore = FirebaseFirestore.instance;

      final chapterId =
          '${parsed.header.bookCode}_${parsed.header.chapter.toString().padLeft(3, '0')}';
      final chapterRef =
          firestore.collection(kChapterCollection).doc(chapterId);

      final chapterData = <String, dynamic>{
        'id': chapterId,
        'book': parsed.header.book,
        'bookCode': parsed.header.bookCode,
        'chapter': parsed.header.chapter,
        'version': parsed.header.version, // KJV
        'langPair': parsed.header.langPair, // EN-KO
        'titleEn': parsed.titleEn,
        'titleKo': parsed.titleKo,
        'verseCount': parsed.verses.length,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Firestore batch limit is 500 operations.
      // 안전하게 450개 단위로 커밋 (여유 버퍼).
      const int maxOpsPerBatch = 450;

      WriteBatch batch = firestore.batch();
      int opCount = 0;
      int commits = 0;

      Future<void> commitBatch() async {
        await batch.commit();
        commits++;
        batch = firestore.batch();
        opCount = 0;
      }

      void addOp() {
        opCount++;
      }

      // 1) Chapter doc (1 op)
      batch.set(chapterRef, chapterData, SetOptions(merge: true));
      addOp();

      // 2) Verses subcollection
      final versesCol = chapterRef.collection(kVersesSubcollection);

      for (final v in parsed.verses) {
        // 배치가 꽉 차기 전에 먼저 커밋
        if (opCount >= maxOpsPerBatch) {
          await commitBatch();
        }

        final vid = BibleTextParser.verseId(
          bookCode: parsed.header.bookCode,
          chapter: parsed.header.chapter,
          verse: v.number,
        );

        final verseRef = versesCol.doc(vid);
        final verseData = <String, dynamic>{
          'id': vid,
          'n': v.number,
          'book': parsed.header.book,
          'bookCode': parsed.header.bookCode,
          'chapter': parsed.header.chapter,
          'version': parsed.header.version,
          'en': v.en,
          'ko': v.ko,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(verseRef, verseData, SetOptions(merge: true));
        addOp();
      }

      // 마지막 배치 커밋 (op가 있을 때만)
      if (opCount > 0) {
        await commitBatch();
      }

      _append('SAVE OK');
      _append('chapterId=$chapterId');
      _append('chapterPath=$kChapterCollection/$chapterId');
      _append(
          'versesPath=$kChapterCollection/$chapterId/$kVersesSubcollection/{verseId}');
      _append('versesSaved=${parsed.verses.length}');
      _append('commits=$commits');
    } catch (e, st) {
      _append('SAVE ERROR: $e');
      _append(st.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Parse Test (KJV+KO)'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _fillSample,
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Insert sample',
          ),
          IconButton(
            onPressed: _saving ? null : _clear,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Paste chapter text (# / T| / V| format)',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _runParseTest,
                    child: const Text('PARSE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveToFirestore,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('SAVE TO FIRESTORE'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log.isEmpty ? '(log)' : _log,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
