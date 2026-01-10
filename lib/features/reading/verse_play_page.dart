// lib/features/reading/verse_play_page.dart
//
// Fix: Bottom overflow (e.g., "BOTTOM OVERFLOWED BY XX PIXELS")
// Approach:
// - Text area: scrollable (Expanded + SingleChildScrollView)
// - Audio controls: fixed at bottom (no overflow)
// - SafeArea applied
//
// Dependencies (pubspec.yaml):
//   just_audio: ^0.9.36
//
// NOTE: This file is UI-safe even if you later swap the data source (Firestore, local, etc.).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VersePlayPage extends StatefulWidget {
  const VersePlayPage({
    super.key,
    required this.title,
    required this.textEn,
    required this.textKo,
    required this.audioUrl,
  });

  final String title;
  final String textEn;
  final String textKo;
  final String audioUrl;

  @override
  State<VersePlayPage> createState() => _VersePlayPageState();
}

class _VersePlayPageState extends State<VersePlayPage> {
  late final AudioPlayer _player;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _isLoadingAudio = false;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _bindAudioStreams();
    _prepareAudio();
  }

  void _bindAudioStreams() {
    _durationSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });

    _positionSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });

    _playerStateSub = _player.playerStateStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _prepareAudio() async {
    setState(() {
      _isLoadingAudio = true;
      _audioError = null;
    });

    try {
      await _player.setUrl(widget.audioUrl);
    } catch (e) {
      setState(() {
        _audioError = 'Audio load failed: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingAudio = false);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool get _isPlaying => _player.playing;

  Future<void> _onPlay() async {
    if (_audioError != null) {
      await _prepareAudio();
      if (_audioError != null) return;
    }
    await _player.play();
  }

  Future<void> _onStop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  Future<void> _onSeek(double seconds) async {
    final target = Duration(seconds: seconds.round());
    await _player.seek(target);
  }

  double _safeMaxSeconds() {
    final s = _duration.inSeconds;
    return s <= 0 ? 1.0 : s.toDouble();
  }

  double _safePositionSeconds() {
    final pos = _position.inSeconds.toDouble();
    final max = _safeMaxSeconds();
    if (pos.isNaN) return 0.0;
    if (pos < 0) return 0.0;
    if (pos > max) return max;
    return pos;
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _prepareAudio,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload audio',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1) Scrollable content (prevents bottom overflow)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      title: 'English',
                      text: widget.textEn,
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Korean',
                      text: widget.textKo,
                    ),
                    const SizedBox(height: 12),

                    // Audio URL display (wrap to multiple lines, no overflow)
                    Text(
                      'audioUrl: ${widget.audioUrl}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      softWrap: true,
                    ),

                    if (_audioError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _audioError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 2) Fixed bottom audio controls (never overflow)
            _AudioControlsBar(
              isLoading: _isLoadingAudio,
              isPlaying: _isPlaying,
              position: _position,
              duration: _duration,
              positionSeconds: _safePositionSeconds(),
              maxSeconds: _safeMaxSeconds(),
              fmt: _fmt,
              onPlay: _onPlay,
              onStop: _onStop,
              onSeek: _onSeek,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioControlsBar extends StatelessWidget {
  const _AudioControlsBar({
    required this.isLoading,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.positionSeconds,
    required this.maxSeconds,
    required this.fmt,
    required this.onPlay,
    required this.onStop,
    required this.onSeek,
  });

  final bool isLoading;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  final double positionSeconds;
  final double maxSeconds;

  final String Function(Duration) fmt;

  final Future<void> Function() onPlay;
  final Future<void> Function() onStop;
  final Future<void> Function(double seconds) onSeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 12,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Buttons row
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onPlay,
                    icon: Icon(isPlaying ? Icons.play_arrow : Icons.play_arrow),
                    label: Text(isLoading ? 'Loading...' : 'Play'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Slider + time
            Row(
              children: [
                Text(
                  fmt(position),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Slider(
                    value: positionSeconds,
                    min: 0,
                    max: maxSeconds,
                    onChanged: isLoading ? null : onSeek,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  fmt(duration),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
