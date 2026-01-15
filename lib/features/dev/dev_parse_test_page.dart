// lib/features/dev/dev_parse_test_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/bible_text_parser.dart';

class DevParseTestPage extends StatefulWidget {
  const DevParseTestPage({super.key});

  static const routeName = '/dev/parse';

  @override
  State<DevParseTestPage> createState() => _DevParseTestPageState();
}

class _DevParseTestPageState extends State<DevParseTestPage> {
  final _controller = TextEditingController();
  String _log = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _append(String s) {
    setState(() => _log += '$s\n');
    debugPrint(s);
  }

  void _clearLog() {
    setState(() => _log = '');
  }

  Future<void> _loadAssetChapter(String assetPath) async {
    try {
      final text = await rootBundle.loadString(assetPath);
      _controller.text = text;
      _append('OK: loaded asset: $assetPath');
    } catch (e) {
      _append('FAIL: load asset: $assetPath');
      _append('ERR : $e');
    }
  }

  Future<void> _loadProverbs1FromAsset() async {
    final text = await rootBundle.loadString('assets/dev/proverbs_001.txt');

    _controller.text = text;

    _runParseTest();
  }

  void _runParseTest() {
    setState(() => _log = '');
    _clearLog();

    try {
      final parsed = BibleTextParser.parseChapter(_controller.text);

      // 필드명이 프로젝트마다 달라서, 안전하게 toString 위주로 로그를 남깁니다.
      _append('OK: header = ${parsed.header}');
      _append("OK: title  = EN='${parsed.titleEn}' KO='${parsed.titleKo}'");
      _append('OK: verses = ${parsed.verses.length}');

      if (parsed.verses.isNotEmpty) {
        _append('first = ${parsed.verses.first}');
        _append('last  = ${parsed.verses.last}');
      }

      _append('PASS');
    } catch (e) {
      _append('FAIL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEV — Parse Test (Assets)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loadProverbs1FromAsset,
                  child: const Text('Load Proverbs 1 (asset)'),
                ),
                ElevatedButton(
                  onPressed: _runParseTest,
                  child: const Text('Parse/Test'),
                ),
                OutlinedButton(
                  onPressed: _clearLog,
                  child: const Text('Clear Log'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste chapter text here (or load asset)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _log.isEmpty ? '(log)' : _log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
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
