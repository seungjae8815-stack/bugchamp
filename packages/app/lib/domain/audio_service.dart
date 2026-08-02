import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사운드 설정(로컬 저장). 배경음·효과음 각각 on/off + 볼륨(0~1).
@immutable
class AudioSettings {
  const AudioSettings({
    this.bgmOn = true,
    this.sfxOn = true,
    this.bgmVol = 0.55,
    this.sfxVol = 0.8,
  });

  final bool bgmOn;
  final bool sfxOn;
  final double bgmVol;
  final double sfxVol;

  AudioSettings copyWith({
    bool? bgmOn,
    bool? sfxOn,
    double? bgmVol,
    double? sfxVol,
  }) => AudioSettings(
    bgmOn: bgmOn ?? this.bgmOn,
    sfxOn: sfxOn ?? this.sfxOn,
    bgmVol: bgmVol ?? this.bgmVol,
    sfxVol: sfxVol ?? this.sfxVol,
  );
}

/// 앱 전역 사운드(배경음 + 효과음). [NotificationService] 처럼 싱글턴이라
/// Riverpod 없는 순수 위젯(전투 아레나 등)에서도 직접 호출할 수 있다.
///
/// 설정은 shared_preferences 에 **기기 로컬** 저장(세이브·서버와 무관 → 기기별 유지).
/// 사운드 파일은 `assets/sounds/*.wav`(합성 스타터). 같은 파일명으로 CC0 교체 가능.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  /// 설정 상태(설정 UI 가 이걸 구독해 슬라이더/토글을 갱신).
  final ValueNotifier<AudioSettings> settings = ValueNotifier(
    const AudioSettings(),
  );

  final AudioPlayer _bgm = AudioPlayer(playerId: 'bgm');
  final Map<String, AudioPlayer> _sfx = {};
  SharedPreferences? _prefs;
  bool _ready = false;
  bool _bgmStarted = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      final p = _prefs!;
      settings.value = AudioSettings(
        bgmOn: p.getBool('audio.bgmOn') ?? true,
        sfxOn: p.getBool('audio.sfxOn') ?? true,
        bgmVol: p.getDouble('audio.bgmVol') ?? 0.55,
        sfxVol: p.getDouble('audio.sfxVol') ?? 0.8,
      );
      await _bgm.setReleaseMode(ReleaseMode.loop);
      _ready = true;
    } catch (e) {
      debugPrint('AudioService init failed: $e');
    }
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    final s = settings.value;
    await p.setBool('audio.bgmOn', s.bgmOn);
    await p.setBool('audio.sfxOn', s.sfxOn);
    await p.setDouble('audio.bgmVol', s.bgmVol);
    await p.setDouble('audio.sfxVol', s.sfxVol);
  }

  /// 홈 진입/복귀 시 호출 — 배경음 시작(설정 on 일 때만).
  Future<void> startBgm() async {
    if (!_ready) await init();
    final s = settings.value;
    if (!s.bgmOn) return;
    try {
      if (_bgmStarted) {
        await _bgm.setVolume(s.bgmVol);
        await _bgm.resume();
      } else {
        await _bgm.play(AssetSource('sounds/bgm.wav'), volume: s.bgmVol);
        _bgmStarted = true;
      }
    } catch (e) {
      debugPrint('startBgm: $e');
    }
  }

  Future<void> pauseBgm() async {
    try {
      await _bgm.pause();
    } catch (_) {}
  }

  Future<void> setBgmOn(bool v) async {
    settings.value = settings.value.copyWith(bgmOn: v);
    await _persist();
    if (v) {
      await startBgm();
    } else {
      try {
        await _bgm.stop();
      } catch (_) {}
      _bgmStarted = false;
    }
  }

  Future<void> setSfxOn(bool v) async {
    settings.value = settings.value.copyWith(sfxOn: v);
    await _persist();
    if (v) sfxTap(); // 켜는 순간 미리듣기
  }

  Future<void> setBgmVol(double v) async {
    settings.value = settings.value.copyWith(bgmVol: v);
    try {
      await _bgm.setVolume(v);
    } catch (_) {}
    await _persist();
  }

  Future<void> setSfxVol(double v) async {
    settings.value = settings.value.copyWith(sfxVol: v);
    await _persist();
  }

  Future<void> _playSfx(String name) async {
    if (!_ready || !settings.value.sfxOn) return;
    try {
      final p = _sfx.putIfAbsent(
        name,
        () => AudioPlayer(playerId: 'sfx_$name')
          ..setReleaseMode(ReleaseMode.stop),
      );
      await p.stop();
      await p.play(AssetSource('sounds/$name.wav'), volume: settings.value.sfxVol);
    } catch (e) {
      debugPrint('playSfx($name): $e');
    }
  }

  void sfxHit() => _playSfx('hit');
  void sfxHurt() => _playSfx('hurt');
  void sfxTap() => _playSfx('tap');
  void sfxReward() => _playSfx('reward');
}
