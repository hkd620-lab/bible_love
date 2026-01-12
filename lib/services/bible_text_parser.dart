// lib/services/bible_text_parser.dart
//
// Strict, deterministic parser + validator for the “Bible Text Fetcher” format:
//
// #BOOK=...|BOOKCODE=...|CHAPTER=...|VERSION=KJV|LANGPAIR=EN-KO|ARCHAIC=INLINE_PARENS
// T|EN=...|KO=...
// V|N=1|EN=...|KO=...
// V|N=2|EN=...|KO=...
//
// - No blank lines
// - One record per line
// - Enforces strict keys and ordering
// - Enforces BOOKCODE standard (optional expectedBookCode)
// - Enforces archaic gloss rule: archaicToken(modern) when archaicToken appears in EN
//
// NOTE: Adjust verseId() format to match your app’s existing convention if needed.

import 'dart:core';

class ChapterHeader {
  final String book;
  final String bookCode;
  final int chapter;
  final String version;
  final String langPair;
  final String archaicMode;

  const ChapterHeader({
    required this.book,
    required this.bookCode,
    required this.chapter,
    required this.version,
    required this.langPair,
    required this.archaicMode,
  });

  @override
  String toString() {
    return '#BOOK=$book|BOOKCODE=$bookCode|CHAPTER=$chapter|VERSION=$version|LANGPAIR=$langPair|ARCHAIC=$archaicMode';
  }
}

class VerseLine {
  final int number;
  final String en;
  final String ko;

  const VerseLine({
    required this.number,
    required this.en,
    required this.ko,
  });

  @override
  String toString() => 'V|N=$number|EN=$en|KO=$ko';
}

class ParsedChapter {
  final ChapterHeader header;
  final String titleEn;
  final String titleKo;
  final List<VerseLine> verses;

  const ParsedChapter({
    required this.header,
    required this.titleEn,
    required this.titleKo,
    required this.verses,
  });
}

class BibleTextParser {
  /// Project-wide archaic -> modern gloss mapping.
  /// Extend as you encounter more KJV archaic forms.
  static const Map<String, String> archaicGloss = {
    'thee': 'you',
    'thou': 'you',
    'thy': 'your',
    'thine': 'yours',
    'ye': 'you',
    'unto': 'to',
    'hath': 'has',
    'dost': 'do',
    'shalt': 'will',
    'cometh': 'comes',
    'endureth': 'endures',
    'taketh': 'takes',
    'crieth': 'cries',
    'uttereth': 'utters',
    'hearkeneth': 'hears',
  };

  /// Parse + validate an entire chapter text.
  ///
  /// strict:
  /// - true: throws FormatException on any violation.
  /// - false: still parses, but skips some strict checks (NOT recommended for production).
  ///
  /// expectedBookCode:
  /// - if provided, BOOKCODE must match exactly (e.g., "prov").
  static ParsedChapter parseChapter(
    String raw, {
    bool strict = true,
    String? expectedBookCode,
  }) {
    final lines = _normalizeLines(raw);

    if (lines.isEmpty) {
      throw const FormatException('Empty input.');
    }
    if (lines.any((l) => l.trim().isEmpty)) {
      throw const FormatException('Blank lines are not allowed.');
    }

    // (1) Header
    final headerLine = lines.first;
    final header = _parseHeader(headerLine, strict: strict, expectedBookCode: expectedBookCode);

    // (2) Title
    if (lines.length < 2) {
      throw const FormatException('Missing title line.');
    }
    final titleLine = lines[1];
    final title = _parseTitle(titleLine, strict: strict);

    // (3) Verses
    if (lines.length < 3) {
      throw const FormatException('Missing verse lines.');
    }
    final verseLines = lines.sublist(2);
    final verses = _parseVerses(verseLines, strict: strict);

    // Additional strict validation: archaic gloss in EN
    if (strict) {
      for (final v in verses) {
        validateArchaicUsage(v.en, v.number);
      }
    }

    return ParsedChapter(
      header: header,
      titleEn: title.$1,
      titleKo: title.$2,
      verses: verses,
    );
  }

  /// Validate archaic usage in one EN verse line.
  /// Rule:
  /// - If an archaic token appears, it must be written as token(modern) with NO spaces.
  /// - Duplicate gloss like you(you) or thou(thou) is forbidden.
  static void validateArchaicUsage(String enText, int verseNumber) {
    // Reject duplicate gloss like word(word)
    final dup = RegExp(r'\b([A-Za-z]+)\(\1\)');
    if (dup.hasMatch(enText)) {
      throw FormatException('Duplicate gloss detected at verse $verseNumber.');
    }

    for (final entry in archaicGloss.entries) {
      final token = entry.key;
      final modern = entry.value;

      // Any occurrence of token that is NOT immediately followed by "(modern)" is invalid.
      //
      // We allow punctuation after the closing paren (e.g., ye(you),)
      // But we do NOT allow token followed by "(wrong)" or token without parentheses.
      final unglossed = RegExp(r'\b' + RegExp.escape(token) + r'\b(?!\(' + RegExp.escape(modern) + r'\))');
      if (unglossed.hasMatch(enText)) {
        throw FormatException('Archaic token "$token" missing required "($modern)" at verse $verseNumber.');
      }

      // Additionally, if token(modern) appears, ensure there is NO space like "token (modern)".
      final spaced = RegExp(r'\b' + RegExp.escape(token) + r'\s+\(');
      if (spaced.hasMatch(enText)) {
        throw FormatException('Whitespace before archaic gloss is not allowed at verse $verseNumber.');
      }
    }
  }

  /// VerseId helper (adjust if your app uses a different convention).
  static String verseId({
    required String bookCode,
    required int chapter,
    required int verse,
  }) {
    // Stable, sortable id: prov_001_001
    final c = chapter.toString().padLeft(3, '0');
    final v = verse.toString().padLeft(3, '0');
    return '${bookCode.toLowerCase()}_$c\_$v';
  }

  // ----------------------------
  // Internal parsing helpers
  // ----------------------------

  static List<String> _normalizeLines(String raw) {
    // Normalize CRLF -> LF and trim only the outermost whitespace.
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return const [];
    return text.split('\n');
  }

  static ChapterHeader _parseHeader(
    String line, {
    required bool strict,
    String? expectedBookCode,
  }) {
    if (!line.startsWith('#')) {
      throw const FormatException('Header must start with "#".');
    }
    if (strict && line.contains(' ')) {
      throw const FormatException('Header must not contain spaces.');
    }

    final body = line.substring(1);
    final parts = body.split('|');
    final map = <String, String>{};

    for (final p in parts) {
      final idx = p.indexOf('=');
      if (idx <= 0 || idx == p.length - 1) {
        throw FormatException('Invalid header token "$p". Expected KEY=VALUE.');
      }
      final k = p.substring(0, idx);
      final v = p.substring(idx + 1);
      map[k] = v;
    }

    const requiredKeys = ['BOOK', 'BOOKCODE', 'CHAPTER', 'VERSION', 'LANGPAIR', 'ARCHAIC'];
    for (final k in requiredKeys) {
      if (!map.containsKey(k)) {
        throw FormatException('Header missing required key: $k');
      }
    }
    if (strict && map.keys.length != requiredKeys.length) {
      throw FormatException('Header contains extra keys: ${map.keys.where((k) => !requiredKeys.contains(k)).toList()}');
    }

    final book = map['BOOK']!;
    final bookCode = map['BOOKCODE']!;
    final chapterStr = map['CHAPTER']!;
    final version = map['VERSION']!;
    final langPair = map['LANGPAIR']!;
    final archaicMode = map['ARCHAIC']!;

    if (strict) {
      if (bookCode.toLowerCase() != bookCode) {
        throw const FormatException('BOOKCODE must be lowercase.');
      }
      if (version != 'KJV') {
        throw const FormatException('VERSION must be KJV in this format.');
      }
      if (langPair != 'EN-KO') {
        throw const FormatException('LANGPAIR must be EN-KO.');
      }
      if (archaicMode != 'INLINE_PARENS') {
        throw const FormatException('ARCHAIC must be INLINE_PARENS.');
      }
      if (expectedBookCode != null && bookCode != expectedBookCode) {
        throw FormatException('BOOKCODE must be "$expectedBookCode" but was "$bookCode".');
      }
    }

    final chapter = int.tryParse(chapterStr);
    if (chapter == null || chapter <= 0) {
      throw FormatException('Invalid CHAPTER value: $chapterStr');
    }

    return ChapterHeader(
      book: book,
      bookCode: bookCode,
      chapter: chapter,
      version: version,
      langPair: langPair,
      archaicMode: archaicMode,
    );
  }

  static (String, String) _parseTitle(String line, {required bool strict}) {
    if (!line.startsWith('T|')) {
      throw const FormatException('Title line must start with "T|".');
    }
    final parts = line.split('|');

    // Expected: T | EN=... | KO=...
    if (parts.isEmpty || parts.first != 'T') {
      throw const FormatException('Invalid title line prefix.');
    }

    final map = <String, String>{};
    for (final p in parts.skip(1)) {
      final idx = p.indexOf('=');
      if (idx <= 0 || idx == p.length - 1) {
        throw FormatException('Invalid title token "$p". Expected KEY=VALUE.');
      }
      final k = p.substring(0, idx);
      final v = p.substring(idx + 1);
      map[k] = v;
    }

    const required = ['EN', 'KO'];
    for (final k in required) {
      if (!map.containsKey(k)) {
        throw FormatException('Title missing required key: $k');
      }
    }
    if (strict && map.keys.length != required.length) {
      throw FormatException('Title contains extra keys: ${map.keys.where((k) => !required.contains(k)).toList()}');
    }

    final en = map['EN']!;
    final ko = map['KO']!;

    if (strict) {
      if (en.trim().isEmpty || ko.trim().isEmpty) {
        throw const FormatException('Title EN/KO must not be empty.');
      }
    }
    return (en, ko);
  }

  static List<VerseLine> _parseVerses(List<String> lines, {required bool strict}) {
    final verses = <VerseLine>[];

    for (final line in lines) {
      if (!line.startsWith('V|')) {
        throw FormatException('Verse line must start with "V|": $line');
      }
      final parts = line.split('|');
      if (parts.isEmpty || parts.first != 'V') {
        throw FormatException('Invalid verse line prefix: $line');
      }

      final map = <String, String>{};
      for (final p in parts.skip(1)) {
        final idx = p.indexOf('=');
        if (idx <= 0 || idx == p.length - 1) {
          throw FormatException('Invalid verse token "$p". Expected KEY=VALUE.');
        }
        final k = p.substring(0, idx);
        final v = p.substring(idx + 1);
        map[k] = v;
      }

      const required = ['N', 'EN', 'KO'];
      for (final k in required) {
        if (!map.containsKey(k)) {
          throw FormatException('Verse missing required key: $k ($line)');
        }
      }
      if (strict && map.keys.length != required.length) {
        throw FormatException('Verse contains extra keys: ${map.keys.where((k) => !required.contains(k)).toList()}');
      }

      final nStr = map['N']!;
      final n = int.tryParse(nStr);
      if (n == null || n <= 0) {
        throw FormatException('Invalid verse number N=$nStr');
      }

      final en = map['EN']!;
      final ko = map['KO']!;

      if (strict) {
        if (en.trim().isEmpty || ko.trim().isEmpty) {
          throw FormatException('Verse EN/KO must not be empty (N=$n).');
        }
        // KO quotation marks rule: if “ appears, ” must also appear on the same line.
        final hasOpen = ko.contains('“');
        final hasClose = ko.contains('”');
        if (hasOpen != hasClose) {
          throw FormatException('KO quotes must open and close on the same line (N=$n).');
        }
      }

      verses.add(VerseLine(number: n, en: en, ko: ko));
    }

    if (strict) {
      // Ensure verses are strictly 1..N with no gaps.
      for (int i = 0; i < verses.length; i++) {
        final expected = i + 1;
        if (verses[i].number != expected) {
          throw FormatException('Verse numbering must be continuous starting at 1. Expected $expected but got ${verses[i].number}.');
        }
      }
    }

    return verses;
  }
}
