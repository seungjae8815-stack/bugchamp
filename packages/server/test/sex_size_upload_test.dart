import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:server/src/actions.dart';
import 'package:server/src/game_config.dart';
import 'package:test/test.dart';

/// 암컷 크기(2026-10-24 §12 암수 · feat 29) — 저장본 마이그레이션 · 구버전 업로드 · 결투 무게 수컷 환산.
final t0 = DateTime.utc(2026, 10, 24, 12);

void main() {
  late GameActions actions;
  late Species sp;
  late Map<String, Species> byId;

  setUpAll(() async {
    actions = GameActions(
      config: await GameConfig.load(dir: '../app/assets/data'),
      now: () => t0,
    );
    byId = {for (final x in actions.config.speciesList) x.id: x};
    sp = actions.config.speciesList.firstWhere((x) => x.id == 'stag_giant');
  });

  IndividualBug bug(String id, double mm, Sex sex) => IndividualBug(
    id: id,
    speciesId: 'stag_giant',
    sizeMm: mm,
    potential: 1,
    temperament: Temperament.cunning,
    sex: sex,
    element: Element.wood,
    stage: LifeStage.adult,
    stageSince: t0.subtract(const Duration(days: 30)),
  );

  SaveGame stored(List<IndividualBug> bugs, {bool sxm = true}) =>
      SaveGame.initial(createdAt: t0).copyWith(
        lastSeen: t0.subtract(const Duration(seconds: 60)),
        bugs: bugs,
        sexSizeMigrated: sxm,
      );

  double sizeOf(SaveGame s, String id) =>
      s.bugs.firstWhere((b) => b.id == id).sizeMm;

  test(
    'mergeSave migrates an unmigrated stored save once (sxm) and keeps male-equivalent mm',
    () {
      // 저장본: 아직 안 옮겨진 암컷 66mm(수컷 범위 값). 클라는 feat 28(sxm 없음)로 같은 곤충을 올린다 —
      // keep-list 가 저장본 크기를 돌려주므로 **저장본이 먼저 옮겨져야** 40 이 된다(안 옮기면 66).
      final old = stored([bug('a', 66, Sex.female)], sxm: false);
      final j = old.toJson()
        ..['feat'] = 28
        ..remove('sxm');
      final out = actions.mergeSave(old, j).save!;
      expect(out.sexSizeMigrated, isTrue);
      expect(sizeOf(out, 'a'), closeTo(40, 0.001));
      expect(sp.maleEquivalentMm(out.bugs.single), closeTo(66, 0.001));
      // 입력 저장본 객체는 바뀌지 않는다.
      expect(old.sexSizeMigrated, isFalse);
      expect(sizeOf(old, 'a'), 66);
    },
  );

  test(
    'feat<29 upload: same-id female keeps stored sizeMm; new female in male range is remapped; sxm stays true',
    () {
      final s = stored([bug('a', 40, Sex.female)]);
      final j =
          SaveGame.initial(createdAt: t0)
              .copyWith(
                lastSeen: s.lastSeen,
                bugs: [bug('a', 66, Sex.female), bug('b', 92, Sex.female)],
              )
              .toJson()
            ..['feat'] = 28
            ..remove('sxm');
      final out = actions.mergeSave(s, j).save!;
      expect(sizeOf(out, 'a'), closeTo(40, 0.001));
      expect(sizeOf(out, 'b'), closeTo(50, 0.001));
      expect(out.sexSizeMigrated, isTrue);
    },
  );

  test(
    'feat>=29 upload: client female sizes are trusted but must be inside the female range',
    () {
      final s = stored([]);
      SaveGame upload(double mm) {
        final j = stored([bug('a', mm, Sex.female)]).toJson()
          ..['feat'] = kSaveFeatureLevel;
        return actions.mergeSave(s, j).save!;
      }

      expect(sizeOf(upload(45), 'a'), closeTo(45, 0.001));
      // 업로드는 크기를 고치지 않는다(받는 쪽 그대로) — 범위 밖은 결투 편성 검증(integrityError)이 막는다.
      final bad = upload(55);
      expect(sizeOf(bad, 'a'), closeTo(55, 0.001));
      final r = actions.validateDuelTeam(
        bad.copyWith(
          bugs: [
            bad.bugs.single,
            bug('b', 60, Sex.male),
            bug('c', 60, Sex.male),
          ],
        ),
        ['a', 'b', 'c'],
        speciesById: byId,
        petConfig: actions.config.pet,
      );
      expect(r.error, 'bug_forged:size_out_of_range');
    },
  );

  test('validateDuelTeam passes male-equivalent mm and sex to DuelBug', () {
    final s = stored([
      bug('a', 40, Sex.female),
      bug('b', 66, Sex.male),
      bug('c', 66, Sex.male),
    ]);
    final r = actions.validateDuelTeam(
      s,
      ['a', 'b', 'c'],
      speciesById: byId,
      petConfig: actions.config.pet,
    );
    expect(r.error, isNull);
    expect(r.team[0].sizeMm, closeTo(66, 0.001));
    expect(r.team[0].sex, Sex.female);
    expect(r.team[1].sex, Sex.male);
  });

  test('validateDuelTeam migrates an unmigrated save first (idempotent)', () {
    final s = stored([
      bug('a', 66, Sex.female),
      bug('b', 66, Sex.male),
      bug('c', 66, Sex.male),
    ], sxm: false);
    final r = actions.validateDuelTeam(
      s,
      ['a', 'b', 'c'],
      speciesById: byId,
      petConfig: actions.config.pet,
    );
    expect(r.error, isNull);
    expect(r.team[0].sizeMm, closeTo(66, 0.001));
  });
}
