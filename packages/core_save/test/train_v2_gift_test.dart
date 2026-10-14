import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:test/test.dart';

/// 1.0.21 업데이트 기념 무료 다시 찍기(2026-10-14 사장님 확정) — 포인트를 찍은 곤충마다 1회 · 한 번만.
void main() {
  final t = DateTime.utc(2026, 10, 14);
  test('찍은 곤충에만 무료 다시 찍기 · 두 번째 실행은 아무것도 안 한다', () {
    final s = SaveGame.initial(createdAt: t).copyWith(
      trainPoints: {
        'a': const BugTrain(alloc: {TrainSlot.attack: 10}),
        'b': const BugTrain(),
        'c': const BugTrain(alloc: {TrainSlot.hp: 5}, freeRespec: true),
      },
    );
    final g = grantRespecGift1021(s);
    expect(g.granted, 1);
    expect(g.save.trainPoints['a']!.freeRespec, isTrue);
    expect(g.save.trainPoints['b']!.freeRespec, isFalse);
    expect(g.save.trainPoints['c']!.freeRespec, isTrue);
    expect(g.save.dailyClaims[kRespecGift1021Key], isNotNull);

    final again = grantRespecGift1021(
      g.save.copyWith(
        trainPoints: {
          ...g.save.trainPoints,
          'a': g.save.trainPoints['a']!.copyWith(freeRespec: false),
        },
      ),
    );
    expect(again.granted, 0);
    expect(again.save.trainPoints['a']!.freeRespec, isFalse);
  });
}
