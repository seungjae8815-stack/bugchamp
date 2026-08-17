import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart' hide Element;

import '../../data/game_data.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/labels.dart';
import '../battle/arena_widgets.dart';

const _honey = Color(0xFFEBA52F);

/// 이벤트 전투 무대 — PvP 아레나와 **같은 위젯**(`ArenaFighter`·`ArenaFloat`·
/// `ArenaBurst`)을 쓴다. 연출을 두 벌로 만들면 한쪽만 좋아지고 다른 쪽은 낡는다.
///
/// 배경은 대회 전용(`ui/event/arena_bg.webp`) — 관중이 둘러싼 통나무 무대라
/// "대회에 나왔다"가 화면에서 읽힌다. 없으면 오행 서식지 배경으로 폴백한다.
class EventArena extends StatelessWidget {
  const EventArena({
    super.key,
    required this.data,
    required this.mine,
    required this.foe,
    required this.mineSpeciesId,
    required this.mineHpFrac,
    required this.foeHpFrac,
    required this.stanceMine,
    required this.stanceFoe,
    required this.flashL,
    required this.flashR,
    required this.lungeDx,
    required this.shake,
    required this.floats,
    required this.bursts,
  });

  final GameData data;
  final BattleBug? mine;
  final BattleBug? foe;
  final String? mineSpeciesId;
  final double mineHpFrac;
  final double foeHpFrac;
  final Stance? stanceMine;
  final Stance? stanceFoe;
  final double flashL;
  final double flashR;

  /// 방향이 반영된 돌진 오프셋(왼쪽 파이터 기준, 오른쪽은 부호 반전).
  final double lungeDx;
  final double shake;
  final List<FloatText> floats;
  final List<BurstFx> bursts;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      // 오행 상극이 터질 때만 흔든다 — 매 라운드 흔들면 멀미가 나고,
      // "이번 한 방이 컸다"는 신호도 죽는다.
      offset: Offset(shake * 6 * (shake > 0.5 ? 1 : -1), 0),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              // 배경은 영역을 꽉 채워야 해서 `gameImage`(고정 크기)가 아니라
              // Image.asset 을 직접 쓴다. 없으면 오행 서식지 배경으로 폴백.
              child: Image.asset(
                'assets/images/ui/event/arena_bg.webp',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => foe == null
                    ? const ColoredBox(color: Color(0xFF1E3B28))
                    : biomeBackground(
                        foe!.element,
                        fallback: const ColoredBox(color: Color(0xFF1E3B28)),
                      ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: mine == null
                    ? const SizedBox.shrink()
                    : ArenaFighter(
                        data: data,
                        bug: mine!,
                        speciesId: mineSpeciesId,
                        hpFrac: mineHpFrac.clamp(0.0, 1.0),
                        flip: false,
                        stance: stanceMine,
                        flash: flashL,
                        dx: lungeDx,
                      ),
              ),
              Expanded(
                child: foe == null
                    ? const SizedBox.shrink()
                    : ArenaFighter(
                        data: data,
                        // 적은 이벤트가 만든 유닛이라 종 그림이 없다 —
                        // `speciesId` 를 주지 않으면 위젯이 기본 아이콘으로 그린다.
                        bug: foe!,
                        speciesId: null,
                        hpFrac: foeHpFrac.clamp(0.0, 1.0),
                        flip: true,
                        stance: stanceFoe,
                        flash: flashR,
                        dx: -lungeDx,
                      ),
              ),
            ],
          ),
          for (final b in bursts) ArenaBurst(fx: b),
          for (final f in floats) ArenaFloat(f: f),
        ],
      ),
    );
  }
}

/// 웨이브 진행 바 — 숫자만 있으면 "얼마나 왔는지" 감이 없다.
/// **5의 배수마다 눈금**을 찍어 목표(다음 고비)를 만든다.
class WaveProgress extends StatelessWidget {
  const WaveProgress({
    super.key,
    required this.wave,
    required this.maxWave,
    this.nextElement,
  });

  final int wave;
  final int maxWave;

  /// 다음 웨이브의 대표 오행 — 미리 알려주면 카드 선택에 계획이 생긴다
  /// ("다음이 불이니 이번엔 방어를 챙기자").
  final Element? nextElement;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final frac = maxWave <= 0 ? 0.0 : (wave / maxWave).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.eventWaveRecord(wave),
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
            const Spacer(),
            if (nextElement != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: elementColor(nextElement!).withValues(alpha: 0.8),
                  ),
                ),
                child: Text(
                  '${l.eventNextWave} ${elementGlyph(nextElement!)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (c, box) => SizedBox(
            height: 8,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(_honey),
                  ),
                ),
                // 5의 배수 눈금 — 다음 고비가 어디인지 보인다.
                for (var w = 5; w < maxWave; w += 5)
                  Positioned(
                    left: box.maxWidth * (w / maxWave) - 1,
                    child: Container(
                      width: 2,
                      height: 8,
                      color: const Color(0x66000000),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
