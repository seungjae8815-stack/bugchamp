import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/game_server.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/toast.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../battle/duel_arena_screen.dart';
import '../battle/duel_driver.dart';

/// 왕충 선발대회(2회차부터) — **곤충 1마리 · 결투 엔진 웨이브전**을 결투 무대로 치른다.
///
/// 규칙은 core_battle `event_duel.dart` 한 곳이다. 서버 진행기는 판마다 `/event/duel/throw` 로
/// 확정하고, 개발자 체험 진행기는 같은 함수를 앱에서 돌린다(기록·보상 없음).

/// 대회 진행기 공통 — 진행 상태·지금 걸린 카드·고른 카드를 들고 있다.
abstract class EventDuelDriver implements DuelDriver {
  EventDuelDriver({required this.spec, required this.cfg});

  final EventDuelSpec spec;
  final EventConfig cfg;

  EventDuelRun run = const EventDuelRun();

  /// 지금 고를 수 있는 카드(웨이브를 깬 직후에만).
  List<EventCard> cards = const [];

  /// 고른 카드 — 다음 [next] 에 실린다.
  String? pendingCard;

  int score = 0;
  bool isBest = false;
  bool recorded = false;

  @override
  String? error;

  @override
  bool get interactive => true;

  /// 카드를 고른 뒤의 진행(표시용) — 건너뛰기면 다음 적이 바뀐다. 서버와 같은 함수.
  EventDuelRun get preview {
    final c = pendingCard == null ? null : cfg.cardById(pendingCard!);
    return c == null ? run : run.applyCard(c.kind, c.value, spec);
  }

  /// 그만하기 — 지금까지의 기록으로 끝낸다. 실패하면 false([error]).
  Future<bool> quit();

  /// 그만하기로 받은 세이브(서버 진행기만).
  Map<String, dynamic>? quitSave;

  DuelStep _step(DuelBout bout, {Map<String, dynamic>? save}) => DuelStep(
    bout: bout,
    // 무대의 점수판·상대 번호 규칙에 맞춘다: 이긴 판 = 깬 웨이브, 진 판 = 끝났으면 1.
    winsA: run.cleared,
    winsB: run.over ? 1 : 0,
    done: run.over,
    save: save,
  );
}

/// 서버 세션 — 시드는 서버만 안다.
class ServerEventDuelDriver extends EventDuelDriver {
  ServerEventDuelDriver({
    required super.spec,
    required super.cfg,
    required this.server,
    required this.sessionId,
  });

  final GameServer server;
  final String sessionId;

  @override
  Future<DuelStep?> next(double launch) async {
    final res = await server.eventDuelThrow(
      sessionId: sessionId,
      launch: launch,
      cardId: pendingCard,
    );
    final d = res.data;
    if (!res.isOk || d == null || d['bout'] is! Map) {
      error = res.error ?? 'server';
      return null;
    }
    pendingCard = null;
    run = EventDuelRun.fromJson(Map<String, dynamic>.from(d['run'] as Map));
    cards = [
      for (final c in (d['cards'] as List? ?? const []))
        ?cfg.cardById('${(c as Map)['id']}'),
    ];
    score = (d['score'] as num?)?.toInt() ?? 0;
    isBest = d['isBest'] == true;
    recorded = d['recorded'] == true;
    return _step(
      DuelBout.fromJson(Map<String, dynamic>.from(d['bout'] as Map)),
      save: res.save,
    );
  }

  @override
  Future<bool> quit() async {
    final res = await server.eventDuelQuit(sessionId);
    final d = res.data;
    if (!res.isOk || d == null || d['run'] is! Map) {
      error = res.error ?? 'server';
      return false;
    }
    run = EventDuelRun.fromJson(Map<String, dynamic>.from(d['run'] as Map));
    cards = const [];
    score = (d['score'] as num?)?.toInt() ?? 0;
    isBest = d['isBest'] == true;
    recorded = d['recorded'] == true;
    quitSave = res.save;
    return true;
  }
}

/// 개발자 체험 — 서버 없이 같은 규칙을 앱에서 돌린다. 참가권·부상·기록·보상 없음.
class LocalEventDuelDriver extends EventDuelDriver {
  LocalEventDuelDriver({
    required super.spec,
    required super.cfg,
    required this.seed,
    required this.roundSeed,
    required this.bug,
    required this.enemyOf,
    required this.params,
  });

  final int seed;
  final int roundSeed;
  final DuelBug bug;
  final DuelBug Function(int wave) enemyOf;
  final DuelParams params;

  @override
  Future<DuelStep?> next(double launch) async {
    run = preview;
    pendingCard = null;
    final step = eventDuelFight(
      seed: seed,
      run: run,
      bug: bug,
      enemy: enemyOf(run.wave),
      params: params,
      spec: spec,
      launch: launch,
    );
    run = step.run;
    cards = step.won && !run.over
        ? cfg.drawCards(roundSeed, run.cleared)
        : const [];
    score = cfg.score(
      clearedWaves: run.cleared,
      hpPct: run.hpAtEntry,
      survivors: 0,
      totalRounds: run.ticks ~/ params.tickHz,
    );
    return _step(step.bout);
  }

  @override
  Future<bool> quit() async {
    run = run.quit();
    cards = const [];
    score = cfg.score(
      clearedWaves: run.cleared,
      hpPct: run.hpAtEntry,
      survivors: 0,
      totalRounds: run.ticks ~/ params.tickHz,
    );
    return true;
  }
}

/// 웨이브 [wave] 의 적 — 서버 `eventDuelEnemyOf` 와 같은 규칙(종 id 정렬 순서로 모습 고르기).
DuelBug eventEnemyFor(
  GameData data,
  EventDuelSpec spec,
  int roundSeed,
  int wave,
  String locale,
) {
  final ids = data.speciesById.keys.toList()..sort();
  final spId = eventWaveSpeciesId(roundSeed, wave, 0, ids) ?? '';
  final sp = data.speciesById[spId];
  return eventDuelEnemy(
    roundSeed: roundSeed,
    wave: wave,
    spec: spec,
    speciesId: spId,
    specialty: sp?.specialty ?? Specialty.strike,
    name: sp?.name.resolve(locale),
  );
}

/// 강화 칩 아이콘 → 그 강화를 주는 카드 그림 id(`assets/images/ui/cards/`).
final _cardArtOf = <IconData, String>{
  Icons.flash_on_rounded: 'atk_s',
  Icons.shield_rounded: 'def_s',
  Icons.favorite_rounded: 'hp_s',
  Icons.air_rounded: 'agile',
  Icons.gps_fixed_rounded: 'vital',
  Icons.spa_rounded: 'breath',
  Icons.fitness_center_rounded: 'heft',
  Icons.speed_rounded: 'ironhide',
  Icons.local_fire_department_rounded: 'last_stand',
  Icons.autorenew_rounded: 'revive',
};

/// 지금 받고 있는 강화(카드 누적) — 무대 체력칸 아래 · 카드 창에 같은 모양으로.
Widget eventBuffChips(AppLocalizations l, EventDuelRun run) {
  String pct(double v) => '+${(v * 100).round()}%';
  Widget chip(IconData icon, Color c, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xB3000000),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 그 강화를 준 카드 그림(없으면 아이콘).
        gameImage(
          'assets/images/ui/cards/${_cardArtOf[icon] ?? ''}.webp',
          width: 18,
          height: 18,
          fallback: Icon(icon, size: 12, color: c),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
  final chips = [
    if (run.atk > 0)
      chip(
        Icons.flash_on_rounded,
        const Color(0xFFFF8A65),
        '${l.bugInfoAtk} ${pct(run.atk)}',
      ),
    if (run.def != 0)
      chip(
        Icons.shield_rounded,
        run.def > 0 ? const Color(0xFF81D4FA) : const Color(0xFFB0BEC5),
        '${l.bugInfoDef} ${run.def > 0 ? pct(run.def) : '${(run.def * 100).round()}%'}',
      ),
    if (run.maxHp > 0)
      chip(
        Icons.favorite_rounded,
        const Color(0xFFEF9A9A),
        '${l.statHp} ${pct(run.maxHp)}',
      ),
    if (run.evade > 0)
      chip(
        Icons.air_rounded,
        const Color(0xFFB2EBF2),
        '${l.eventBuffEvade} ${pct(run.evade)}',
      ),
    if (run.crit > 0)
      chip(
        Icons.gps_fixed_rounded,
        const Color(0xFFFFCC80),
        '${l.eventBuffCrit} ${pct(run.crit)}',
      ),
    if (run.recover > 0)
      chip(
        Icons.spa_rounded,
        const Color(0xFFA5D6A7),
        '${l.eventBuffRecover} ${pct(run.recover)}',
      ),
    if (run.size > 0)
      chip(
        Icons.fitness_center_rounded,
        const Color(0xFFD7CCC8),
        '${l.eventBuffSize} ${pct(run.size)}',
      ),
    if (run.spd < 0)
      chip(
        Icons.speed_rounded,
        const Color(0xFFB0BEC5),
        '${l.eventBuffSpd} ${(run.spd * 100).round()}%',
      ),
    if (run.lastStand > 0)
      chip(
        Icons.local_fire_department_rounded,
        run.hpPct < EventDuelRun.lastStandBelow
            ? const Color(0xFFFF5252)
            : const Color(0x88FF5252),
        '${l.eventBuffLastStand} ${pct(run.lastStand)}',
      ),
    if (run.revives > 0)
      chip(
        Icons.autorenew_rounded,
        const Color(0xFFFFE082),
        l.eventBuffRevive(run.revives),
      ),
  ];
  if (chips.isEmpty) {
    return Text(
      l.eventBuffNone,
      style: const TextStyle(
        color: Color(0x88FFFFFF),
        fontSize: 11,
        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
      ),
    );
  }
  return Wrap(spacing: 4, runSpacing: 4, children: chips);
}

/// 대회 한 판을 결투 무대로 연다. 끝나면 결과 팝업(웨이브·점수·최고 기록).
Future<void> playEventDuel({
  required BuildContext context,
  required WidgetRef ref,
  required GameData data,
  required IndividualBug bug,
  required DuelBug mine,
  required int roundSeed,
  required EventDuelDriver driver,
  bool dev = false,
}) async {
  final locale = Localizations.localeOf(context).languageCode;
  final params = DuelParams.fromJson(
    (data.battleConfig ?? const BattleConfig()).duelJson,
  );
  final spec = driver.spec;
  DuelBug foe(int index) =>
      eventEnemyFor(data, spec, roundSeed, index + 1, locale);
  // 그만하기 — 확인 → 확정 → 결과. 조준·싸우는 중·카드 창에서 같은 흐름.
  Future<bool> quitFlow() async {
    final l = AppLocalizations.of(context);
    final ok = await showGameDialog<bool>(
      context,
      title: l.eventQuitTitle,
      icon: Icons.flag_rounded,
      content: Text(
        l.eventQuitBody(
          driver.run.cleared,
          (driver.run.hpPct * 100).round(),
          (spec.injuryRatio(driver.run.hpPct) * 100).round(),
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, height: 1.45),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          () => Navigator.pop(context, false),
          primary: false,
        ),
        gameDialogButton(l.eventQuit, () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true || !context.mounted) return false;
    if (!await driver.quit()) {
      // 실패를 알리지 않으면 조준 화면으로 돌아가 3초 뒤 저절로 던져졌다(2026-09-30 점검).
      if (context.mounted) showCenterToast(context, l.eventQuitFailed);
      return false;
    }
    final save = driver.quitSave;
    if (save != null) {
      await ref.read(saveControllerProvider.notifier).adoptServerSave(save);
    }
    if (!context.mounted) return true;
    await _showEventResult(context, driver, dev: dev);
    return true;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DuelArenaScreen(
        mine: [mine],
        foe: [foe(0)],
        foeAt: foe,
        foeIndex: () => driver.preview.wave - 1,
        header: () {
          final l = AppLocalizations.of(context);
          return l.eventWaveHeader(driver.preview.wave);
        },
        driver: driver,
        params: params,
        arena: mine.element,
        mySkins: {mine.id: bugView(ref.read(skinOfProvider), bug)},
        showDuelResult: false,
        // 장외·뒤집기·시간으로 졌지만 체력이 남았으면 — 왜 또 싸우는지 알려 준다.
        boutNote: (s) {
          if (s.bout.aWon || s.done) return null;
          final l = AppLocalizations.of(context);
          return s.bout.finish == DuelFinish.knockout
              ? l.eventReviveRetry
              : l.eventFallRetry((spec.fallPenalty * 100).round());
        },
        // 체력칸 아래 — 이번 웨이브에 실리는 강화(고른 카드까지).
        mineStatus: () =>
            eventBuffChips(AppLocalizations.of(context), driver.preview),
        onQuit: quitFlow,
        between: (last) async {
          if (driver.cards.isEmpty || !context.mounted) return false;
          // 카드 창의 그만하기 → 확인 → 취소하면 카드 창을 다시 연다.
          while (true) {
            if (!context.mounted) return false;
            final pick = await _pickCard(context, driver);
            // 안드로이드 뒤로가기로 닫혔다 — 카드 없이 던지면 서버가 거절해 판이 끊겼다
            // (참가권은 이미 썼다, 2026-09-30 점검). 다시 연다.
            if (pick == null) continue;
            if (pick != _quitPick) {
              driver.pendingCard = pick;
              return false;
            }
            if (await quitFlow()) return true;
          }
        },
        onFinished: (last) async {
          final save = last.save;
          if (save != null) {
            await ref
                .read(saveControllerProvider.notifier)
                .adoptServerSave(save);
          }
          if (!context.mounted) return;
          await _showEventResult(context, driver, dev: dev);
        },
      ),
    ),
  );
}

/// 카드 창에서 그만하기를 눌렀다는 표시(카드 id 와 겹치지 않는 값).
const _quitPick = '__quit__';

/// 카드 3장 중 1장 — 닫을 수 없다(골라야 다음 웨이브로 간다).
/// 한 줄에 한 장씩 세로로 쌓는다 — 가로 3칸이면 이름·설명이 잘렸다(2026-09-30 실기 지적).
Future<String?> _pickCard(BuildContext context, EventDuelDriver driver) {
  final l = AppLocalizations.of(context);
  return showGameDialog<String>(
    context,
    title: l.eventCardTitle(driver.run.cleared),
    icon: Icons.style_rounded,
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.eventCardHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 10),
        // 지금까지 받은 강화 — 무엇을 더 쌓을지 보고 고른다.
        Text(
          l.eventBuffNow,
          style: const TextStyle(
            color: Color(0xFFEBA52F),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        eventBuffChips(l, driver.run),
        const SizedBox(height: 10),
        for (final c in driver.cards)
          Builder(
            builder: (ctx) {
              final (name, desc) = cardText(l, c.id);
              return GestureDetector(
                onTap: () => Navigator.of(ctx).pop(c.id),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x22000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEBA52F),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      gameImage(
                        'assets/images/ui/cards/${c.id}.webp',
                        width: 42,
                        height: 42,
                        fallback: Text(
                          cardGlyph(c.kind),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFEBA52F),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 6),
        // 그만하기 — 카드를 고르지 않고 여기서 기록을 확정한다.
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(_quitPick),
          icon: const Icon(Icons.flag_rounded, size: 16),
          label: Text(l.eventQuit),
          // 글자색은 팝업 그림 버튼 기본(크림)으로 — 회색 나무 위 분홍은 흐릿했다. 위험 표시는 아이콘으로만.
          style: TextButton.styleFrom(iconColor: const Color(0xFFEF9A9A)),
        ),
      ],
    ),
  );
}

Future<void> _showEventResult(
  BuildContext context,
  EventDuelDriver driver, {
  required bool dev,
}) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.eventResultTitle(driver.run.cleared),
    icon: Icons.emoji_events_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.eventScore(driver.score),
          style: const TextStyle(
            color: Color(0xFFEBC24A),
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.eventStopHp,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5),
        ),
        if (driver.isBest && !dev) ...[
          const SizedBox(height: 6),
          Text(
            l.eventNewBest,
            style: const TextStyle(
              color: Color(0xFF6FCF6F),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        if (dev) ...[
          const SizedBox(height: 8),
          Text(
            l.eventDevPreview,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
          ),
        ],
      ],
    ),
    actions: [
      gameDialogButton(l.duelResultOk, () => Navigator.of(context).pop()),
    ],
  );
}
