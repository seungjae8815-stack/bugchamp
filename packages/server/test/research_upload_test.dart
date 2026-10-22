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

  test('clock_forward — 끝나기 직전으로 위조한 진행 칸도 이미 흐른 몫을 센다', () {
    final s = stored();
    // 1분 경과인데 Lv1(5분) 칸이 1초 남았다 = 4분 59초가 흘렀다는 주장.
    final json = s
        .copyWith(
          researchSlots: [
            ResearchSlot(
              id: 'jaw',
              level: 1,
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

  test('jelly_finish_accepted — 줄어든 젤리로 즉시 완료한 만큼 인정, 젤리가 안 줄었으면 되돌림', () {
    final need = timeSum(0, 3) - const Duration(seconds: 60);
    final cost = rc.instantJelly(need);
    final s = stored(jelly: 1000);
    final ok = up(
      s,
      s
          .copyWith(
            researchLevels: {'jaw': 3},
            materials: {MaterialKind.jelly: 1000 - cost},
          )
          .toJson(),
    );
    expect(ok.researchLevels['jaw'], 3);
    final bad = up(s, s.copyWith(researchLevels: {'jaw': 3}).toJson());
    expect(bad.researchLevels['jaw'], isNull);
  });

  test('칸 구매 — 젤리를 낸 만큼만, 2칸까지', () {
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
    final free = up(s, s.copyWith(researchSlotsBought: 1).toJson());
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
    final small = up(s, s.copyWith(researchSamples: 55).toJson());
    expect(small.researchSamples, 55);
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
}
