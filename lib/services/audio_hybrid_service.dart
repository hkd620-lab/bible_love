import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';

import 'tts_service.dart';

class AudioHybridService {
  final TtsService tts;
  final AudioPlayer player;
  final CacheManager cache;

  AudioHybridService({
    required this.tts,
    AudioPlayer? player,
    CacheManager? cache,
  })  : player = player ?? AudioPlayer(),
        cache = cache ?? DefaultCacheManager();

  Future<void> dispose() async {
    await tts.stop();
    await player.dispose();
  }

  Future<void> play({
    required String text,
    String? audioUrl,
    bool autoSwitch = true,
  }) async {
    await player.stop();
    await tts.speakEn(text);

    if (audioUrl == null || audioUrl.trim().isEmpty) return;

    try {
      final file = await cache.getSingleFile(audioUrl);
      await player.setFilePath(file.path);

      if (autoSwitch) {
        await tts.stop();
        await player.play();
      }
    } catch (_) {
      // 서버 오디오 실패 시 TTS 유지
    }
  }

  Future<void> stop() async {
    await tts.stop();
    await player.stop();
  }

  Future<void> prefetch(String audioUrl) async {
    if (audioUrl.trim().isEmpty) return;
    try {
      await cache.getSingleFile(audioUrl);
    } catch (_) {
      // 프리페치 실패는 무시
    }
  }
}
