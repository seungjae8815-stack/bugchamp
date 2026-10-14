import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 도감 통달이 세는 수 = 보유 곤충 + 발견한 종(2026-10-14 사장님 확정). 상한 50 은 deriveStats 가 자른다.
void main() {
  final t = DateTime.utc(2026, 10, 14);
  IndividualBug b(String id) => IndividualBug(
    id: id,
    speciesId: 'stag_saw',
    sizeMm: 40,
    potential: 1,
    temperament: Temperament.steadfast,
    sex: Sex.male,
    stage: LifeStage.larva,
  );
  test('보유 곤충 + 발견한 종 · 정수로 바꿔 곤충이 줄어도 발견한 종은 남는다', () {
    final s = SaveGame.initial(createdAt: t).copyWith(
      bugs: [b('a'), b('b')],
      dex: {
        'stag_saw': DexEntry.fromJson(const {}),
        'rhino': DexEntry.fromJson(const {}),
      },
    );
    expect(s.bugBuffCount, 4);
    expect(s.copyWith(bugs: const []).bugBuffCount, 2);
  });
}
