import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/bug_grade.dart';
import '../../ui/colors.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';

/// 표본함 아이콘 그림(채집함 앱바·팝업 제목 공용).
Widget specimenBoxIcon({double size = 30}) => gameImage(
  'assets/images/ui/specimen_box.webp',
  width: size,
  height: size,
  fallback: Icon(Icons.museum_rounded, size: size * 0.8, color: kHoney),
);

/// 표본함(2026-11-10 사장님 확정) — 왕중왕전에서 져 표본이 된 곤충. 채집함과 따로 보이고 칸을 차지하지 않는다.
/// 결투·대회·펫·짝짓기·먹이 어디에도 못 쓴다(진 곤충은 소모된다) — 보기만 한다.
/// 2026-11-12: 도감 옆 버튼 · 진열장 두 줄을 옆으로 넘기는 벽(한 화면에 여러 개). [preview] 를 주면 그 곤충들을
/// 표본처럼 보여 준다(개발자 모드 확인용, 세이브는 그대로).
Future<void> showSpecimenBox(
  BuildContext context, {
  List<IndividualBug>? preview,
}) {
  final l = AppLocalizations.of(context);
  return showGameDialog<void>(
    context,
    title: l.specimenBoxTitle,
    iconWidget: specimenBoxIcon(),
    content: Consumer(
      builder: (context, ref, _) {
        final save = ref.watch(saveControllerProvider).value;
        final data = ref.watch(gameDataProvider).value;
        if (save == null || data == null) return const SizedBox.shrink();
        final list =
            preview ??
            [
              for (final b in save.bugs)
                if (save.retiredBugs.contains(b.id)) b,
            ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preview != null
                  ? '개발자 미리보기 — 실제 표본이 아니에요'
                  : keepWords(l.specimenBoxBody),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l.specimenBoxEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            else
              _Wall(
                list: list,
                data: data,
                // 미리보기는 순위를 돌아가며 붙여 금테(16강 이상)도 보이게.
                records: preview == null
                    ? save.specimenRecords
                    : {
                        for (final (i, b) in preview.indexed)
                          b.id: '1:${const [2, 4, 8, 16, 32][i % 5]}',
                      },
              ),
          ],
        );
      },
    ),
    actions: [gameDialogButton(l.actionClose, popOnTap(context))],
  );
}

/// 진열장 벽 — 두 줄, 옆으로 넘긴다(한 화면에 2열 × 2줄 + 다음 열이 살짝 보인다).
class _Wall extends StatelessWidget {
  const _Wall({
    required this.list,
    required this.data,
    this.records = const {},
  });
  final List<IndividualBug> list;
  final GameData data;

  /// 곤충 id → `회차:순위`(SaveGame.specimenRecords).
  final Map<String, String> records;

  /// 진열장 그림(`ui/specimen_case.webp`, 가로 1000×583) 비율. 곤충·이름표 자리도 이 그림 기준 비율이다.
  static const _caseAspect = 1000 / 583;
  static const _gap = 8.0;
  static const _detailH = 16.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return LayoutBuilder(
      builder: (context, box) {
        final cellW = (box.maxWidth - _gap) * 0.46;
        final cellH = cellW / _caseAspect + 2 + _detailH;
        final rows = list.length == 1 ? 1 : 2;
        return SizedBox(
          height: rows * cellH + (rows - 1) * _gap,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: rows,
              mainAxisExtent: cellW,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final b = list[i];
              final sp = data.speciesById[b.speciesId];
              if (sp == null) return const SizedBox.shrink();
              return _card(l, lang, b, sp);
            },
          ),
        );
      },
    );
  }

  Widget _card(AppLocalizations l, String lang, IndividualBug b, Species sp) {
    final rarity = bugRarityOf(data, b, sp);
    // 왕중왕전 기록(2026-11-12) — "제N회 M강" · 16강 이상은 금테 진열장(진 곤충에 대한 위로).
    final rec = records[b.id]?.split(':');
    final round = rec == null ? null : int.tryParse(rec.first);
    final place = rec == null || rec.length < 2 ? null : int.tryParse(rec[1]);
    final gold = place != null && place <= 16;
    final recLabel = round == null || place == null || round <= 0
        ? null
        : '${l.kotkRound('$round')} ${switch (place) {
            1 => l.kotkPlace1,
            2 => l.kotkPlace2,
            _ => l.kotkPlaceN('$place'),
          }}';
    // 그림이 없으면 나무 테 + 초록 바탕(같은 자리 배치).
    final fallbackCase = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF6B4226), width: 4),
        color: const Color(0xFF1E4A3A),
      ),
      child: const SizedBox.expand(),
    );
    const detail = TextStyle(
      color: Color(0xDDFFFFFF),
      fontSize: 10,
      fontWeight: FontWeight.w800,
    );
    return Column(
      children: [
        AspectRatio(
          aspectRatio: _caseAspect,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(
                    child: gameImage(
                      'assets/images/ui/specimen_case.webp',
                      width: w,
                      height: h,
                      fit: BoxFit.fill,
                      fallback: fallbackCase,
                    ),
                  ),
                  // 초록 바탕 자리(그림의 10~72%) — 표본이라 색을 조금 바랜 듯이(살아 있는 채집함 곤충과 갈라 보이게).
                  Positioned(
                    left: w * 0.1,
                    right: w * 0.1,
                    top: h * 0.1,
                    height: h * 0.62,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.75, 0.2, 0.05, 0, 8, //
                        0.15, 0.75, 0.05, 0, 6, //
                        0.1, 0.15, 0.6, 0, 0, //
                        0, 0, 0, 1, 0,
                      ]),
                      child: bugStageImage(
                        sp.id,
                        LifeStage.adult,
                        size: h * 0.6,
                        sex: b.sex,
                        fallback: bugAvatar(sp, size: h * 0.45),
                      ),
                    ),
                  ),
                  if (gold)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFFFFD54F),
                              width: 2.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66FFD54F),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // 아래 나무 받침(그림의 73~92%)에 놋쇠 이름표.
                  Positioned(
                    left: w * 0.18,
                    right: w * 0.18,
                    top: h * 0.755,
                    height: h * 0.135,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9B865), Color(0xFF9C7631)],
                        ),
                        border: Border.all(color: const Color(0xFF5E4519)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          sp.name.resolve(lang),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF2B1D07),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: _detailH,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bugRarityOn(data)) ...[
                rarityGem(rarity, size: 9),
                const SizedBox(width: 2),
                Text(gradeLabel(l, rarity), style: detail),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  recLabel != null
                      ? '$recLabel · ${formatSizeMm(b.sizeMm)}mm'
                      : '${formatSizeMm(b.sizeMm)}mm · Lv.${b.level}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gold
                      ? detail.copyWith(color: const Color(0xFFFFE082))
                      : detail,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
