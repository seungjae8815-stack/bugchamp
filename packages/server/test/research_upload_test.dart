// 연구소 업로드 검증(설계 §3.9) — 연구 레벨은 결투에 실리므로 서버가 업로드마다 레벨 증가를 자른다.
//
// 허용 = 경과 × 열린 칸 수 + 이번 업로드에서 줄어든 젤리로 설명되는 즉시 완료 + 저장본 진행 칸의 남은 몫 + 1분.
// 넘치면 연구 필드(rsL·rsS·rsB) 전체를 저장본으로. 표본(rsC) 급증·칸 구매(rsB)는 따로 자른다.
// 구버전(feat 27) 업로드는 연구 필드를 저장본 값으로 지킨다 · 연구 패스 만료는 서버 소유.
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

final t0 = DateTime.utc(2026, 10, 22, 12);

void main() {
  late GameConfig cfg;
  late GameActions actions;
  late ResearchConfig rc;
  late ResearchDef jaw;

  setUpAll(() async {
    cfg = await GameConfig.load(dir: '../app/assets/data');
    actions = GameActions(config: cfg, now: () => t0);
    rc = cfg.research!;
    jaw = rc.byId('jaw')!;
  });

  SaveGame stored({
    Duration elapsed = const Duration(seconds: 60),
    Map<String, int> levels = const {},
    List<ResearchSlot> slots = const [],
    int samples = 50,
    int bought = 0,
    int jelly = 1000,
    DateTime? passUntil,
  }) => SaveGame.initial(createdAt: t0.subtract(const Duration(days: 40)))
      .copyWith(
        lastSeen: t0.subtract(elapsed),
        researchLevels: levels,
        researchSlots: slots,
        researchSamples: samples,
        researchSlotsBought: bought,
        materials: {MaterialKind.jelly: jelly},
        researchPassExpiresAt: passUntil,
      );

  SaveGame up(SaveGame s, Map<String, dynamic> json) {
    final r = actions.mergeSave(s, json);
    expect(r.isOk, isTrue, reason: r.error);
    return r.save!;
  }

  List<String> reasons(SaveGame s, Map<String, dynamic> json) => [
    for (final e
        in (actions.mergeSave(s, json).extra['clampReasons'] as List? ??
            const []))
      '$e',
  ];

  Duration timeSum(int from, int to) {
    var d = Duration.zero;
    for (var lv = from + 1; lv <= to; lv++) {
      d += rc.timeAt(jaw, lv);
    }
    return d;
  }

  test('old_app_upload_keeps_research — feat 27 업로드는 연구 필드를 몰라 저장본 값을 지킨다', () {
    final s = stored(
      levels: {'jaw': 5},
      slots: [
        ResearchSlot(
          id: 'shell',
          level: 1,
          endsAt: t0.add(const Duration(hours: 1)),
        ),
      ],
      samples: 40,
      bought: 1,
    );
    final json = s.copyWith(researchLevels: const {}).toJson()
      ..['feat'] = 27
      ..remove('rsL')
      ..remove('rsS')
      ..remove('rsC')
      ..remove('rsB');
    final out = up(s, json);
    expect(out.researchLevels, {'jaw': 5});
    expect(out.researchSlots.single.id, 'shell');
    expect(out.researchSamples, 40);
    expect(out.researchSlotsBought, 1);
  });

  test('clock_forward_upload_is_clamped — 1분 경과에 Lv20 이면 연구 필드 전체를 저장본으로', () {
    final s = stored(levels: {'jaw': 1});
    final json = s
        .copyWith(
          researchLevels: {'jaw': 20},
          researchSlots: [
            ResearchSlot(
              id: 'shell',
              level: 1,
              endsAt: t0.add(const Duration(seconds: 1)),
            ),
          ],
        )
        .toJson();
    final out = up(s, json);
    expect(out.researchLevels, {'jaw': 1});
    expect(out.researchSlots, isEmpty);
    expect(reasons(s, json), contains('research'));
  });

  test('상한에 걸리면 무엇을 되돌렸는지 상세를 남긴다(2026-10-27 운영 요약)', () {
    final s = stored(levels: {'jaw': 1});
    final json = s.copyWith(researchLevels: {'jaw': 20}).toJson();
    final r = actions.mergeSave(s, json);
    final d = (r.extra['clampDetail'] as Map?)?['research']?.toString() ?? '';
    expect(d, contains('jaw 20→1'));
    expect(d, contains('시간·젤리 판정 실패'));
  });

  test('끝났지만 아직 안 받은 칸(연구 완료 버튼 전)은 업로드마다 그대로 남아도 걸리지 않는다', () {
    final slot = ResearchSlot(
      id: 'jaw',
      level: 3,
      endsAt: t0.subtract(const Duration(hours: 5)),
    );
    final s = stored(levels: {'jaw': 2}, slots: [slot]);
    final json = s.toJson();
    expect(reasons(s, json), isNot(contains('research')));
    final out = up(s, json);
    expect(out.researchSlots.single.id, 'jaw');
    expect(out.researchLevels['jaw'], 2);
    // 나중에 받으면(레벨 3 · 칸 비움) 그것도 그대로 인정.
    final claimed = s
        .copyWith(researchLevels: {'jaw': 3}, researchSlots: const [])
        .toJson();
    expect(reasons(s, claimed), isNot(contains('research')));
    expect(up(s, claimed).researchLevels['jaw'], 3);
  });

  test('clock_forward — 끝나기 직전으로 위조한 진행 칸도 이미 흐른 몫을 센다', () {
    final s = stored(levels: {'jaw': 4});
    // 1분 경과인데 Lv5 칸이 1초 남았다 = 그 레벨 시간이 다 흘렀다는 주장(시계 어긋남 여유로는 모자란다).
    final json = s
        .copyWith(
          researchSlots: [
            ResearchSlot(
              id: 'jaw',
              level: 5,
              endsAt: t0.add(const Duration(seconds: 1)),
            ),
          ],
        )
        .toJson();
    expect(up(s, json).researchSlots, isEmpty);
  });

  test('honest_progress_accepted — 경과 시간 안의 레벨업·새 진행 칸은 인정', () {
    final need = timeSum(0, 2);
    final s = stored(elapsed: need);
    final json = s
        .copyWith(
          researchLevels: {'jaw': 2},
          researchSlots: [
            // 방금 시작한 칸(흐른 몫 0).
            ResearchSlot(
              id: 'barter',
              level: 1,
              endsAt: t0.add(rc.timeAt(rc.byId('barter')!, 1)),
            ),
          ],
        )
        .toJson();
    final out = up(s, json);
    expect(out.researchLevels['jaw'], 2);
    expect(out.researchSlots.single.id, 'barter');
    expect(reasons(s, json), isNot(contains('research')));
  });

  test('honest — 저장본에서 진행 중이던 칸은 남은 몫만 센다', () {
    final s = stored(
      slots: [
        ResearchSlot(
          id: 'jaw',
          level: 1,
          endsAt: t0.subtract(const Duration(seconds: 30)),
        ),
      ],
    );
    final out = up(
      s,
      s.copyWith(researchLevels: {'jaw': 1}, researchSlots: const []).toJson(),
    );
    expect(out.researchLevels['jaw'], 1);
  });

  test('jelly_finish_accepted — 저장본 진행 칸 하나를 젤리로 끝낸 만큼 인정, 젤리가 안 줄었으면 되돌림', () {
    // 저장본에 Lv3 진행 칸 — 60초 뒤 남은 몫을 젤리로 끝냈다.
    final full = rc.timeAt(jaw, 3);
    final s = stored(
      levels: {'jaw': 2},
      slots: [
        ResearchSlot(
          id: 'jaw',
          level: 3,
          endsAt: t0.subtract(const Duration(seconds: 60)).add(full),
        ),
      ],
    );
    final cost = rc.instantJelly(full - const Duration(seconds: 60));
    final finished = s.copyWith(
      researchLevels: {'jaw': 3},
      researchSlots: const [],
    );
    final ok = up(
      s,
      finished.copyWith(materials: {MaterialKind.jelly: 1000 - cost}).toJson(),
    );
    expect(ok.researchLevels['jaw'], 3);
    final bad = up(s, finished.toJson());
    expect(bad.researchLevels['jaw'], 2);
  });

  test('젤리 300 이 줄고 20 레벨 — 레벨마다 즉시 완료 값을 매겨 되돌림', () {
    final s = stored(jelly: 1000);
    final out = up(
      s,
      s
          .copyWith(
            researchLevels: {'jaw': 20},
            materials: const {MaterialKind.jelly: 700},
          )
          .toJson(),
    );
    expect(out.researchLevels['jaw'], isNull);
  });

  test('다른 곳(알 뽑기)에 쓴 젤리는 연구 즉시 완료에 다시 쓰지 못한다', () {
    final full = rc.timeAt(jaw, 3);
    final s = stored(
      levels: {'jaw': 2},
      slots: [
        ResearchSlot(
          id: 'jaw',
          level: 3,
          endsAt: t0.subtract(const Duration(seconds: 60)).add(full),
        ),
      ],
    );
    final cost = rc.instantJelly(full - const Duration(seconds: 60));
    final price = cfg.pet.gachaJellyCost;
    final eggs = (cost / price).ceil();
    final gacha = [
      for (var i = 0; i < eggs; i++)
        IndividualBug(
          id: 'g$i',
          speciesId: 'stag_giant',
          sizeMm: 50,
          potential: 3,
          temperament: Temperament.steadfast,
          sex: Sex.male,
          element: Element.wood,
          stage: LifeStage.egg,
          stageSince: t0,
          fromGacha: true,
        ),
    ];
    // 뽑기에 젤리를 다 쓰고, 연구도 젤리로 끝냈다고 주장.
    final out = up(
      s,
      s
          .copyWith(
            bugs: gacha,
            researchLevels: {'jaw': 3},
            researchSlots: const [],
            materials: {MaterialKind.jelly: 1000 - eggs * price},
          )
          .toJson(),
    );
    expect(out.researchLevels['jaw'], 2);
  });

  test('칸 구매 — 낸 젤리(+ 같은 업로드의 기기 젤리 수입)만큼, 2칸까지', () {
    final s = stored(jelly: 1000);
    final paid = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 1,
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[0]},
          )
          .toJson(),
    );
    expect(paid.researchSlotsBought, 1);
    // 같은 업로드에 미션 젤리 — 순감소가 칸 값보다 작아도 받은 흔적(dailyClaims 미션 날짜)이 있으면 산 칸은 남는다.
    final forge = cfg.mission!.missions.firstWhere((m) => m.id == 'forge');
    final gain = forge.rewardAt(1);
    expect(gain, greaterThan(0));
    final withGain = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 1,
            missionClaims: {'forge': 1},
            dailyClaims: {missionJellyKey('forge', 0): dailyDateKey(t0)},
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[0] + gain},
          )
          .toJson(),
    );
    expect(withGain.researchSlotsBought, 1);
    // 흔적 없이 순감소가 모자라면 저장본.
    final noProof = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 1,
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[0] + gain},
          )
          .toJson(),
    );
    expect(noProof.researchSlotsBought, 0);
    // 두 칸(400)을 젤리 없이 — 업로드 젤리 증가 허용치로도 설명이 안 된다.
    final free = up(s, s.copyWith(researchSlotsBought: 2).toJson());
    expect(free.researchSlotsBought, 0);
    final over = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 9,
            materials: const {MaterialKind.jelly: 0},
          )
          .toJson(),
    );
    expect(over.researchSlotsBought, lessThanOrEqualTo(rc.slotJelly.length));
  });

  test('칸 구매는 늘 다음 칸 — 극한(진행도 2칸)은 0 → 2 를 3번째 칸 값으로', () {
    final s = stored(
      jelly: 1000,
    ).copyWith(maxTierReached: 3, difficultyTier: 3);
    final paid = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 2,
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[1]},
          )
          .toJson(),
    );
    expect(paid.researchSlotsBought, 2);
    // 젤리를 안 냈으면(그대로) 3번째 칸은 공짜가 아니다 — 300 상식 여유를 칸 값에 쓰지 않는다.
    final unchanged = up(s, s.copyWith(researchSlotsBought: 2).toJson());
    expect(unchanged.researchSlotsBought, 0);
    // 정직한 구매 + 같은 업로드의 미션 젤리 +2 — 인정.
    final forge = cfg.mission!.missions.firstWhere((m) => m.id == 'forge');
    final claims = [
      for (var c = 0; c < 20; c++)
        if (forge.rewardAt(c) == 2) c,
    ].first;
    final honest = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 2,
            missionClaims: {'forge': claims},
            dailyClaims: {missionJellyKey('forge', 0): dailyDateKey(t0)},
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[1] + 2},
          )
          .toJson(),
    );
    expect(honest.researchSlotsBought, 2);
  });

  test('걸린 칸 구매는 낸 젤리를 돌려준다 — 저장본 + 근거 있는 수입 위로는 안 올린다', () {
    final s = stored(
      jelly: 1000,
    ).copyWith(maxTierReached: 2, difficultyTier: 2);
    // 정직한 구매(−300) + 같은 업로드에 흔적 없는 젤리 +50(우편 등) — 칸은 걸리지만 젤리는 잃지 않는다.
    final honest = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 2,
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[1] + 50},
          )
          .toJson(),
    );
    expect(honest.researchSlotsBought, 0);
    final j = honest.materialCount(MaterialKind.jelly);
    expect(j, greaterThanOrEqualTo(1000 - rc.slotJelly[1] + 50));
    expect(j, lessThanOrEqualTo(1000));
    // 젤리를 그대로 두고 산 수만 올림 — 칸도 없고 젤리도 늘지 않는다.
    final attacker = up(s, s.copyWith(researchSlotsBought: 2).toJson());
    expect(attacker.researchSlotsBought, 0);
    expect(attacker.materialCount(MaterialKind.jelly), 1000);
  });

  test('되돌릴 때 이번 업로드에 시작한 단계의 시작 값을 돌려준다', () {
    final barter = rc.byId('barter')!;
    final c = rc.costAt(barter, 1);
    final s = stored(samples: 50).copyWith(gold: 1000000);
    // 정직하게 교환 협상 Lv1 을 시작해 값을 냈는데, 같은 업로드의 다른 칸이 위조로 걸렸다.
    final json = s
        .copyWith(
          researchSamples: 50 - c.samples,
          gold: 1000000 - 1000,
          researchLevels: {'jaw': 20},
          researchSlots: [
            ResearchSlot(
              id: 'barter',
              level: 1,
              endsAt: t0.add(rc.timeAt(barter, 1)),
            ),
          ],
        )
        .toJson();
    final out = up(s, json);
    expect(out.researchLevels['jaw'], isNull);
    expect(out.researchSlots, isEmpty);
    expect(out.researchSamples, greaterThanOrEqualTo(50));
    expect(out.gold, greaterThanOrEqualTo(1000000 - 1000));
  });

  test('기기 시계가 3분 늦어도 새 진행 칸은 인정', () {
    final s = stored();
    final def = rc.byId('barter')!;
    final skewed = t0.subtract(const Duration(minutes: 3));
    final out = up(
      s,
      s
          .copyWith(
            researchSlots: [
              ResearchSlot(
                id: 'barter',
                level: 1,
                endsAt: skewed.add(rc.timeAt(def, 1)),
              ),
            ],
          )
          .toJson(),
    );
    expect(out.researchSlots.single.id, 'barter');
  });

  test('3번째 칸은 심연(2026-10-25) — 극한 최종 보스 기록 없이 심연을 적어 올리면 2칸으로 판정한다', () {
    final run = cfg.run;
    final fin3 = run.bossArtId(3, run.zonesPerTier);
    final s = stored().copyWith(maxTierReached: 3);
    final three = [
      for (final id in ['jaw', 'incubator', 'barter'])
        ResearchSlot(
          id: id,
          level: 1,
          endsAt: t0.add(const Duration(hours: 1)),
        ),
    ];
    final forged = up(
      s,
      s.copyWith(abyssUnlocked: true, researchSlots: three).toJson(),
    );
    expect(forged.researchSlots, isEmpty, reason: '2칸인데 셋을 돌림 → 저장본');
    final honest = up(
      s,
      s
          .copyWith(
            abyssUnlocked: true,
            bossDex: {...s.bossDex, fin3},
            researchSlots: three,
          )
          .toJson(),
    );
    expect(honest.researchSlots, hasLength(3));
  });

  test('한 줄은 칸 하나 — 노는 칸의 시간을 빌려 한 연구를 두 배로 올리지 못한다', () {
    final need = timeSum(0, 2);
    // 심연까지 간 계정 = 3칸. 경과는 두 레벨 시간의 60% — 칸 셋을 합치면 넉넉하지만 한 줄로는 모자란다.
    final s = stored(
      elapsed: need * 0.6,
    ).copyWith(maxTierReached: 3, abyssUnlocked: true);
    expect(rc.slotsFor(s.topTier, 0, abyss: s.abyssUnlocked), 3);
    final out = up(s, s.copyWith(researchLevels: {'jaw': 2}).toJson());
    expect(out.researchLevels['jaw'], isNull);
  });

  test('끝 시각을 업로드마다 60초씩 당기면 결국 되돌린다', () {
    final full = rc.timeAt(jaw, 5);
    var s = stored(
      levels: {'jaw': 4},
      slots: [ResearchSlot(id: 'jaw', level: 5, endsAt: t0.add(full))],
    ).copyWith(lastSeen: t0);
    var clamped = false;
    for (var i = 1; i <= 30 && !clamped; i++) {
      final t = t0.add(Duration(minutes: i));
      final a = GameActions(config: cfg, now: () => t);
      final pulled = s.researchSlots.single.endsAt.subtract(
        const Duration(seconds: 60),
      );
      final json = s
          .copyWith(
            researchSlots: [ResearchSlot(id: 'jaw', level: 5, endsAt: pulled)],
          )
          .toJson();
      final next = a.mergeSave(s, json).save!;
      if (next.researchSlots.single.endsAt != pulled) clamped = true;
      s = next;
    }
    expect(clamped, isTrue);
  });

  test('위조한 최대 연구 레벨은 골드 상한 봉투를 넓히지 못한다', () {
    final s = stored().copyWith(gold: 1000);
    final maxed = {for (final d in rc.defs) d.id: d.maxLevel};
    final plain = up(s, s.copyWith(gold: 1 << 50).toJson());
    final forged = up(
      s,
      s.copyWith(gold: 1 << 50, researchLevels: maxed).toJson(),
    );
    expect(plain.gold, lessThan(1 << 50));
    expect(forged.gold, plain.gold);
    expect(forged.researchLevels.values.every((v) => v == 0), isTrue);
  });

  test('레벨이 줄면 저장본 · 모르는 연구는 버림 · 최대 레벨로 자름', () {
    final s = stored(levels: {'jaw': jaw.maxLevel, 'shell': 3});
    final json = s
        .copyWith(researchLevels: {'jaw': jaw.maxLevel, 'shell': 1})
        .toJson();
    (json['rsL'] as Map)['nope'] = 7;
    (json['rsL'] as Map)['jaw'] = jaw.maxLevel + 5;
    final out = up(s, json);
    expect(out.researchLevels['shell'], 3);
    expect(out.researchLevels['jaw'], jaw.maxLevel);
    expect(out.researchLevels.containsKey('nope'), isFalse);
  });

  test('samples_surge_clamped — 표본 급증은 저장본 + 허용치로, 정상 드롭은 인정', () {
    final s = stored(samples: 50);
    // 60초 = 가장 큰 드롭 한 번 + 경과 시간 몫(1초 업로드를 되풀이해 모으지 못하게 정액이 아니다).
    final small = up(s, s.copyWith(researchSamples: 53).toJson());
    expect(small.researchSamples, 53);
    final surged = up(s, s.copyWith(researchSamples: 1000000).toJson());
    expect(surged.researchSamples, greaterThan(50));
    expect(surged.researchSamples, lessThan(1000));
    // 새 보스 첫 처치 = 확정 드롭.
    final withBoss = up(
      s,
      s
          .copyWith(
            bossDex: {'b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8'},
            researchSamples: 50 + 8 * rc.bossFirstDrop,
          )
          .toJson(),
    );
    expect(withBoss.researchSamples, 50 + 8 * rc.bossFirstDrop);
    // 쓰는 것(감소)은 자유.
    expect(up(s, s.copyWith(researchSamples: 3).toJson()).researchSamples, 3);
  });

  test('10초 만에 다시 올린 업로드의 정예 표본 1개는 그대로 — 판정도 실패하지 않는다(2026-10-28 운영 요약)', () {
    // 운영 요약: `research 시간·젤리 판정 실패 · 표본 저장본 88 · 업로드 89 → 88(경과 10초)`.
    final slot = ResearchSlot(
      id: 'jaw',
      level: 3,
      endsAt: t0.add(const Duration(hours: 2)),
    );
    final s = stored(
      elapsed: const Duration(seconds: 10),
      samples: 88,
      levels: {'jaw': 2},
      slots: [slot],
    );
    final json = s.copyWith(researchSamples: 89).toJson();
    expect(reasons(s, json), isNot(contains('research')));
    final out = up(s, json);
    expect(out.researchSamples, 89);
    expect(out.researchSlots.single.id, 'jaw');
    // 여유를 썼으니 기준 시각이 앞으로 갔다(서버 소유).
    expect(out.researchDropSlackAt, isNotNull);
  });

  test('표본이 넘쳐도 같은 업로드에 시작한 연구는 되돌리지 않는다 — 표본만 자른다', () {
    final s = stored(elapsed: const Duration(seconds: 10), samples: 1000);
    final cost = rc.costAt(jaw, 1).samples;
    // 연구를 시작하면서(표본 지불) 정예 표본도 얻었다 — 운 좋은 1개 + 위조 500.
    final legit = s
        .copyWith(
          researchSamples: 1000 - cost + 1,
          researchSlots: [
            ResearchSlot(
              id: 'jaw',
              level: 1,
              endsAt: t0.add(rc.timeAt(jaw, 1)),
            ),
          ],
        )
        .toJson();
    expect(reasons(s, legit), isNot(contains('research')));
    expect(up(s, legit).researchSamples, 1000 - cost + 1);
    final json = s
        .copyWith(
          researchSamples: 1000 - cost + 500,
          researchSlots: [
            ResearchSlot(
              id: 'jaw',
              level: 1,
              endsAt: t0.add(rc.timeAt(jaw, 1)),
            ),
          ],
        )
        .toJson();
    final out = up(s, json);
    expect(out.researchSlots.single.id, 'jaw', reason: '연구 시작은 그대로');
    expect(out.researchSamples, lessThan(1000 - cost + 10));
    expect(out.researchSamples, greaterThanOrEqualTo(1000 - cost));
  });

  test('표본 여유는 시간으로만 찬다 — 1초마다 쪼개 올려도 1분에 가장 큰 드롭 한 번 몫', () {
    final maxDrop = rc.eliteDropAmount > rc.bossRepeatDrop
        ? rc.eliteDropAmount
        : rc.bossRepeatDrop;
    var s = stored(elapsed: const Duration(seconds: 1), samples: 0);
    var at = t0;
    for (var i = 0; i < 60; i++) {
      final a = GameActions(config: cfg, now: () => at);
      final r = a.mergeSave(
        s,
        s.copyWith(researchSamples: s.researchSamples + maxDrop).toJson(),
      );
      s = r.save!.copyWith(lastSeen: at);
      at = at.add(const Duration(seconds: 1));
    }
    // 1분 동안: 여유(가장 큰 드롭 한 번, 처음엔 가득) + 1분 차오름 + 경과 시간 몫 — 쪼개 올린 60번 × 드롭이 아니다.
    expect(s.researchSamples, lessThanOrEqualTo(maxDrop * 4));
  });

  test('표본 여유 기준 시각은 서버 소유 — 앱이 지워도 저장본 값', () {
    final at = t0.subtract(const Duration(seconds: 5));
    final s = stored(
      elapsed: const Duration(seconds: 10),
      samples: 10,
    ).copyWith(researchDropSlackAt: at);
    final json = s.toJson()..remove('rDA');
    expect(up(s, json).researchDropSlackAt, at);
  });

  test('samples — 연구 패스가 켜진 동안의 방치 몫은 경과 시간만큼 더 인정', () {
    const gap = Duration(hours: 8);
    final noPass = stored(elapsed: gap, samples: 0);
    final pass = stored(
      elapsed: gap,
      samples: 0,
      passUntil: t0.add(const Duration(days: 10)),
    );
    final kills =
        gap.inSeconds * kRareDropKillsPerSecondCap * cfg.run.eliteChance;
    final idle = (kills * rc.eliteDropChance * rc.eliteDropAmount).floor();
    expect(idle, greaterThan(100));
    expect(
      up(pass, pass.copyWith(researchSamples: idle).toJson()).researchSamples,
      idle,
    );
    expect(
      up(
        noPass,
        noPass.copyWith(researchSamples: idle).toJson(),
      ).researchSamples,
      lessThan(idle),
    );
  });

  test('research_pass_server_owned — 클라가 만료일을 늘리거나 지워도 저장본 값', () {
    final s = stored();
    final forged = up(
      s,
      s
          .copyWith(researchPassExpiresAt: t0.add(const Duration(days: 30)))
          .toJson(),
    );
    expect(forged.researchPassExpiresAt, isNull);
    final until = t0.add(const Duration(days: 3));
    final s2 = stored(passUntil: until);
    final json = s2.toJson()..remove('researchPassExpiresAt');
    expect(up(s2, json).researchPassExpiresAt, until);
  });

  test('숫자가 아닌 연구 값은 업로드를 깨지 않는다(무시)', () {
    final s = stored(levels: {'jaw': 2}, samples: 10, bought: 1);
    final json = s.toJson()
      ..['rsL'] = {
        'jaw': 'abc',
        'shell': null,
        'barter': 1.5e300,
        'x': [1],
      }
      ..['rsS'] = [
        'junk',
        {'i': 7, 'l': 'a', 'e': 3},
        {'i': 'jaw', 'l': 3},
      ]
      ..['rsC'] = 'many'
      ..['rsB'] = {'a': 1};
    final r = actions.mergeSave(s, json);
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.save!.researchLevels['jaw'], 2);
    expect(r.save!.researchSlotsBought, 1);
    expect(r.save!.researchSlots, isEmpty);
    // 맵이 아닌 rsL 도 마찬가지.
    final r2 = actions.mergeSave(s, s.toJson()..['rsL'] = 'oops');
    expect(r2.isOk, isTrue, reason: r2.error);
    expect(r2.save!.researchLevels['jaw'], 2);
  });

  test('환불 골드는 업로드 골드 허용치를 함께 쓴다 — 이월 창 안에서 되풀이해도 직접 올린 상한을 못 넘는다', () {
    final barter = rc.byId('barter')!;
    var s = stored().copyWith(
      gold: 1000000,
      goldCarry: 1 << 40,
      goldCarryUntil: t0.add(const Duration(minutes: 4)),
    );
    for (var i = 1; i <= 3; i++) {
      final t = t0.add(Duration(seconds: 60 * i));
      final a = GameActions(config: cfg, now: () => t);
      // 위조로 걸리는 업로드 — 골드는 그대로, 새 칸을 시작했다고 주장(환불 대상).
      final forged = a
          .mergeSave(
            s,
            s
                .copyWith(
                  researchLevels: {'jaw': 20},
                  researchSlots: [
                    ResearchSlot(
                      id: 'barter',
                      level: 1,
                      endsAt: t.add(rc.timeAt(barter, 1)),
                    ),
                  ],
                )
                .toJson(),
          )
          .save!;
      // 같은 저장본에서 골드를 직접 최대로 올린 업로드.
      final direct = a.mergeSave(s, s.copyWith(gold: 1 << 60).toJson()).save!;
      expect(
        forged.gold + forged.goldCarry,
        lessThanOrEqualTo(direct.gold + direct.goldCarry),
        reason: '$i번째 업로드',
      );
      expect(forged.researchLevels['jaw'], isNull);
      s = forged;
    }
  });

  test('되돌려도 값을 치른 산 칸은 남고, 즉시 완료 젤리는 돌려주지 않는다(수도꼭지 규칙)', () {
    final s = stored(jelly: 1000);
    final full = rc.timeAt(jaw, 1);
    final finishJelly = rc.instantJelly(full - const Duration(seconds: 60));
    final uploaded = 1000 - rc.slotJelly[0] - finishJelly;
    final out = up(
      s,
      s
          .copyWith(
            researchSlotsBought: 1,
            // 칸 값 + 즉시 완료 젤리를 냈다. 그런데 다른 줄(교환 협상 Lv20)이 위조로 걸린다.
            materials: {MaterialKind.jelly: uploaded},
            researchLevels: {'jaw': 1, 'barter': 20},
          )
          .toJson(),
    );
    expect(out.researchLevels['barter'], isNull);
    expect(out.researchLevels['jaw'], isNull);
    expect(out.researchSlotsBought, 1);
    expect(out.materialCount(MaterialKind.jelly), uploaded);
  });

  test('다른 곳에 젤리를 쓰고 rsL 을 위조해도 젤리가 올라온 값보다 늘지 않는다', () {
    // 교환소·부화 즉시 완료 등(연구 검사가 세지 않는 소비처)에 젤리 200 을 썼다 + 위조 레벨.
    var s = stored(jelly: 1000);
    for (var i = 1; i <= 3; i++) {
      final t = t0.add(Duration(seconds: 60 * i));
      final a = GameActions(config: cfg, now: () => t);
      final uploaded = s.materialCount(MaterialKind.jelly) - 200;
      final out = a
          .mergeSave(
            s,
            s
                .copyWith(
                  researchLevels: {'jaw': 25},
                  materials: {MaterialKind.jelly: uploaded},
                )
                .toJson(),
          )
          .save!;
      expect(out.researchLevels['jaw'], isNull);
      expect(out.materialCount(MaterialKind.jelly), uploaded, reason: '$i');
      s = out;
    }
  });

  test('위조한 최고 난이도로 연구 칸·시간 풀을 늘리지 못한다(저장본 +1 까지)', () {
    // 쉬움만 가 본 계정(1칸). 경과는 두 연구 Lv1 을 동시에 돌린 만큼 — 2칸이어야 설명된다.
    final lv1 = rc.timeAt(jaw, 1);
    final s = stored(elapsed: lv1);
    final json = s
        .copyWith(maxTierReached: 3, researchLevels: {'jaw': 1, 'barter': 1})
        .toJson();
    final out = up(s, json);
    expect(out.researchLevels['barter'], isNull);
    // 극한을 정말 가 본 저장본이면 3칸이라 인정.
    final real = stored(elapsed: lv1).copyWith(maxTierReached: 3);
    final ok = up(
      real,
      real.copyWith(researchLevels: {'jaw': 1, 'barter': 1}).toJson(),
    );
    expect(ok.researchLevels['barter'], 1);
  });

  test('기기 시계가 3분 빠르면 저장본 칸의 자연 완료가 서버 시각보다 일찍 온다 — 인정', () {
    final full = rc.timeAt(jaw, 5);
    // 저장본 시각에 Lv5 칸이 10분 남았고, 7분 뒤(서버) 기기는 10분이 지났다고 본다.
    final s = stored(
      elapsed: const Duration(minutes: 7),
      levels: {'jaw': 4},
      slots: [
        ResearchSlot(
          id: 'jaw',
          level: 5,
          endsAt: t0
              .subtract(const Duration(minutes: 7))
              .add(const Duration(minutes: 10)),
        ),
      ],
    );
    expect(full, greaterThan(const Duration(minutes: 10)));
    final out = up(
      s,
      s.copyWith(researchLevels: {'jaw': 5}, researchSlots: const []).toJson(),
    );
    expect(out.researchLevels['jaw'], 5);
  });

  test('연구 효율 단계가 먼저 끝나면 뒤에 시작한 단계는 줄어든 시간으로 잰다', () {
    final eff = rc.byId('researchEff')!;
    const jawLv = 8;
    final cut = rc.effectAt(eff, 1);
    final shortened = Duration(
      milliseconds: (rc.timeAt(jaw, jawLv).inMilliseconds * (1 - cut)).round(),
    );
    // 차이가 여유(1분)보다 커야 의미 있는 검사다.
    expect(
      rc.timeAt(jaw, jawLv) - shortened,
      greaterThan(const Duration(minutes: 2)),
    );
    // 저장본: 연구 효율 Lv1 칸이 저장본 시각에 끝남 · 그 뒤 턱 강화 Lv8 을 줄어든 시간으로 자연 완료.
    final s = stored(
      elapsed: shortened,
      levels: {'jaw': jawLv - 1},
      slots: [
        ResearchSlot(
          id: 'researchEff',
          level: 1,
          endsAt: t0.subtract(shortened),
        ),
      ],
    );
    final out = up(
      s,
      s
          .copyWith(
            researchLevels: {'jaw': jawLv, 'researchEff': 1},
            researchSlots: const [],
          )
          .toJson(),
    );
    expect(out.researchLevels['jaw'], jawLv);
    expect(out.researchLevels['researchEff'], 1);
  });

  test('같은 업로드에 받은 패스 일일 젤리(+20)로 연구를 즉시 완료해도 인정', () {
    final full = rc.timeAt(jaw, 3);
    final s = stored(
      levels: {'jaw': 2},
      slots: [
        ResearchSlot(
          id: 'jaw',
          level: 3,
          endsAt: t0.subtract(const Duration(seconds: 60)).add(full),
        ),
      ],
    ).copyWith(passExpiresAt: t0.add(const Duration(days: 10)));
    final cost = rc.instantJelly(full - const Duration(seconds: 60));
    final daily = cfg.iap.passDailyJelly;
    expect(daily, greaterThan(0));
    expect(cost, greaterThan(0));
    final finished = s.copyWith(
      researchLevels: {'jaw': 3},
      researchSlots: const [],
      materials: {MaterialKind.jelly: 1000 + daily - cost},
    );
    final ok = up(
      s,
      finished.copyWith(dailyClaims: {'_iapDaily': dailyDateKey(t0)}).toJson(),
    );
    expect(ok.researchLevels['jaw'], 3);
    expect(ok.materialCount(MaterialKind.jelly), 1000 + daily - cost);
    // 받은 흔적이 없으면 순감소(cost − 20)로는 즉시 완료가 설명되지 않는다.
    expect(up(s, finished.toJson()).researchLevels['jaw'], 2);
  });

  test('내일 날짜의 선물 2배는 젤리 수입 근거가 아니다(오늘까지만)', () {
    final s = stored(jelly: 1000);
    final gain = cfg.gift!.doubleJellyMax;
    expect(gain, greaterThan(0));
    SaveGame buy(String date) => up(
      s,
      s
          .copyWith(
            researchSlotsBought: 1,
            giftDoubleDate: date,
            giftDoubleCount: 1,
            materials: {MaterialKind.jelly: 1000 - rc.slotJelly[0] + gain},
          )
          .toJson(),
    );
    expect(buy(dailyDateKey(t0)).researchSlotsBought, 1);
    final tomorrow = dailyDateKey(t0.add(const Duration(days: 1)));
    expect(buy(tomorrow).researchSlotsBought, 0);
  });

  test('새로 시작한 단계의 표본 값을 치르지 않으면 서버가 뺀다 · 저장본에 모자라면 되돌린다(2026-10-28)', () {
    // 표본 값이 60초 업로드 표본 허용치(3)보다 큰 단계 — 젤리로 즉시 완료했다고 본다.
    var lv = 1;
    while (rc.costAt(jaw, lv).samples <= 5) {
      lv++;
    }
    final price = rc.costAt(jaw, lv).samples;
    final jelly = rc.instantJelly(rc.timeAt(jaw, lv)) + 1000;
    final s = stored(
      levels: {'jaw': lv - 1},
      samples: price + 100,
      jelly: jelly,
    );
    SaveGame done(int samples) => s.copyWith(
      researchLevels: {'jaw': lv},
      researchSamples: samples,
      materials: {MaterialKind.jelly: 1000},
    );
    expect(up(s, done(100).toJson()).researchLevels['jaw'], lv);
    // 표본을 그대로 두고 레벨만 올렸다 — 레벨은 인정하되 값만큼 표본이 빠진다(공짜 레벨 없음).
    final json = done(price + 100).toJson();
    final out = up(s, json);
    expect(out.researchLevels['jaw'], lv);
    expect(out.researchSamples, lessThan(100 + 10));
    expect(reasons(s, json), contains('research'));
    // 저장본 표본이 값보다 모자라면(허용치로도) 되돌린다.
    final poor = stored(levels: {'jaw': lv - 1}, samples: 0, jelly: jelly);
    final forged = poor
        .copyWith(
          researchLevels: {'jaw': lv},
          researchSamples: 0,
          materials: {MaterialKind.jelly: 1000},
        )
        .toJson();
    expect(up(poor, forged).researchLevels['jaw'], lv - 1);
  });

  test('선행 연구가 열리지 않은 연구는 시작할 수 없다', () {
    final shell = rc.byId('shell')!;
    final req = shell.requires!;
    final s = stored(elapsed: const Duration(hours: 1), samples: 10000);
    ResearchSlot slot() => ResearchSlot(
      id: 'shell',
      level: 1,
      endsAt: t0.add(rc.timeAt(shell, 1)),
    );
    final locked = up(
      s,
      s
          .copyWith(
            researchSlots: [slot()],
            researchSamples: 10000 - rc.costAt(shell, 1).samples,
          )
          .toJson(),
    );
    expect(locked.researchSlots, isEmpty);
    // 저장본에서 선행 레벨이 이미 열려 있으면 인정.
    final open = stored(
      elapsed: const Duration(hours: 1),
      samples: 10000,
      levels: {req.id: req.level},
    );
    final ok = up(
      open,
      open
          .copyWith(
            researchSlots: [slot()],
            researchSamples: 10000 - rc.costAt(shell, 1).samples,
          )
          .toJson(),
    );
    expect(ok.researchSlots.single.id, 'shell');
  });

  test('표본 온라인 몫은 경과 시간에 비례 — 1초 업로드를 되풀이해도 쌓이지 않는다', () {
    var s = stored(elapsed: const Duration(seconds: 1), samples: 0);
    var total = 0;
    for (var i = 1; i <= 60; i++) {
      final t = t0.add(Duration(seconds: i));
      final a = GameActions(config: cfg, now: () => t);
      final out = a
          .mergeSave(
            s,
            s.copyWith(researchSamples: s.researchSamples + 50).toJson(),
          )
          .save!;
      total = out.researchSamples;
      s = out.copyWith(lastSeen: t);
    }
    // 한 번에 60초를 올린 업로드의 허용치 + 처음 가득 찬 드롭 여유 한 번보다 많지 않다
    // (여유는 서버 소유 기준 시각에서 시간으로만 다시 찬다 — 2026-10-28).
    final once = stored(samples: 0);
    final big = up(once, once.copyWith(researchSamples: 1000).toJson());
    final maxDrop = rc.eliteDropAmount > rc.bossRepeatDrop
        ? rc.eliteDropAmount
        : rc.bossRepeatDrop;
    expect(total, lessThanOrEqualTo(big.researchSamples + maxDrop));
    // 30분 공백이면 60초보다 크게 열린다(패스 없음 — 온라인 몫만).
    final gap = stored(elapsed: const Duration(minutes: 30), samples: 0);
    final long = up(gap, gap.copyWith(researchSamples: 1000).toJson());
    expect(long.researchSamples, greaterThan(big.researchSamples));
    expect(long.researchSamples, lessThan(1000));
  });

  test('가 본 최고 난이도는 그 난이도의 최종 보스 기록이 있어야 + 1 — 위조 업로드 3번으로 극한에 못 간다', () {
    // 최종 보스 없이 올린 극한은 저장본에 머문다(예전엔 +1 씩 올라 3번이면 극한이었다).
    var s = stored();
    for (var i = 1; i <= 3; i++) {
      final t = t0.add(Duration(seconds: 60 * i));
      final a = GameActions(config: cfg, now: () => t);
      s = a
          .mergeSave(
            s,
            s.copyWith(maxTierReached: 3, difficultyTier: 3).toJson(),
          )
          .save!;
      expect(s.maxTierReached, 0, reason: '$i번째 업로드');
      expect(s.difficultyTier, 0);
    }
    // 최종 보스까지 함께 위조해도 한 계단 뒤에는 그 난이도에 들어선 지 6시간이 지나야 한다.
    final run = cfg.run;
    String fin(int tier) => run.bossArtId(tier, run.zonesPerTier);
    s = stored();
    for (var i = 1; i <= 3; i++) {
      final t = t0.add(Duration(seconds: 60 * i));
      final a = GameActions(config: cfg, now: () => t);
      s = a
          .mergeSave(
            s,
            s
                .copyWith(
                  maxTierReached: 3,
                  difficultyTier: 3,
                  bossDex: {fin(0), fin(1), fin(2)},
                )
                .toJson(),
          )
          .save!;
      expect(s.maxTierReached, 1, reason: '$i번째 업로드');
      expect(s.difficultyTier, lessThanOrEqualTo(1));
    }
    // 정직한 한 계단(쉬움 최종 보스를 잡고 바로 보통으로 — 같은 업로드)은 그대로.
    final easy = stored();
    final next = up(
      easy,
      easy
          .copyWith(maxTierReached: 1, difficultyTier: 1, bossDex: {fin(0)})
          .toJson(),
    );
    expect(next.maxTierReached, 1);
    expect(next.difficultyTier, 1);
    // 보통에 들어선 지 6시간 뒤 보통 최종 보스를 잡으면 어려움으로.
    final later = t0.add(const Duration(hours: 7));
    final hard = GameActions(config: cfg, now: () => later)
        .mergeSave(
          next,
          next
              .copyWith(
                maxTierReached: 2,
                difficultyTier: 2,
                bossDex: {...next.bossDex, fin(1)},
              )
              .toJson(),
        )
        .save!;
    expect(hard.maxTierReached, 2);
    // 내려가는 것(로드맵 난이도 선택)은 막지 않는다.
    final down = up(next, next.copyWith(difficultyTier: 0).toJson());
    expect(down.difficultyTier, 0);
    expect(down.maxTierReached, 1);
  });
}
