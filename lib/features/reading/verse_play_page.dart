import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/audio_hybrid_service.dart';
import '../../services/tts_service.dart';

class VersePlayPage extends StatefulWidget {
  final String verseId;

  const VersePlayPage({
    super.key,
    required this.verseId,
  });

  @override
  State<VersePlayPage> createState() => _VersePlayPageState();
}

class _VersePlayPageState extends State<VersePlayPage> {
  late final TtsService _tts;
  late final AudioHybridService _audio;

  bool _loading = true;
  String? _error;

  String? _verseTextEn;
  String? _verseAudioUrl;

  static const String _fallbackTextEn =
      "The Lord's message rang out from you not only in Macedonia and Achaia—your faith in God has become known everywhere.";

  @override
  void initState() {
    super.initState();
    _tts = TtsService();
    _audio = AudioHybridService(tts: _tts);
    _init();
  }

  Future<void> _init() async {
    try {
      await _tts.init();
      await _loadVerseFromFirestore();
      if (!mounted) return;

      final url = _verseAudioUrl;
      if (url != null && url.trim().isNotEmpty) {
        await _audio.prefetch(url);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'init 실패: $e';
      });
    }
  }

  Future<void> _loadVerseFromFirestore() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('verses')
          .doc(widget.verseId)
          .get();

      if (!doc.exists) {
        setState(() {
          _loading = false;
          _error = 'Firestore에 문서가 없습니다: verses/${widget.verseId}';
          _verseTextEn = null;
          _verseAudioUrl = null;
        });
        return;
      }

      final data = doc.data();
      final segments = data?['segments'] as List<dynamic>?;

String textEn = '';
String audioUrl = '';

if (segments != null && segments.isNotEmpty) {
  final seg0 = segments.first as Map<String, dynamic>;
  textEn = (seg0['textEn'] ?? '').toString();
  audioUrl = (seg0['audioUrl'] ?? '').toString();
}


      setState(() {
        _loading = false;
        _verseTextEn = textEn.trim().isEmpty ? null : textEn.trim();
        _verseAudioUrl = audioUrl.trim().isEmpty ? null : audioUrl.trim();
      });

    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Firestore 로드 실패: $e';
      });
    }
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final text = (_verseTextEn == null || _verseTextEn!.isEmpty)
        ? _fallbackTextEn
        : _verseTextEn!;

    final url = (_verseAudioUrl == null || _verseAudioUrl!.isEmpty)
        ? null
        : _verseAudioUrl!;

    await _audio.play(
      text: text,
      audioUrl: url,
      autoSwitch: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textToShow = (_verseTextEn == null || _verseTextEn!.isEmpty)
        ? _fallbackTextEn
        : _verseTextEn!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verse Play Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerseFromFirestore,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () => _audio.stop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('verseId: ${widget.verseId}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),

            if (_loading) ...[
              const Text('Firestore에서 불러오는 중...'),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],

            const Text('본문(영어)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(textToShow, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _play,
              icon: const Icon(Icons.volume_up),
              label: Text(_verseAudioUrl == null ? '듣기(TTS)' : '듣기(오디오/TTS)'),
            ),

            const SizedBox(height: 8),
            Text(
              _verseAudioUrl == null
                  ? 'audio_url이 없어서 TTS로 재생됩니다.'
                  : 'audio_url이 있으면 서버 오디오를 우선 재생하고, 실패 시 TTS로 전환합니다.',
            ),
          ],
        ),
      ),
    );
  }
}
