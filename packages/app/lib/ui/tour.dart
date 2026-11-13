import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'colors.dart' show kHoney;

/// 첫 실행 화면 둘러보기(2026-11-12 사장님 확정) — 어디에 무엇이 있는지 한 칸씩 밝혀 짚어 준다.
///
/// 화면 곳곳에 [TourKeys] 의 키를 [KeyedSubtree] 로 붙여 두고, [showTour] 가 그 위치를 찾아 그 자리만 밝힌다.
/// 키가 화면에 없으면(다른 탭·아직 안 그림) 그 단계는 건너뛴다 — 배치가 바뀌어도 깨지지 않는다.
class TourKeys {
  TourKeys._();

  /// 탭 안내용 이름 키(같은 이름이면 같은 키) — 화면마다 [KeyedSubtree] 로 붙인다.
  static final _named = <String, GlobalKey>{};
  static GlobalKey named(String id) =>
      _named.putIfAbsent(id, () => GlobalKey(debugLabel: 'tour.$id'));
  static final upgrades = GlobalKey(debugLabel: 'tour.upgrades');
  static final stage = GlobalKey(debugLabel: 'tour.stage');
  static final buffs = GlobalKey(debugLabel: 'tour.buffs');
  static final mail = GlobalKey(debugLabel: 'tour.mail');
  static final mission = GlobalKey(debugLabel: 'tour.mission');
  static final navStorage = GlobalKey(debugLabel: 'tour.navStorage');
  static final navBattle = GlobalKey(debugLabel: 'tour.navBattle');
  static final navShop = GlobalKey(debugLabel: 'tour.navShop');
  static final navSwitch = GlobalKey(debugLabel: 'tour.navSwitch');

  /// 장비 탭의 모루(미션 "장비 제련" 안내가 짚는다).
  static final forge = GlobalKey(debugLabel: 'tour.forge');
}

typedef TourStep = ({GlobalKey key, String text});

/// 탭 안내가 짚을 자리 표시 — [id] 가 null 이면 그대로(목록 안 첫 줄만 표시할 때).
Widget tourMark(String? id, Widget child) =>
    id == null ? child : KeyedSubtree(key: TourKeys.named(id), child: child);

/// 둘러보기가 화면을 덮고 있는가 — 그동안 사냥 화면은 몬스터 공격을 멈춘다(창과 같은 취급).
bool tourShowing = false;

/// 첫 실행 둘러보기 단계(왼쪽 위부터 아래로 — 눈이 가는 순서).
List<TourStep> firstRunTour(AppLocalizations l) => [
  (key: TourKeys.upgrades, text: l.tourUpgrades),
  (key: TourKeys.stage, text: l.tourStage),
  (key: TourKeys.buffs, text: l.tourBuffs),
  (key: TourKeys.mail, text: l.tourMail),
  (key: TourKeys.mission, text: l.tourMission),
  (key: TourKeys.navStorage, text: l.tourStorage),
  (key: TourKeys.navBattle, text: l.tourBattle),
  (key: TourKeys.navShop, text: l.tourShop),
  (key: TourKeys.navSwitch, text: l.tourSwitch),
];

/// 탭 첫 방문 안내(2026-11-12 사장님 확정) — 탭 번호마다 그 탭의 핵심 기능. 화면에 없는 칸은 건너뛴다.
/// 번호는 `domain/providers.dart` 의 탭 번호(1 채집함 · 2 결투 · 3 길드 · 4 상점 · 5 장비 · 6 스킬 · 7 요정 · 8 연구소).
List<TourStep> tabTour(AppLocalizations l, int tab) {
  TourStep s(String id, String text) => (key: TourKeys.named(id), text: text);
  return switch (tab) {
    1 => [
      s('storage.dex', l.tabTourStorageDex),
      s('storage.mats', l.tabTourStorageMats),
      s('storage.cap', l.tabTourStorageCap),
      s('storage.pets', l.tabTourStoragePets),
      s('storage.tools', l.tabTourStorageTools),
      s('storage.grid', l.tabTourStorageGrid),
      s('storage.breed', l.tabTourStorageBreed),
      s('storage.hatch', l.tabTourStorageHatch),
    ],
    5 => [
      s('equip.scene', l.tabTourEquipScene),
      s('equip.stats', l.tabTourEquipStats),
      s('equip.grid', l.tabTourEquipGrid),
      (key: TourKeys.forge, text: l.tabTourEquipAnvil),
      s('equip.grade', l.tabTourEquipGrade),
      s('equip.filter', l.tabTourEquipFilter),
      s('equip.rush', l.tabTourEquipRush),
      s('equip.auto', l.tabTourEquipAuto),
    ],
    2 => [
      s('battle.ticket', l.tabTourBattleTicket),
      s('battle.squad', l.tabTourBattleSquad),
      s('battle.start', l.tabTourBattleStart),
      s('battle.recovery', l.tabTourBattleRecovery),
      s('battle.training', l.tabTourBattleTraining),
      s('battle.board', l.tabTourBattleBoard),
    ],
    4 => [
      s('shop.top', l.tabTourShopTop),
      s('shop.gacha', l.tabTourShopGacha),
      s('shop.exchange', l.tabTourShopExchange),
    ],
    6 => [
      s('skill.gacha', l.tabTourSkillGacha),
      s('skill.sweep', l.tabTourSkillSweep),
      s('skill.grade', l.tabTourSkillGrade),
      s('skill.shards', l.tabTourSkillShards),
      s('skill.slots', l.tabTourSkillSlots),
      s('skill.list', l.tabTourSkillList),
    ],
    7 => [
      s('fairy.companion', l.tabTourFairyCompanion),
      s('fairy.nest', l.tabTourFairyNest),
      s('fairy.gacha', l.tabTourFairyGacha),
      s('fairy.dex', l.tabTourFairyDex),
      s('fairy.feed', l.tabTourFairyFeed),
      s('fairy.release', l.tabTourFairyRelease),
    ],
    8 => [
      s('research.currency', l.tabTourResearchCurrency),
      s('research.slots', l.tabTourResearchSlots),
      s('research.tabs', l.tabTourResearchTabs),
      s('research.tree', l.tabTourResearchTree),
      s('research.abyss', l.tabTourResearchAbyss),
    ],
    _ => const [],
  };
}

/// 단계를 하나씩 보여 준다. 끝까지 보거나 "건너뛰기"를 누르면 완료된다.
Future<void> showTour(BuildContext context, List<TourStep> steps) async {
  final shown = [
    for (final s in steps)
      if (_rectOf(s.key) != null) s,
  ];
  if (shown.isEmpty) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  var i = 0;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final step = shown[i];
      final rect = _rectOf(step.key);
      return _TourLayer(
        rect: rect,
        text: step.text,
        index: i,
        total: shown.length,
        onNext: () {
          if (i + 1 >= shown.length) {
            entry.remove();
            done.complete();
          } else {
            i++;
            entry.markNeedsBuild();
          }
        },
        onSkip: () {
          entry.remove();
          done.complete();
        },
      );
    },
  );
  tourShowing = true;
  overlay.insert(entry);
  return done.future.whenComplete(() => tourShowing = false);
}

Rect? _rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final o = box.localToGlobal(Offset.zero);
  return (o & box.size).inflate(4);
}

class _TourLayer extends StatelessWidget {
  const _TourLayer({
    required this.rect,
    required this.text,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final Rect? rect;
  final String text;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final r = rect;
    // 밝힌 칸이 화면 아래쪽이면 말풍선을 위에, 위쪽이면 아래에.
    final below = r == null || r.center.dy < size.height / 2;
    const side = 16.0;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(horizontal: side),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF243318),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHoney, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // 한 칸짜리 안내(미션 바로 가기)는 쪽수·건너뛰기 없이 "알겠어요"만.
              if (total > 1)
                Text(
                  '${index + 1} / $total',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const Spacer(),
              if (total > 1) ...[
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    l.tourSkip,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kHoney,
                  foregroundColor: const Color(0xFF2A1A05),
                ),
                onPressed: onNext,
                child: Text(
                  total == 1
                      ? l.bossIntroOk
                      : (index + 1 >= total ? l.tourDone : l.tourNext),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 어둡게 깔고 그 칸만 뚫는다. 바깥을 눌러도 다음으로(눌러 둘러보는 손맛).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNext,
              child: CustomPaint(painter: _HolePainter(r)),
            ),
          ),
          if (r != null)
            Positioned.fromRect(
              rect: r,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kHoney, width: 2.5),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: below ? (r?.bottom ?? size.height * 0.3) + 10 : null,
            bottom: below ? null : size.height - r.top + 10,
            // 말풍선 글자를 눌러도 다음으로(버튼만 되면 글을 누른 사람이 멈춘 줄 안다).
            child: GestureDetector(onTap: onNext, child: bubble),
          ),
        ],
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  const _HolePainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? all
        : Path.combine(
            PathOperation.difference,
            all,
            Path()
              ..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(12))),
          );
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}
