import 'dart:math' as math;

import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 처음 쓰는 기능의 **즉시 완료 1회 무료**(2026-11-12 사장님 확정) — 기능을 처음 만났을 때 기다리지 않고
/// 끝까지 한 번 보게 한다. 부화기가 1칸뿐이라 첫 알이 희귀(90분)면 시작하자마자 멈췄다.
/// ❌ 젤리를 주지 않는다 — 젤리를 안 받을 뿐이고, 기능마다 한 번이라 수도꼭지가 아니다(§2.6).
/// 서버가 판정하는 기다림(연구 시간 예산)은 넣지 않는다 — 기기에서 끝나는 것만.
const kFirstFreeKeys = {'hatch', 'breed', 'breakthrough'};

/// [key] 기능의 첫 1회 무료가 남았나.
bool firstFreeAvailable(SaveGame s, String key) =>
    kFirstFreeKeys.contains(key) && !s.firstFreeUsed.contains(key);

/// 첫 1회 무료면 0, 아니면 [cost].
int firstFreeCost(SaveGame s, String key, int cost) =>
    firstFreeAvailable(s, key) ? 0 : cost;

/// 첫 1회 무료를 썼다고 적는다(이미 썼으면 그대로).
SaveGame markFirstFree(SaveGame s, String key) => firstFreeAvailable(s, key)
    ? s.copyWith(firstFreeUsed: {...s.firstFreeUsed, key})
    : s;

/// 신규 부화 단축(2026-11-12) — 계정의 처음 몇 번 부화는 최대 `beginnerHatchMaxSec` 초. 앱 부화기 넣기와 화면 시간 표시 공용.
int beginnerHatchSeconds(SaveGame s, PetConfig cfg, int sec) =>
    s.beginnerHatches < cfg.beginnerHatchCount && cfg.beginnerHatchMaxSec > 0
    ? math.min(sec, cfg.beginnerHatchMaxSec)
    : sec;
