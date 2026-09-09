import 'dart:math' as math;

import 'package:core_models/core_models.dart';

/// 방치 런에 나오는 **몬스터 한 종류**의 정의(§6 — 코드가 아니라 데이터).
///
/// 예전엔 `HabitatKind` **enum 다섯 개**가 전부였다. 그림을 늘리려면 enum·
/// switch·이모지 표를 다 고쳐야 했고, 그래서 게임 전체가 나무·꽃·바위·
/// 그루터기·버섯 5장으로 굴러갔다(2026-09-09 제보 — "매번 비슷해서 단조롭다").
/// 이제는 JSON 에 한 줄 적고 그림을 넣으면 끝이다.
class MonsterDef {
  const MonsterDef({
    required this.id,
    required this.name,
    this.glyph = '🌿',
    this.scale = 1.0,
  });

  /// 애셋 파일명이자 지역 목록에서 쓰는 키. `assets/images/habitats/{id}.webp`
  final String id;

  final LocalizedText name;

  /// 그림이 아직 없을 때 대신 그릴 이모지(§6 — 폴백도 데이터).
  ///
  /// enum 시절엔 이 표가 `art.dart` 의 switch 안에 있었다. 몬스터를 늘릴 때마다
  /// **코드를 고쳐야 하는 이유**가 하나 더 있었던 셈이다.
  final String glyph;

  /// 같은 그림을 크게/작게 그려 실루엣을 가른다(1.0 = 기본 84px).
  ///
  /// 그림 한 장으로도 다른 개체처럼 보이게 하는 가장 싼 수단이다.
  final double scale;

  factory MonsterDef.fromJson(Map<String, dynamic> json) => MonsterDef(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    glyph: json['glyph'] as String? ?? '🌿',
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
  );
}

/// 한 스테이지에 등장할 몬스터 순서를 만든다. **결정론**(§5) — 같은
/// 스테이지는 언제 봐도 같은 순서다.
///
/// 예전 공식은 `(stage * 7 + index * 3) % 종류수` 였다. 주기가 딱 떨어져서
/// 20마리가 5개짜리 고리를 **정확히 네 번** 돌았다(풀숲 초원은 3종뿐이라
/// 같은 그림을 6~7번 봤다). 무작위가 아니라 **행진**이었던 것이다.
///
/// 대신 스테이지를 씨앗으로 목록을 섞어 이어 붙인다. 이어 붙이는 지점에서
/// 같은 게 연달아 오면 그 자리만 뒤로 밀어 **연속 중복을 없앤다** — 두 번
/// 연속으로 같은 몬스터가 나오는 게 단조로움의 가장 큰 원인이다.
List<String> monsterOrder({
  required List<String> ids,
  required int stageNumber,
  required int count,
}) {
  if (ids.isEmpty || count <= 0) return const [];
  if (ids.length == 1) return List.filled(count, ids.first);

  final rng = math.Random(stageNumber * 7919 + 13);
  final out = <String>[];
  while (out.length < count) {
    final chunk = [...ids]..shuffle(rng);
    // 이어 붙이는 자리에서 겹치면 다음 것과 바꾼다. 한 칸만 밀면 되므로
    // 다시 섞을 필요가 없다(다시 섞으면 무한 루프가 될 수 있다).
    if (out.isNotEmpty && chunk.first == out.last && chunk.length > 1) {
      final t = chunk[0];
      chunk[0] = chunk[1];
      chunk[1] = t;
    }
    out.addAll(chunk);
  }
  return out.sublist(0, count);
}

/// 이 자리에 엘리트가 나오는가. **결정론** — 같은 칸은 언제 와도 같다.
///
/// 시간·전역 난수로 굴리면 화면을 껐다 켤 때마다 달라져서, 놓친 엘리트를
/// 다시 만나려고 되돌아가는 행동이 성립하지 않는다.
///
/// 보스 자리에는 걸지 않는다 — 보스는 그 자체가 사건이고, 엘리트 보스는
/// 벽 앞에서 난이도를 두 번 곱한다.
bool isEliteAt({
  required int stageNumber,
  required int habitatIndex,
  required double chance,
  required bool boss,
}) {
  if (boss || chance <= 0) return false;
  if (chance >= 1) return true;
  return math.Random(
        stageNumber * 104729 + habitatIndex * 1299709,
      ).nextDouble() <
      chance;
}
