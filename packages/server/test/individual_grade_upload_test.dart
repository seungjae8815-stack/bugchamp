import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 개체 등급(2026-10-11 · feat 24) 업로드 — 구버전 보존 · 롤 정리 · 정수·물약 급증.
final t0 = DateTime.utc(2026, 10, 11, 12);

void main() {
  late GameActions off;
  late GameActions on;

  setUpAll(() async {
    off = GameActions(
      config: await GameConfig.load(dir: '../app/assets/data'),
      now: () => t0,
    );
    // 켠 설정 — 데이터 폴더 사본의 pets.json 에서 individualGrade.enabled 만 켠다.
    final tmp = Directory.systemTemp.createTempSync('grade_upload');
    for (final f in Directory(
      '../app/assets/data',
    ).listSync().whereType<File>()) {
      f.copySync('${tmp.path}/${f.uri.pathSegments.last}');
    }
    final pf = File('${tmp.path}/pets.json');
    final pets = jsonDecode(pf.readAsStringSync()) as Map<String, dynamic>;
    (pets['individualGrade'] as Map<String, dynamic>)['enabled'] = true;
    pf.writeAsStringSync(jsonEncode(pets));
    on = GameActions(
      config: await GameConfig.load(dir: tmp.path),
      now: () => t0,
    );
  });

  IndividualBug bug(
    String id, {
    int su = 0,
    List<int>? rolls,
    bool gc = false,
  }) => IndividualBug(
    id: id,
    speciesId: 'stag_dorcus',
    sizeMm: 40,
    potential: 1 + su,
    temperament: Temperament.cunning,
    sex: Sex.male,
    stage: LifeStage.adult,
    synthUps: su,
    rolls: rolls,
    fromGacha: gc,
  );

  SaveGame stored(List<IndividualBug> bugs) => SaveGame.initial(
    createdAt: t0,
  ).copyWith(lastSeen: t0.subtract(const Duration(seconds: 60)), bugs: bugs);

  test('구버전 앱(feat 23)이 올려도 정수·물약·롤·뽑기 출신을 지킨다', () {
    const good = [90, 90, 90, 90, 90, 90, 90, 90];
    final s = stored([
      bug('a', su: 1, rolls: good, gc: true),
    ]).copyWith(essence: {'stag_dorcus': 40}, growthPotions: 7);
    final j = s.toJson()
      ..['feat'] = 23
      ..remove('essence')
      ..remove('potions');
    j['bugs'] = [
      for (final b in j['bugs'] as List)
        (Map<String, dynamic>.from(b as Map)
          ..remove('rl')
          ..remove('gc')),
    ];
    final out = off.mergeSave(s, j).save!;
    expect(out.essence, {'stag_dorcus': 40});
    expect(out.growthPotions, 7);
    expect(out.bugs.first.rolls, good);
    expect(out.bugs.first.fromGacha, isTrue);
  });

  test('등급 올리기를 안 한 곤충(합성 0)의 롤은 처음 롤로 되돌린다(위조 차단)', () {
    final s = stored([bug('a')]);
    final j = stored([
      bug('a', rolls: const [100, 100, 100, 100, 100, 100, 100, 100]),
    ]).toJson();
    final out = off.mergeSave(s, j).save!;
    expect(out.bugs.first.rolls, isNull);
  });

  test('정수는 사라진 곤충 가치만큼만 늘 수 있다(켰을 때)', () {
    final s = stored([bug('a'), bug('b')]);
    // 근거 없이 1,000 — 저장본(0) + 사라진 곤충 없음 = 0 으로 자른다.
    final fake = s.copyWith(essence: {'stag_dorcus': 1000}).toJson();
    expect(on.mergeSave(s, fake).save!.essence['stag_dorcus'] ?? 0, 0);
    // a 를 정수로 바꿨다 — 일반 1마리 = 1.
    final ok = s
        .copyWith(bugs: [bug('b')], essence: {'stag_dorcus': 1})
        .toJson();
    expect(on.mergeSave(s, ok).save!.essence['stag_dorcus'], 1);
  });

  test('물약은 쓴 젤리 ÷ 가격 + 드롭 여유만큼만 늘 수 있다(켰을 때)', () {
    final s = stored([]).copyWith(materials: {MaterialKind.jelly: 200});
    final up = s
        .copyWith(materials: {MaterialKind.jelly: 150}, growthPotions: 40)
        .toJson();
    // 50젤리 = 5개 + 여유 5 = 10.
    expect(on.mergeSave(s, up).save!.growthPotions, 10);
  });
}
