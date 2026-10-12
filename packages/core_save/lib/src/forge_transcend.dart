import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 공방 초월 — 시간 + 젤리 즉시 완료(2026-10-12 사장님 확정).
///
/// 누르는 순간: 화석을 내고 낀 장비·모루가 사라지고 공방이 0레벨(풀잎)로 돌아간다(기존과 같다).
/// 옵션 최대치가 오르는 효과([SaveGame.forgeTranscend] +1)는 **시간이 끝나 수령할 때** 붙는다.
/// 진행 중에도 공방 제련·등급업은 할 수 있고, 다시 초월만 못 한다.
/// 기기 권위(솔로 루프) — 앱이 이 함수로 처리하고 서버는 구버전 업로드에서 끝 시각을 지킨다(feat 25).
///
/// 결과: 성공이면 `save` 에 새 세이브, 실패면 `error` 에 이유.
typedef ForgeTranscendResult = ({SaveGame? save, String? error});

/// 초월을 시작한다. 실패 이유: `in_progress`(이미 진행 중) · `not_max`(최대 레벨 아님 · 등급업 중) ·
/// `maxed`(초월 끝) · `not_enough_fossil`.
ForgeTranscendResult startForgeTranscend(
  SaveGame s,
  ForgeConfig forge,
  DateTime now,
) {
  if (s.forgeTranscendAt != null) return (save: null, error: 'in_progress');
  if (s.forgeLevel < forge.maxLevel || s.forgeUpAt != null) {
    return (save: null, error: 'not_max');
  }
  if (s.forgeTranscend >= forge.transcendMax) {
    return (save: null, error: 'maxed');
  }
  final cost = forge.transcendFossilCost(s.forgeTranscend);
  final have = s.materialCount(MaterialKind.fossil);
  if (have < cost) return (save: null, error: 'not_enough_fossil');
  final d = forge.transcendDuration(s.forgeTranscend);
  final cleared = s.copyWith(
    forgeLevel: 0,
    forgeSteps: 0,
    clearForgeUpAt: true,
    equippedItems: const {},
    forgeStack: const [],
    materials: {...s.materials, MaterialKind.fossil: have - cost},
    // 등급 필터는 풀잎부터 다시 시작하는 공방에 맞게 푼다 — "호박 이상"이 남으면 거의 다 팔리고(낀 장비도 없어
    // 별 재료로도 안 간다) 화석만 끝까지 탄다(2026-10-10 출시 전 점검). 옵션 필터는 등급과 무관해서 남긴다.
    autoForgeMinTier: 0,
  );
  // 시간이 0 이면(설정에 시간이 없으면) 예전처럼 바로 오른다.
  if (d <= Duration.zero) {
    return (
      save: cleared.copyWith(forgeTranscend: s.forgeTranscend + 1),
      error: null,
    );
  }
  return (
    save: cleared.copyWith(forgeTranscendAt: now.toUtc().add(d)),
    error: null,
  );
}

/// 시간이 끝난 초월을 수령한다. 실패 이유: `none`(진행 중 아님) · `not_ready`.
ForgeTranscendResult claimForgeTranscendSave(
  SaveGame s,
  ForgeConfig forge,
  DateTime now,
) {
  final at = s.forgeTranscendAt;
  if (at == null) return (save: null, error: 'none');
  if (now.isBefore(at)) return (save: null, error: 'not_ready');
  return (save: _complete(s, forge), error: null);
}

/// 남은 시간을 젤리로 즉시 끝낸다 — 값표는 공방 등급업과 같다([ForgeConfig.levelUpJelly]).
/// 시간이 이미 끝났으면 무료로 수령한다. 실패 이유: `none` · `not_enough_jelly`.
ForgeTranscendResult rushForgeTranscendSave(
  SaveGame s,
  ForgeConfig forge,
  DateTime now,
) {
  final at = s.forgeTranscendAt;
  if (at == null) return (save: null, error: 'none');
  final cost = forgeTranscendRushJelly(s, forge, now);
  final have = s.materialCount(MaterialKind.jelly);
  if (have < cost) return (save: null, error: 'not_enough_jelly');
  final paid = cost <= 0
      ? s
      : s.copyWith(
          materials: {...s.materials, MaterialKind.jelly: have - cost},
        );
  return (save: _complete(paid, forge), error: null);
}

/// 진행 중 초월을 지금 끝내는 젤리 값(진행 중이 아니거나 끝났으면 0).
int forgeTranscendRushJelly(SaveGame s, ForgeConfig forge, DateTime now) {
  final at = s.forgeTranscendAt;
  if (at == null) return 0;
  return forge.levelUpJelly(at.difference(now));
}

SaveGame _complete(SaveGame s, ForgeConfig forge) => s.copyWith(
  forgeTranscend: (s.forgeTranscend + 1).clamp(0, forge.transcendMax),
  clearForgeTranscendAt: true,
);
