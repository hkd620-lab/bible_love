// lib/features/reading/verse_play_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  final AudioPlayer _player = AudioPlayer();

  String _title = '';
  String _textEn = '';
  String _textKo = '';
  String _audioUrl = '';

  bool _loadingDoc = true;
  String? _docError;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;

  String? _audioError; // 오디오 로드/재생 에러

  @override
  void initState() {
    super.initState();
    _loadVerseDoc();
    _listenPlayer();
  }

  void _listenPlayer() {
    _playerStateSub = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });

    // 네트워크/디코딩 등 재생 에러 잡기
    _playbackEventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        if (mounted) {
          setState(() {
            _audioError = e.toString();
          });
        }
      },
    );
  }

  Future<void> _loadVerseDoc() async {
    setState(() {
      _loadingDoc = true;
      _docError = null;
      _audioError = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('verses')
          .doc(widget.verseId)
          .get();

      if (!doc.exists) {
        setState(() {
          _docError = '문서가 없습니다: ${widget.verseId}';
          _loadingDoc = false;
        });
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};

      // 진단 로그(필요 없으면 지워도 됨)
      debugPrint('VERSE_ID=${widget.verseId}');
      debugPrint('RAW=${doc.data()}');

      // Firestore 실제 구조에 맞춤:
      // - ref: "1 Thessalonians 1:8"
      // - textEn: (문서 최상단)
      // - segments[0].ko / segments[0].t / segments[0].audioUrl
      final ref = (data['ref'] ?? '').toString();
      final textEn = (data['textEn'] ?? '').toString();

      final segments =
          (data['segments'] is List) ? (data['segments'] as List) : const [];
      final first = segments.isNotEmpty && segments.first is Map
          ? (segments.first as Map)
          : const <dynamic, dynamic>{};

      final textKo = (first['ko'] ?? '').toString();
      final tShort = (first['t'] ?? '').toString();
      final audioUrl = (first['audioUrl'] ?? '').toString();

      setState(() {
        _title = ref.isNotEmpty ? ref : 'Verse';
        _textEn = (textEn.isNotEmpty ? textEn : tShort).trim();
        _textKo = textKo.trim();
        _audioUrl = audioUrl.trim();
        _loadingDoc = false;
      });

      // audioUrl이 있으면 미리 로드(자동재생은 하지 않음)
      if (_audioUrl.isNotEmpty) {
        await _setAudioUrl(_audioUrl);
      }
    } catch (e) {
      setState(() {
        _docError = e.toString();
        _loadingDoc = false;
      });
    }
  }

  Future<void> _setAudioUrl(String url) async {
    setState(() {
      _audioError = null;
    });

    try {
      await _player.stop();
      await _player.setUrl(url);
    } catch (e) {
      setState(() {
        _audioError = e.toString();
      });
    }
  }

  bool get _isLoadingAudio {
    final state = _player.playerState;
    return state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
  }

  bool get _isPlaying {
    final state = _player.playerState;
    return state.playing && state.processingState != ProcessingState.completed;
  }

  Future<void> _togglePlayPause() async {
    if (_audioUrl.isEmpty) return;

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    // 완료 상태면 처음부터
    if (_player.playerState.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }

    // 아직 setUrl이 안된 경우 대비
    if (_player.audioSource == null) {
      await _setAudioUrl(_audioUrl);
      if (_audioError != null) return;
    }

    await _player.play();
  }

  Future<void> _stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  // ===== 문법/단어 기능 =====

  void _openGrammarSheet() {
    final en = _textEn.trim();
    if (en.isEmpty) {
      _showBottomSheet(title: '문법', body: '영어 문장이 비어있습니다.');
      return;
    }
    final info = _simpleGrammar(en);
    _showBottomSheet(title: '문법', body: info);
  }

  void _openVocabSheet() {
    final en = _textEn.trim();
    if (en.isEmpty) {
      _showBottomSheet(title: '단어', body: '영어 문장이 비어있습니다.');
      return;
    }

    final list = _simpleVocab(en);
    _showBottomSheet(
      title: '단어',
      body: list.isEmpty ? '뽑아낼 단어가 없습니다.' : list.join('\n'),
    );
  }

  String _simpleGrammar(String s) {
    // 초보자용: “눈에 보이는” 핵심만
    final hasNotOnly = s.toLowerCase().contains('not only');
    final hasButAlso = s.toLowerCase().contains('but also');
    final hasDash = s.contains('—') || s.contains('--');
    final hasFrom = RegExp(r'\bfrom\b', caseSensitive: false).hasMatch(s);
    final hasIn = RegExp(r'\bin\b', caseSensitive: false).hasMatch(s);
    final hasHasBecomeKnown = s.toLowerCase().contains('has become known');

    final lines = <String>[];
    lines.add('1) 핵심 구조(대략)');
    lines.add('- 주어(S) + 동사(V) + (부가 정보) 형태로 읽습니다.');
    lines.add('');

    if (hasHasBecomeKnown) {
      lines.add('2) has become known');
      lines.add('- “알려지게 되었다” (become + 형용사/과거분사 느낌)');
      lines.add('');
    }

    if (hasNotOnly) {
      lines.add('3) not only ~ (but also) ~');
      lines.add('- “~뿐만 아니라 …도” 라는 강조 표현입니다.');
      if (!hasButAlso) {
        lines.add('- not only A but also B 형태가 기본이지만, 문장에 따라 but also가 생략되기도 합니다.');
      }
      lines.add('');
    }

    if (hasFrom) {
      lines.add('4) from');
      lines.add('- “~로부터/~에서” 출발·근원(출처)을 나타냅니다.');
      lines.add('');
    }

    if (hasIn) {
      lines.add('5) in + 장소');
      lines.add('- “~에서(지역/장소)”를 나타내는 전치사구입니다.');
      lines.add('');
    }

    if (hasDash) {
      lines.add('6) — (대시)');
      lines.add('- 앞 내용을 보충 설명하거나 덧붙이는 느낌입니다.');
      lines.add('');
    }

    lines.add('읽기 팁');
    lines.add('- 길면 쉼표(,)나 — 에서 잠깐 끊어서 읽으면 쉬워집니다.');

    return lines.join('\n');
  }

  List<String> _simpleVocab(String s) {
    // 단순 토큰화 + 불용어 제거 + 길이 기준 + 상위 빈도
    final stop = <String>{
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'also',
      'not',
      'only',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'from',
      'with',
      'by',
      'you',
      'your',
      'has',
      'have',
      'had',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'it',
      'this',
      'that',
      'these',
      'those',
      'as',
      'we',
      'they',
      'he',
      'she',
      'i',
      'our',
      'their',
      'into',
      'over',
      'under',
      'about',
      'every',
      'become',
      'known',
    };

    final cleaned = s
        .replaceAll('—', ' ')
        .replaceAll(RegExp(r"[^A-Za-z' ]"), ' ')
        .toLowerCase();

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => w.length >= 4)
        .where((w) => !stop.contains(w))
        .toList();

    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }

    final top = freq.keys.toList()
      ..sort((a, b) => (freq[b]!).compareTo(freq[a]!));

    // 아주 간단 뜻(계속 확장 가능)
    final dict = <String, String>{
      'message': '메시지/말씀',
      'rang': '울리다(ring 과거형)',
      'everywhere': '어디에서나',
      'faith': '믿음',
      'macedonia': '마케도니아',
      'achaia': '아가야',
      'gospel': '복음',
      'lord': '주님',
      'power': '능력',
      'spirit': '성령/영',
    };

    final result = <String>[];

    // 표현(구)
    if (s.toLowerCase().contains('not only')) {
      result.add('• not only A (but also) B : A뿐만 아니라 B도');
    }
    if (s.toLowerCase().contains('has become known')) {
      result.add('• has become known : 알려지게 되었다');
    }
    if (s.toLowerCase().contains('rang out')) {
      result.add('• rang out : (소리/소식이) 퍼져 나가다');
    }

    for (final w in top.take(10)) {
      final meaning = dict[w] ?? '(뜻 추가 필요)';
      result.add('- $w : $meaning');
    }

    return result;
  }

  // ===== UI =====

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playbackEventSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _title.isEmpty ? 'Verse' : _title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loadVerseDoc,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingDoc
          ? const Center(child: CircularProgressIndicator())
          : _docError != null
              ? _ErrorView(
                  message: _docError!,
                  onRetry: _loadVerseDoc,
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TextCard(
                        title: 'English',
                        text: _textEn.isEmpty ? '(empty)' : _textEn,
                      ),
                      const SizedBox(height: 12),
                      _TextCard(
                        title: 'Korean',
                        text: _textKo.isEmpty ? '(empty)' : _textKo,
                      ),
                      const SizedBox(height: 16),

                      // Audio URL 표시(디버깅용)
                      if (_audioUrl.isEmpty)
                        const Text(
                          'audioUrl이 비어있습니다.',
                          style: TextStyle(color: Colors.redAccent),
                        )
                      else
                        Text(
                          'audioUrl: $_audioUrl',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),

                      const SizedBox(height: 10),

                      // 오디오 에러
                      if (_audioError != null) ...[
                        Text(
                          '오디오 에러: $_audioError',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // 컨트롤
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_audioUrl.isEmpty || _isLoadingAudio)
                                      ? null
                                      : _togglePlayPause,
                              icon: _isLoadingAudio
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(_isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow),
                              label: Text(_isPlaying ? 'Pause' : 'Play'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: (_audioUrl.isEmpty) ? null : _stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 진행바 + 시간
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? Duration.zero;
                          final dur = _player.duration ?? Duration.zero;
                          final maxMs =
                              dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
                          final valueMs =
                              pos.inMilliseconds.clamp(0, maxMs);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Slider(
                                value: valueMs.toDouble(),
                                max: maxMs.toDouble(),
                                onChanged: (_player.duration == null)
                                    ? null
                                    : (v) {
                                        _player.seek(Duration(
                                            milliseconds: v.toInt()));
                                      },
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_fmt(pos)),
                                  Text(_fmt(dur)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const Spacer(),

                      // 문법/단어 아이콘
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: '문법',
                            onPressed: _openGrammarSheet,
                            icon: const Icon(Icons.menu_book),
                          ),
                          IconButton(
                            tooltip: '단어',
                            onPressed: _openVocabSheet,
                            icon: const Icon(Icons.psychology),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  void _showBottomSheet({required String title, required String body}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${two(m)}:${two(s)}';
  }
}

class _TextCard extends StatelessWidget {
  final String title;
  final String text;

  const _TextCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
