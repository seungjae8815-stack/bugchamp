import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';

import 'save_game.dart';

/// 요정 진행 규칙(docs/design_fairy.md) — **알 · 둥지 · 가속기 · 속성석 · 합성 · 레벨 · 뽑기 · 분해**.
///
/// 규칙이 여기 한 곳에만 있다(스킬과 같다). 지금은 [FairyState] 만 받고 젤리는 숫자로
/// 주고받는다 — 세이브 연결(2단계)은 이 함수들을 감싸기만 한다.
///
/// 시간은 인자로 받고(§5 결정론), 무작위도 주입된 [math.Random] 으로만 쓴다.

/// 요정 액션 결과. 실패면 [state] 가 null 이고 [error] 에 사유 키.
/// [jelly] = 이 액션이 쓴 젤리(호출부가 세이브에서 뺀다).
class FairyOp {
  const FairyOp.ok(
    FairyState this.state, {
    this.jelly = 0,
    this.extra = const {},
  }) : error = null;
  const FairyOp.fail(String this.error)
    : state = null,
      jelly = 0,
      extra = const {};

  final FairyState? state;
  final String? error;
  final int jelly;
  final Map<String, Object?> extra;

  bool get isOk => state != null;
}

/// 알을 넣는다. 요정함이 차면 **넘친 알은 가루로** 바꾼다(곤충 채집함 획득 차단과 달리
/// 버리지 않는다 — 보스 첫 처치처럼 한 번뿐인 알이 사라지면 클레임이 된다).
///
/// 알 자동 분해([FairyState.autoReleaseUpTo], 2026-10-06)가 켜져 있으면 그 등급 이하는 넣지 않고
/// 바로 분해 가루로 바꾼다. [autoRelease] 가 false 면 건너뛴다 — 상점에서 **골라 산** 알이 가루가 되면 안 된다.
/// 결과 `extra['overflowDust']` · `extra['overflowEggs']`(넘쳐 가루가 된 알 수) ·
/// `extra['autoDust']` · `extra['autoEggs']`(자동 분해된 알 수) · `extra['kept']`(실제로 들어간 알 등급).
FairyOp grantFairyEggs(
  FairyState s,
  FairyConfig cfg,
  List<FairyGrade> grades, {
  bool autoRelease = true,
}) {
  if (grades.isEmpty) return FairyOp.ok(s);
  final eggs = [...s.eggs];
  var seq = s.seq;
  var dust = s.dust;
  var overflow = 0;
  var overflowEggs = 0;
  var autoDust = 0;
  var autoEggs = 0;
  final kept = <FairyGrade>[];
  var used = s.boxUsed;
  final upTo = autoRelease ? s.autoReleaseUpTo : null;
  for (final g in grades) {
    if (upTo != null &&
        g.index <= upTo.index &&
        g.index <= kFairyAutoReleaseMax.index) {
      final d = cfg.releaseDust[g] ?? 0;
      dust += d;
      autoDust += d;
      autoEggs++;
      continue;
    }
    if (used >= cfg.boxCap) {
      final d = cfg.releaseDust[g] ?? 0;
      dust += d;
      overflow += d;
      overflowEggs++;
      continue;
    }
    seq++;
    eggs.add(FairyEgg(id: 'e$seq', grade: g));
    kept.add(g);
    used++;
  }
  return FairyOp.ok(
    s.copyWith(eggs: eggs, seq: seq, dust: dust),
    extra: {
      'overflowDust': overflow,
      'overflowEggs': overflowEggs,
      'autoDust': autoDust,
      'autoEggs': autoEggs,
      'kept': kept,
    },
  );
}

/// 알 자동 분해 등급을 정한다(null = 끔). [kFairyAutoReleaseMax] 위는 거절한다.
FairyOp setFairyAutoRelease(FairyState s, FairyGrade? upTo) {
  if (upTo == null) return FairyOp.ok(s.copyWith(clearAutoRelease: true));
  if (upTo.index > kFairyAutoReleaseMax.index) {
    return const FairyOp.fail('bad_grade');
  }
  return FairyOp.ok(s.copyWith(autoReleaseUpTo: upTo));
}

/// 둥지(1칸)에 알을 넣는다. [stoneSub] 가 있으면 그 속성석 1개를 쓴다
/// (원하는 **부가 능력치**가 나올 확률을 올린다).
///
/// 종류·부가는 **여기서 굴려 적어 둔다** — 꺼낼 때 굴리면 앱을 껐다 켜며 다시 굴릴 수 있다.
FairyOp placeFairyEgg(
  FairyState s,
  FairyConfig cfg,
  math.Random rng, {
  required String eggId,
  required DateTime now,
  String? stoneSub,
}) {
  if (s.nest != null) return const FairyOp.fail('nest_busy');
  final idx = s.eggs.indexWhere((e) => e.id == eggId);
  if (idx < 0) return const FairyOp.fail('no_egg');
  if (cfg.kinds.isEmpty || cfg.subWeight.isEmpty) {
    return const FairyOp.fail('off');
  }
  var stones = s.stones;
  if (stoneSub != null) {
    if (!cfg.subWeight.containsKey(stoneSub)) {
      return const FairyOp.fail('bad_sub');
    }
    if ((s.stones[stoneSub] ?? 0) <= 0) return const FairyOp.fail('no_stone');
    stones = _add(s.stones, stoneSub, -1);
  }
  final egg = s.eggs[idx];
  // 순서 고정(종류 → 부가 → 기본 개체값 → 부가 개체값) — 바꾸면 같은 seed 의 결과가 달라진다.
  final kind = cfg.rollKind(rng);
  final sub = cfg.rollSub(rng, stoneSub: stoneSub);
  final baseRoll = cfg.rollQuality(rng);
  final subRoll = cfg.rollQuality(rng);
  return FairyOp.ok(
    s.copyWith(
      eggs: [...s.eggs]..removeAt(idx),
      stones: stones,
      nest: FairyNest(
        eggId: egg.id,
        grade: egg.grade,
        kind: kind,
        sub: sub,
        baseRoll: baseRoll,
        subRoll: subRoll,
        endsAt: now.toUtc().add(cfg.hatchDuration(egg.grade)),
      ),
    ),
  );
}

/// 다 깬 알을 꺼낸다 → 레벨 1 요정. 도감에 적는다. 결과 `extra['fairy']`.
FairyOp collectFairyNest(FairyState s, {required DateTime now}) {
  final n = s.nest;
  if (n == null) return const FairyOp.fail('nest_empty');
  if (now.toUtc().isBefore(n.endsAt)) return const FairyOp.fail('not_ready');
  final seq = s.seq + 1;
  final f = Fairy(
    id: 'f$seq',
    kind: n.kind,
    grade: n.grade,
    sub: n.sub,
    baseRoll: n.baseRoll,
    subRoll: n.subRoll,
  );
  return FairyOp.ok(
    s.copyWith(
      fairies: [...s.fairies, f],
      clearNest: true,
      seq: seq,
      dex: _dexWith(s.dex, f),
    ),
    extra: {'fairy': f},
  );
}

/// 가속기를 젤리로 산다. ⚠️ 파는 것은 **시간**뿐이다(§2.8) — 둥지는 1칸 고정이고 칸을 팔지 않는다.
FairyOp buyFairyAccelerator(
  FairyState s,
  FairyConfig cfg, {
  required String accelId,
  required int count,
  required int jellyHave,
}) {
  final def = cfg.accelById(accelId);
  if (def == null) return const FairyOp.fail('bad_accel');
  if (count <= 0) return const FairyOp.fail('bad_count');
  final cost = def.jelly * count;
  if (jellyHave < cost) return const FairyOp.fail('not_enough_jelly');
  return FairyOp.ok(
    s.copyWith(accelerators: _add(s.accelerators, accelId, count)),
    jelly: cost,
  );
}

/// 가속기 1개를 둥지에 쓴다 — 남은 시간을 줄인다(지금 시각 아래로는 안 간다).
FairyOp useFairyAccelerator(
  FairyState s,
  FairyConfig cfg, {
  required String accelId,
  required DateTime now,
}) {
  final def = cfg.accelById(accelId);
  if (def == null) return const FairyOp.fail('bad_accel');
  final n = s.nest;
  if (n == null) return const FairyOp.fail('nest_empty');
  final t = now.toUtc();
  if (!t.isBefore(n.endsAt)) return const FairyOp.fail('already_ready');
  if ((s.accelerators[accelId] ?? 0) <= 0) {
    return const FairyOp.fail('no_accel');
  }
  var ends = n.endsAt.subtract(Duration(minutes: def.minutes));
  if (ends.isBefore(t)) ends = t;
  return FairyOp.ok(
    s.copyWith(
      accelerators: _add(s.accelerators, accelId, -1),
      nest: n.copyWith(endsAt: ends),
    ),
  );
}

/// 속성석(부가 능력치 하나를 노리는 돌)을 젤리로 산다.
/// 길드 상점·드롭으로도 얻는다 — 무료 경로가 있어야 시간 판매다(§2.8).
FairyOp buyFairyStone(
  FairyState s,
  FairyConfig cfg, {
  required String sub,
  required int count,
  required int jellyHave,
}) {
  if (!cfg.subWeight.containsKey(sub)) return const FairyOp.fail('bad_sub');
  if (count <= 0) return const FairyOp.fail('bad_count');
  final cost = cfg.stoneJelly * count;
  if (jellyHave < cost) return const FairyOp.fail('not_enough_jelly');
  return FairyOp.ok(
    s.copyWith(stones: _add(s.stones, sub, count)),
    jelly: cost,
  );
}

/// 속성석·가속기·가루를 그냥 넣는다(보상·상점 지급용).
FairyState grantFairyItems(
  FairyState s, {
  Map<String, int> stones = const {},
  Map<String, int> accelerators = const {},
  int dust = 0,
}) {
  var st = s.stones;
  for (final e in stones.entries) {
    if (e.value > 0) st = _add(st, e.key, e.value);
  }
  var ac = s.accelerators;
  for (final e in accelerators.entries) {
    if (e.value > 0) ac = _add(ac, e.key, e.value);
  }
  return s.copyWith(
    stones: st,
    accelerators: ac,
    dust: s.dust + math.max(0, dust),
  );
}

/// 자동 합성 재료로 쓸 수 있나 — 동행 중·레벨 2 이상(투자한 요정)은 빠진다
/// (곤충 자동 합성과 같은 원칙: 투자한 개체가 조용히 사라지면 클레임).
bool fairyIsFodder(FairyState s, Fairy f) =>
    f.id != s.companionId && f.level <= 1 && f.id != s.reroll?.fairyId;

/// 같은 종류·같은 등급 [FairyConfig.mergeCountOf] 마리 → 한 등급 위 1마리(등급 오름은 확정).
/// 마릿수는 재료 등급마다 다를 수 있다(2026-10-04: 영웅 → 전설만 4마리).
///
/// **결과는 새로 굴린다**(2026-10-01 사장님 확정) — 종류는 재료와 같고, 기본 개체값·부가 능력치(종류)·
/// 부가 개체값은 새 등급 범위에서 다시 굴린다. 합성할 때마다 좋은 개체를 노리는 뽑기가 된다.
/// 순서 고정(부가 → 기본 개체값 → 부가 개체값, 둥지 부화와 같다) — 바꾸면 같은 seed 의 결과가 달라진다.
///
/// 직접 고른 것이라 레벨 2 이상도 허용한다(쓴 가루 일부 환급). 동행 중은 안 된다.
/// 결과 `extra['fairy']` · `extra['refund']`.
FairyOp mergeFairies(
  FairyState s,
  FairyConfig cfg,
  List<String> ids,
  math.Random rng,
) {
  if (ids.isEmpty || ids.toSet().length != ids.length) {
    return const FairyOp.fail('bad_count');
  }
  final picked = <Fairy>[];
  for (final id in ids) {
    final f = s.fairyById(id);
    if (f == null) return const FairyOp.fail('no_fairy');
    if (f.id == s.companionId) return const FairyOp.fail('companion');
    picked.add(f);
  }
  final first = picked.first;
  if (picked.any((f) => f.kind != first.kind || f.grade != first.grade)) {
    return const FairyOp.fail('mismatch');
  }
  if (ids.length != cfg.mergeCountOf(first.grade)) {
    return const FairyOp.fail('bad_count');
  }
  final up = first.grade.next;
  if (up == null) return const FairyOp.fail('max_grade');
  if (cfg.subWeight.isEmpty) return const FairyOp.fail('off');
  final refund = _refund(cfg, picked);
  final seq = s.seq + 1;
  final sub = cfg.rollSub(rng);
  final baseRoll = cfg.rollQuality(rng);
  final subRoll = cfg.rollQuality(rng);
  final made = Fairy(
    id: 'f$seq',
    kind: first.kind,
    grade: up,
    sub: sub,
    baseRoll: baseRoll,
    subRoll: subRoll,
  );
  final gone = ids.toSet();
  return FairyOp.ok(
    s.copyWith(
      fairies: [
        for (final f in s.fairies)
          if (!gone.contains(f.id)) f,
        made,
      ],
      seq: seq,
      dust: s.dust + refund,
      dex: _dexWith(s.dex, made),
    ),
    extra: {'fairy': made, 'refund': refund},
  );
}

/// 자동 합성 — 재료가 되는 요정([fairyIsFodder])만 **같은 종류·등급끼리** 묶어 끝까지(연쇄) 합친다.
/// 결과는 어차피 새로 굴리므로 **품질 낮은 것부터** 태운다 — 셋으로 안 나눠떨어지면 좋은 개체가 남는다.
/// [dryRun] 이면 상태를 바꾸지 않고 예상(몇 마리를 써서 몇 마리가 되나)만 준다(실행 전 확인 — §2.7).
/// 결과 `extra['made']`(남는 요정 List<Fairy>) · `extra['used']`(재료 수).
FairyOp autoMergeFairies(
  FairyState s,
  FairyConfig cfg,
  math.Random rng, {
  bool dryRun = false,
}) {
  var cur = s;
  final made = <Fairy>[];
  var used = 0;
  while (true) {
    final groups = <String, List<Fairy>>{};
    for (final f in cur.fairies) {
      if (!fairyIsFodder(cur, f) || f.grade.next == null) continue;
      if (cfg.mergeCountOf(f.grade) <= 0) continue;
      groups.putIfAbsent('${f.kind}|${f.grade.index}', () => []).add(f);
    }
    final ready = groups.values.where(
      (g) => g.length >= cfg.mergeCountOf(g.first.grade),
    );
    if (ready.isEmpty) break;
    final before = made.length;
    for (final g in ready.toList()) {
      final need = cfg.mergeCountOf(g.first.grade);
      g.sort((a, b) => a.quality.compareTo(b.quality));
      final op = mergeFairies(cur, cfg, [
        for (final f in g.take(need)) f.id,
      ], rng);
      if (!op.isOk) continue;
      cur = op.state!;
      made.add(op.extra['fairy']! as Fairy);
      used += need;
    }
    if (made.length == before) break; // 진행이 없으면 멈춘다(무한 반복 방지).
  }
  // 연쇄 중간 산물은 결과에서 뺀다 — 화면엔 **남는 것**만 보여 준다.
  final alive = {for (final f in cur.fairies) f.id};
  final result = [
    for (final f in made)
      if (alive.contains(f.id)) f,
  ];
  // 화면에 보이는 "몇 마리를 합치나" = **원래 있던 요정 중 사라지는 수**(연쇄 중간 산물은 빼야
  // 일반 9 → 영웅 1 이 "12마리"로 부풀지 않는다, 2026-10-01 점검).
  used = s.fairies.where((f) => !alive.contains(f.id)).length;
  return FairyOp.ok(dryRun ? s : cur, extra: {'made': result, 'used': used});
}

/// 재굴림(2026-10-04, 조정안 C) — 가진 요정의 **부가 능력치·개체값을 새로 굴려 대기 결과로 적는다.**
/// 요정은 아직 그대로다 — [chooseFairyReroll] 로 새 값/원래 값을 고른다(나빠지지 않는다).
///
/// ⚠️ **서버만 부른다**(`/fairy/reroll`). 기기에서 굴리면 서버의 정체 고정(`_keepFairyIdentity`)이 되돌리고,
/// 그 고정을 풀면 개체값 위조가 열린다. 하루 횟수([today] = KST 날짜 키)도 서버가 센다.
/// 굴리는 순서는 합성과 같다(부가 → 기본 개체값 → 부가 개체값). 결과 `extra['reroll']`.
FairyOp rollFairyReroll(
  FairyState s,
  FairyConfig cfg,
  math.Random rng, {
  required String fairyId,
  required String today,
  required int jellyHave,
}) {
  if (cfg.rerollJelly <= 0 ||
      cfg.rerollDailyCap <= 0 ||
      cfg.subWeight.isEmpty) {
    return const FairyOp.fail('off');
  }
  if (s.reroll != null) return const FairyOp.fail('reroll_pending');
  if (s.fairyById(fairyId) == null) return const FairyOp.fail('no_fairy');
  final used = s.rerollDay == today ? s.rerollCount : 0;
  if (used >= cfg.rerollDailyCap) return const FairyOp.fail('reroll_cap');
  if (jellyHave < cfg.rerollJelly)
    return const FairyOp.fail('not_enough_jelly');
  final r = FairyReroll(
    fairyId: fairyId,
    sub: cfg.rollSub(rng),
    baseRoll: cfg.rollQuality(rng),
    subRoll: cfg.rollQuality(rng),
  );
  return FairyOp.ok(
    s.copyWith(reroll: r, rerollDay: today, rerollCount: used + 1),
    jelly: cfg.rerollJelly,
    extra: {'reroll': r},
  );
}

/// 재굴림 결과를 고른다 — [accept] 면 새 부가·개체값으로 바꾸고(레벨·등급·종류는 그대로), 아니면 원래 값을 지킨다.
/// 어느 쪽이든 대기 결과를 지운다. 그 사이 요정이 사라졌으면(합성·분해) 대기만 지운다. 서버가 부른다.
FairyOp chooseFairyReroll(FairyState s, {required bool accept}) {
  final r = s.reroll;
  if (r == null) return const FairyOp.fail('no_reroll');
  final f = s.fairyById(r.fairyId);
  if (!accept || f == null) return FairyOp.ok(s.copyWith(clearReroll: true));
  final made = Fairy(
    id: f.id,
    kind: f.kind,
    grade: f.grade,
    sub: r.sub,
    baseRoll: r.baseRoll,
    subRoll: r.subRoll,
    level: f.level,
  );
  return FairyOp.ok(
    s.copyWith(
      fairies: [for (final x in s.fairies) x.id == f.id ? made : x],
      clearReroll: true,
      dex: _dexWith(s.dex, made),
    ),
    extra: {'fairy': made},
  );
}

/// 레벨 +1(요정 가루). 골드는 쓰지 않는다(회차마다 초기화 — 스킬과 같은 이유).
FairyOp levelUpFairy(FairyState s, FairyConfig cfg, String id) {
  final f = s.fairyById(id);
  if (f == null) return const FairyOp.fail('no_fairy');
  if (f.level >= cfg.maxLevelOf(f.grade)) {
    return const FairyOp.fail('max_level');
  }
  final cost = cfg.levelCost(f.grade, f.level);
  if (s.dust < cost) return const FairyOp.fail('not_enough_dust');
  return FairyOp.ok(
    s.copyWith(
      fairies: [
        for (final x in s.fairies)
          x.id == id ? x.copyWith(level: x.level + 1) : x,
      ],
      dust: s.dust - cost,
    ),
  );
}

/// 동행 요정을 정한다. null 이면 해제.
FairyOp setFairyCompanion(FairyState s, String? id) {
  if (id == null) return FairyOp.ok(s.copyWith(clearCompanion: true));
  if (s.fairyById(id) == null) return const FairyOp.fail('no_fairy');
  return FairyOp.ok(s.copyWith(companionId: id));
}

/// 분해 → 요정 가루(등급 가루 + 쓴 레벨업 가루 환급). ❌ 젤리 없음.
FairyOp releaseFairy(FairyState s, FairyConfig cfg, String id) {
  final f = s.fairyById(id);
  if (f == null) return const FairyOp.fail('no_fairy');
  if (f.id == s.companionId) return const FairyOp.fail('companion');
  final got = (cfg.releaseDust[f.grade] ?? 0) + _refund(cfg, [f]);
  return FairyOp.ok(
    s.copyWith(
      fairies: [
        for (final x in s.fairies)
          if (x.id != id) x,
      ],
      dust: s.dust + got,
    ),
    extra: {'dust': got},
  );
}

/// 여러 개를 한 번에 분해(2026-10-06 사장님 — 분해 창) — 요정 [fairyIds] + 알 [eggIds] → 요정 가루.
/// 요정 하나하나는 [releaseFairy] 와 같은 가루(등급 가루 + 레벨업 환급), 알은 등급 가루. ❌ 젤리 없음.
/// 동행 중이거나 없는 것이 하나라도 끼면 통째로 거절한다(일부만 사라지면 화면과 어긋난다).
/// 결과 `extra['dust']`.
FairyOp releaseFairiesBulk(
  FairyState s,
  FairyConfig cfg, {
  List<String> fairyIds = const [],
  List<String> eggIds = const [],
}) {
  final fIds = fairyIds.toSet();
  final eIds = eggIds.toSet();
  if (fIds.isEmpty && eIds.isEmpty) return const FairyOp.fail('bad_count');
  if (fIds.length != fairyIds.length || eIds.length != eggIds.length) {
    return const FairyOp.fail('bad_count');
  }
  if (s.companionId != null && fIds.contains(s.companionId)) {
    return const FairyOp.fail('companion');
  }
  var got = 0;
  var found = 0;
  for (final f in s.fairies) {
    if (!fIds.contains(f.id)) continue;
    found++;
    got += (cfg.releaseDust[f.grade] ?? 0) + _refund(cfg, [f]);
  }
  if (found != fIds.length) return const FairyOp.fail('no_fairy');
  found = 0;
  for (final e in s.eggs) {
    if (!eIds.contains(e.id)) continue;
    found++;
    got += cfg.releaseDust[e.grade] ?? 0;
  }
  if (found != eIds.length) return const FairyOp.fail('no_egg');
  return FairyOp.ok(
    s.copyWith(
      fairies: [
        for (final x in s.fairies)
          if (!fIds.contains(x.id)) x,
      ],
      eggs: [
        for (final e in s.eggs)
          if (!eIds.contains(e.id)) e,
      ],
      dust: s.dust + got,
    ),
    extra: {'dust': got},
  );
}

/// 요정 알 뽑기 [times] 회(젤리). 천장: [FairyConfig.gachaPity] 회째는 천장 등급 이상 확정,
/// **천장 등급이 나왔을 때만** 카운터를 되감는다(알 뽑기·스킬 뽑기와 같다).
/// 결과 `extra['grades']` · `extra['overflowDust']`.
FairyOp drawFairyEggs(
  FairyState s,
  FairyConfig cfg,
  math.Random rng, {
  required int times,
  required int jellyHave,
}) {
  if (times <= 0 || cfg.gachaWeights.isEmpty) {
    return const FairyOp.fail('off');
  }
  final cost = cfg.gachaJelly * times;
  if (jellyHave < cost) return const FairyOp.fail('not_enough_jelly');
  var pity = s.gachaPity;
  final grades = <FairyGrade>[];
  for (var i = 0; i < times; i++) {
    final due = cfg.gachaPity > 0 && pity >= cfg.gachaPity - 1;
    final g = cfg.rollGacha(rng, pityDue: due);
    if (g == null) return const FairyOp.fail('off');
    pity = g.index >= cfg.gachaPityGrade.index ? 0 : pity + 1;
    grades.add(g);
  }
  final op = grantFairyEggs(s.copyWith(gachaPity: pity), cfg, grades);
  return FairyOp.ok(
    op.state!,
    jelly: cost,
    extra: {
      'grades': grades,
      'overflowDust': op.extra['overflowDust'],
      'overflowEggs': op.extra['overflowEggs'],
      'autoDust': op.extra['autoDust'],
      'autoEggs': op.extra['autoEggs'],
      'kept': op.extra['kept'],
    },
  );
}

/// 동행 요정의 능력치(없으면 빈 맵). 방치 런 반영은 3단계(`applyFairy`).
Map<String, double> fairyCompanionBonus(FairyState s, FairyConfig cfg) {
  final f = s.companion;
  return f == null ? const {} : cfg.statBonus(f);
}

/// 도감에 두 축을 적는다 — 등급(`종류:등급`)과 부가(`종류+부가`).
Set<String> _dexWith(Set<String> dex, Fairy f) => {
  ...dex,
  FairyState.dexKey(f.kind, f.grade),
  FairyState.dexSubKey(f.kind, f.sub),
};

int _refund(FairyConfig cfg, List<Fairy> fs) => fs.fold<int>(
  0,
  (a, f) =>
      a + (cfg.dustSpentTo(f.grade, f.level) * cfg.mergeDustRefund).floor(),
);

Map<String, int> _add(Map<String, int> m, String key, int delta) {
  final out = Map<String, int>.from(m);
  final v = (out[key] ?? 0) + delta;
  if (v > 0) {
    out[key] = v;
  } else {
    out.remove(key);
  }
  return out;
}

/// 등급 가치 — 일반 1 · 희귀 3 · 영웅 9 · 전설 27 · 신화 81.
///
/// 합성은 같은 등급 3마리를 한 등급 위 1마리로 바꾸므로 **총합이 변하지 않는다**
/// (영웅 → 전설 4마리 합성은 36 → 27 로 **줄어든다** — 늘지 않는다는 성질은 그대로).
/// 분해·넘침은 줄이기만 한다. 그래서 총합이 늘었다면 새 알이 들어온 것뿐이다 —
/// 서버가 업로드에서 "알 없이 신화가 생겼다"를 이 값 하나로 잡는다.
int fairyGradeValue(FairyGrade g) => math.pow(3, g.index).toInt();

/// 요정 + 알 + 둥지 속 알의 등급 가치 합.
int fairyStateValue(FairyState s) =>
    s.fairies.fold<int>(0, (a, f) => a + fairyGradeValue(f.grade)) +
    s.eggs.fold<int>(0, (a, e) => a + fairyGradeValue(e.grade)) +
    (s.nest == null ? 0 : fairyGradeValue(s.nest!.grade));

/// 규칙 상한 정리 — **앱 로드와 서버 업로드가 같은 함수**를 쓴다.
///
/// - 레벨은 등급 상한까지.
/// - 요정함 상한([FairyConfig.boxCap])을 넘으면 알부터, 그다음 **등급 → 레벨 → 품질이 낮은 요정부터**
///   가루로 바꾼다(분해와 같은 가루 + 레벨업 환급, 동행 요정은 남긴다). 품질만 보던 시절엔 품질 낮은
///   신화 50레벨이 일반보다 먼저 사라질 수 있었다(2026-10-01 점검). 세이브 크기 방어선(§2.1).
FairyState enforceFairyRules(FairyState s, FairyConfig cfg) {
  var fairies = [
    for (final f in s.fairies)
      f.level > cfg.maxLevelOf(f.grade)
          ? f.copyWith(level: cfg.maxLevelOf(f.grade))
          : f,
  ];
  var eggs = [...s.eggs];
  var dust = s.dust;
  var over = s.boxUsed - cfg.boxCap;
  while (over > 0 && eggs.isNotEmpty) {
    dust += cfg.releaseDust[eggs.removeLast().grade] ?? 0;
    over--;
  }
  if (over > 0) {
    final order =
        [
          for (final f in fairies)
            if (f.id != s.companionId) f,
        ]..sort((a, b) {
          final g = a.grade.index.compareTo(b.grade.index);
          if (g != 0) return g;
          final lv = a.level.compareTo(b.level);
          return lv != 0 ? lv : a.quality.compareTo(b.quality);
        });
    final gone = <String>{};
    for (final f in order.take(over)) {
      gone.add(f.id);
      dust += (cfg.releaseDust[f.grade] ?? 0) + _refund(cfg, [f]);
    }
    fairies = [
      for (final f in fairies)
        if (!gone.contains(f.id)) f,
    ];
  }
  return s.copyWith(fairies: fairies, eggs: eggs, dust: dust);
}

/// 보스 처치 요정 드롭 — **첫 처치만** 난이도별 알 1개 확정 + 무작위 속성석(§2.8 무료 경로).
/// 다시 잡으면 없다(아래 사냥터 보스를 도는 게 앞으로 가는 것보다 좋아지지 않게 — 스킬 조각과 같은 이유).
/// 결과 `extra['eggs']`(List<FairyGrade>) · `extra['stones']`(부가 키 → 개수).
FairyOp fairyBossDrop(
  FairyState s,
  FairyConfig cfg,
  math.Random rng, {
  required int tier,
  required bool firstKill,
}) {
  final d = cfg.drops;
  final grade = firstKill ? d.bossFirstEggGrade(tier) : null;
  if (grade == null)
    return FairyOp.ok(s, extra: const {'eggs': <FairyGrade>[]});
  final granted = grantFairyEggs(s, cfg, [grade]);
  var out = granted.state!;
  final stones = <String, int>{};
  final subs = cfg.subWeight.keys.toList();
  for (var i = 0; i < d.bossFirstStones && subs.isNotEmpty; i++) {
    final k = subs[rng.nextInt(subs.length)];
    stones[k] = (stones[k] ?? 0) + 1;
  }
  out = grantFairyItems(out, stones: stones);
  return FairyOp.ok(
    out,
    extra: {
      'eggs': [grade],
      'stones': stones,
      // 요정함이 차서 알 대신 가루가 됐으면 화면이 그렇게 말해야 한다(2026-10-01 점검 — 알 팝업이 떴다).
      'overflowDust': granted.extra['overflowDust'],
      'overflowEggs': granted.extra['overflowEggs'],
      'autoDust': granted.extra['autoDust'],
      'autoEggs': granted.extra['autoEggs'],
    },
  );
}

/// 정예 처치 요정 드롭(확률) — 알 · 속성석 · 가속기. 결과 `extra` 는 [fairyBossDrop] 과 같고 `accel` 이 더 있다.
///
/// 굴리는 순서 고정(알 → 속성석 → 가속기) — 바꾸면 같은 seed 의 결과가 달라진다.
FairyOp fairyEliteDrop(FairyState s, FairyConfig cfg, math.Random rng) {
  final d = cfg.drops;
  final eggs = <FairyGrade>[];
  if (rng.nextDouble() < d.eliteEggChance) {
    final g = d.rollEliteEgg(rng);
    if (g != null) eggs.add(g);
  }
  final stones = <String, int>{};
  final subs = cfg.subWeight.keys.toList();
  if (rng.nextDouble() < d.eliteStoneChance && subs.isNotEmpty) {
    stones[subs[rng.nextInt(subs.length)]] = 1;
  }
  final accel = d.eliteAccelId;
  final gotAccel =
      rng.nextDouble() < d.eliteAccelChance &&
      accel != null &&
      cfg.accelById(accel) != null;
  if (eggs.isEmpty && stones.isEmpty && !gotAccel) {
    return FairyOp.ok(s, extra: const {'eggs': <FairyGrade>[]});
  }
  final granted = eggs.isEmpty ? null : grantFairyEggs(s, cfg, eggs);
  var out = granted?.state ?? s;
  out = grantFairyItems(
    out,
    stones: stones,
    accelerators: gotAccel ? {accel: 1} : const {},
  );
  return FairyOp.ok(
    out,
    extra: {
      'eggs': eggs,
      'stones': stones,
      if (gotAccel) 'accel': accel,
      'overflowDust': granted?.extra['overflowDust'] ?? 0,
      'overflowEggs': granted?.extra['overflowEggs'] ?? 0,
      'autoDust': granted?.extra['autoDust'] ?? 0,
      'autoEggs': granted?.extra['autoEggs'] ?? 0,
    },
  );
}

/// 요정 도감에 모은 칸 수(등급 + 부가). 모르는 키는 서버가 이미 버린다.
int fairyDexCount(FairyState s) => s.dex.length;

/// 지금 받을 수 있는 다음 도감 마일스톤(없으면 null).
FairyDexMilestone? fairyDexNext(FairyState s, FairyConfig cfg) {
  if (s.dexClaimed >= cfg.dexMilestones.length) return null;
  final m = cfg.dexMilestones[s.dexClaimed];
  return fairyDexCount(s) >= m.count ? m : null;
}

/// 도감 마일스톤 하나를 받는다 — 요정 가루·가속기는 요정 상태에, 화석은 재료에. 못 받으면 null.
/// 앱(받기 버튼)·서버(허용치 계산)가 같은 표를 본다.
SaveGame? claimFairyDexMilestone(SaveGame save, FairyConfig cfg) {
  final m = fairyDexNext(save.fairy, cfg);
  if (m == null) return null;
  final f = grantFairyItems(
    save.fairy,
    accelerators: m.accelerators,
    dust: m.dust,
  ).copyWith(dexClaimed: save.fairy.dexClaimed + 1);
  return save.copyWith(
    fairy: f,
    materials: m.fossil <= 0
        ? null
        : {
            ...save.materials,
            MaterialKind.fossil:
                save.materialCount(MaterialKind.fossil) + m.fossil,
          },
  );
}

/// 저장본 → 올라온 세이브 사이에 **새로 받은** 도감 마일스톤(서버 허용치용). 올라온 세이브의 도감 칸 수가
/// 실제로 닿은 것만 센다 — 받은 수를 부풀려도 칸이 모자라면 인정하지 않는다.
List<FairyDexMilestone> fairyDexNewlyClaimed(
  FairyState stored,
  FairyState client,
  FairyConfig cfg,
) => [
  for (
    var i = stored.dexClaimed;
    i < client.dexClaimed && i < cfg.dexMilestones.length;
    i++
  )
    if (fairyDexCount(client) >= cfg.dexMilestones[i].count)
      cfg.dexMilestones[i],
];
