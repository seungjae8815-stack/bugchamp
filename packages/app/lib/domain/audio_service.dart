import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
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
/// 사운드 파일은 `assets/sounds/` — **효과음은 `.wav`**(디코딩 지연 없이 즉시 재생),
/// **배경음은 `.mp3`**(137초 트랙을 wav 로 넣으면 APK 가 24MB 늘어난다).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  /// 설정 상태(설정 UI 가 이걸 구독해 슬라이더/토글을 갱신).
  final ValueNotifier<AudioSettings> settings = ValueNotifier(
    const AudioSettings(),
  );

  final _lifecycle = _BgmLifecycle();
  final AudioPlayer _bgm = AudioPlayer(playerId: 'bgm');
  final Map<String, AudioPlayer> _sfx = {};
  SharedPreferences? _prefs;
  bool _ready = false;
  bool _bgmStarted = false;
  String _bgmTrack = 'bgm';
  Duration _mainPos = Duration.zero;

  Future<void> init() async {
    if (_ready) return;
    try {
      // ⚠️ 오디오 포커스를 끈다. 기본값(gain)이면 **효과음이 재생될 때마다
      // 배경음 플레이어의 포커스를 뺏어** BGM 이 멈춘다(탭 전환음 한 번에
      // 배경음이 사라지던 버그의 원인). 게임 사운드는 서로 섞여야 한다.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
          ),
          // ⚠️ ambient 에 mixWithOthers 를 **명시하면** audioplayers 가 assert 로
          // 죽어 init 전체가 실패한다 = 배경음·효과음이 통째로 안 난다(디버그 빌드).
          // ambient 는 원래 다른 앱 오디오와 섞이고 무음 스위치를 따르므로 옵션 불필요.
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      _prefs = await SharedPreferences.getInstance();
      final p = _prefs!;
      settings.value = AudioSettings(
        bgmOn: p.getBool('audio.bgmOn') ?? true,
        sfxOn: p.getBool('audio.sfxOn') ?? true,
        bgmVol: p.getDouble('audio.bgmVol') ?? 0.55,
        sfxVol: p.getDouble('audio.sfxVol') ?? 0.8,
      );
      await _bgm.setReleaseMode(ReleaseMode.loop);
      // 배경음 일시정지/재개는 **여기서** 책임진다. 예전엔 AppShell 의 생명주기
      // 콜백이 했는데, ① 타이틀 화면에는 옵저버가 없어 대문에서 앱을 내리면
      // 음악이 계속 났고 ② `paused` 만 보고 있어 `hidden`/`detached` 로 빠지는
      // 경로에서 안 멈췄다. 화면과 무관하게 서비스가 스스로 처리한다.
      WidgetsBinding.instance.addObserver(_lifecycle);
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
        await _bgm.play(AssetSource('sounds/$_bgmTrack.mp3'), volume: s.bgmVol);
        _bgmStarted = true;
      }
    } catch (e) {
      debugPrint('startBgm: $e');
    }
  }

  /// 배경음 트랙 교체(보스전·아레나 전용곡). 같은 트랙이면 아무것도 하지 않는다.
  /// 복귀는 [restoreBgm].
  ///
  /// 메인 트랙은 **재생 위치를 기억했다가 이어서** 튼다. 안 그러면 보스를 만날
  /// 때마다 137초짜리 배경음이 처음으로 되감겨 앞 몇 초만 반복해 듣게 된다.
  Future<void> switchBgm(String track) async {
    if (_bgmTrack == track) return;
    if (_bgmTrack == 'bgm') {
      try {
        _mainPos = await _bgm.getCurrentPosition() ?? Duration.zero;
      } catch (_) {
        _mainPos = Duration.zero;
      }
    }
    _bgmTrack = track;
    _bgmStarted = false;
    try {
      await _bgm.stop();
    } catch (_) {}
    await startBgm();
    if (track == 'bgm' && _mainPos > Duration.zero && _bgmStarted) {
      try {
        await _bgm.seek(_mainPos);
      } catch (_) {}
    }
  }

  /// 기본 배경음으로 복귀.
  Future<void> restoreBgm() => switchBgm('bgm');

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
        () =>
            AudioPlayer(playerId: 'sfx_$name')
              ..setReleaseMode(ReleaseMode.stop),
      );
      await p.stop();
      await p.play(
        AssetSource('sounds/$name.wav'),
        volume: settings.value.sfxVol,
      );
    } catch (e) {
      debugPrint('playSfx($name): $e');
    }
  }

  // ── 전투/조작 (자주 재생 — 파일이 짧고 음량도 낮게 정규화돼 있다) ──────────
  void sfxHit() => _playSfx('hit');
  void sfxHurt() => _playSfx('hurt');
  void sfxTap() => _playSfx('tap');
  void sfxSwipe() => _playSfx('swipe');

  /// 몬스터(서식지/보스) 처치음.
  void sfxDie() => _playSfx('die');

  /// 재화 부족·채집함 가득참·잠긴 칸 등 "안 됨" 피드백.
  void sfxError() => _playSfx('error');

  // ── 획득 ────────────────────────────────────────────────────────────────
  /// 곤충 획득(일반). ⚠️ `catch.wav` 미납품 상태 — 파일이 없으면 조용히 무시된다.
  void sfxCatch() => _playSfx('catch');

  /// 희귀 이상 곤충 획득. [sfxCatch] 대신 재생한다.
  void sfxRare() => _playSfx('rare');
  void sfxCoin() => _playSfx('coin');
  void sfxReward() => _playSfx('reward');

  // ── 육성 ────────────────────────────────────────────────────────────────
  void sfxEnhance() => _playSfx('enhance');

  /// 모루 망치질. **한 번 칠 때마다** 부른다.
  ///
  /// ⚠️ 파일은 반드시 **한 방짜리**여야 한다. 받은 원본이 15초짜리 연속
  /// 망치질이라 그대로 넣었더니 화면을 떠나도 계속 울렸다(0.135초로 잘랐다).
  void sfxForge() => _playSfx('forge');
  void sfxHatch() => _playSfx('hatch');
  void sfxBreed() => _playSfx('breed');
  void sfxMission() => _playSfx('mission');

  // ── 진행/전투 결과 ──────────────────────────────────────────────────────
  void sfxLevelUp() => _playSfx('levelup');
  void sfxBoss() => _playSfx('boss');
  void sfxWin() => _playSfx('win');
  void sfxLose() => _playSfx('lose');
  void sfxPromote() => _playSfx('promote');
  void sfxRankUp() => _playSfx('rankup');
  void sfxRankDown() => _playSfx('rankdown');
}

/// 앱이 백그라운드로 가면 배경음을 멈춘다.
///
/// `paused` 만 보면 안 된다 — Flutter 3.13 부터 `hidden` 이 추가돼서, 기기·경로에
/// 따라 `hidden` 으로만 빠지고 `paused` 가 안 오는 경우가 있다(그때 음악이 계속
/// 났다). `inactive` 는 전화·알림센터처럼 잠깐 스치는 상태라 건드리지 않는다.
class _BgmLifecycle extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(AudioService.instance.pauseBgm());
      case AppLifecycleState.resumed:
        unawaited(AudioService.instance.startBgm());
      case AppLifecycleState.inactive:
        break;
    }
  }
}
