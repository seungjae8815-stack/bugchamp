import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/skins.dart';
import '../../ui/toast.dart';

const _honey = Color(0xFFEBA52F);

/// 도감(§2.1) — 종 20개의 **영구 기록**.
///
/// 왜 필요한가: 채집함에 50~100마리를 모으는데 실제로 쓰이는 건 6마리(펫 3 +
/// 결투 3)뿐이고, 나머지는 합성 재료나 분해감이었다. 수집 게임인데 수집이
/// 보상되지 않았다. 도감은 곤충이 사라져도 남으므로 **모으는 행위 자체**에
/// 보상을 걸 수 있는 유일한 축이다.
class DexScreen extends ConsumerWidget {
  const DexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).requireValue;
    final save = ref.watch(saveControllerProvider).requireValue;
    final cfg = data.dexConfig;
    final locale = Localizations.localeOf(context).languageCode;
    final all = dexSpecies(data.allSpecies);

    final claimable = cfg == null
        ? const <DexMilestone>[]
        : cfg.claimable(save.dexDiscovered, save.dexConquered, save.claimedDex);

    return Scaffold(
      appBar: AppBar(title: Text(l.dexTitle)),
      body: Column(
        children: [
          _summary(context, ref, l, save, cfg, all.length, claimable),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.74,
              ),
              itemCount: all.length,
              itemBuilder: (context, i) =>
                  _tile(context, l, locale, all[i], save.dex[all[i].id]),
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 요약 — 발견/정복 진행도 + 지금 받을 수 있는 보상.
  Widget _summary(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    SaveGame save,
    DexConfig? cfg,
    int total,
    List<DexMilestone> claimable,
  ) {
    final discovered = save.dexDiscovered;
    final conquered = save.dexConquered;
    return Container(
      color: const Color(0xFF15200D),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _bar(
                  l.dexDiscovered,
                  discovered,
                  total,
                  const Color(0xFF6FCF6F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _bar(l.dexConquered, conquered, total, _honey)),
              const SizedBox(width: 10),
              // 이색은 1/300 이라 정복보다 훨씬 긴 목표다 — 머리에 띄워야
              // "아직 0/20 이네"가 계속 눈에 밟힌다(수집 게임의 제일 긴 축).
              Expanded(
                child: _bar(
                  l.dexVariant,
                  save.dexVariants,
                  total,
                  const Color(0xFFCE7AE0),
                ),
              ),
            ],
          ),
          if (cfg != null) ...[
            const SizedBox(height: 8),
            // 지금 붙어 있는 영구 보너스 — "모으면 세진다"가 숫자로 보여야 한다.
            Text(
              l.dexBonusSummary(
                (cfg.attackPerConquer * conquered * 100).toStringAsFixed(1),
                (cfg.hpPerConquer * conquered * 100).toStringAsFixed(1),
                (cfg.rewardPerDiscover * discovered * 100).toStringAsFixed(1),
              ),
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5),
            ),
          ],
          if (claimable.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _honey,
                  foregroundColor: const Color(0xFF3A2600),
                ),
                onPressed: () async {
                  final got = await ref
                      .read(saveControllerProvider.notifier)
                      .claimDexMilestones();
                  if (!context.mounted || got.isEmpty) return;
                  final gold = got.fold<int>(0, (a, m) => a + m.gold);
                  final jelly = got.fold<int>(0, (a, m) => a + m.jelly);
                  showCenterToast(
                    context,
                    l.dexClaimedSnack(formatCompact(gold), jelly),
                  );
                },
                icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                label: Text(l.dexClaim(claimable.length)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(String label, int now, int total, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5),
          ),
          const Spacer(),
          Text(
            '$now/$total',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: total <= 0 ? 0 : (now / total).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: const Color(0x33FFFFFF),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ],
  );

  /// 종 칸 하나. 미발견은 **실루엣**으로 — 뭐가 남았는지는 보이되 정체는 감춘다.
  Widget _tile(
    BuildContext context,
    AppLocalizations l,
    String locale,
    Species sp,
    DexEntry? entry,
  ) {
    final found = entry != null;
    final conquered = entry?.raisedToAdult ?? false;
    final variant = entry?.variantFound ?? false;
    // 한 종을 **끝까지** 모았는가 = 발견 + 정복 + 이색. 하나씩 채워 나가는
    // 느낌을 주려면 "완료"라는 종착점이 눈에 보여야 한다(2026-08-31 지시).
    final complete = found && conquered && variant;
    final art = bugStageImage(
      sp.id,
      LifeStage.adult,
      size: 54,
      fallback: bugAvatar(sp, size: 46),
    );
    return GestureDetector(
      onTap: () => _detail(context, l, locale, sp, entry),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          // 완료 칸은 배경까지 바꾼다 — 테두리만으로는 격자에서 안 읽힌다.
          color: complete ? const Color(0x33CE7AE0) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: complete
                ? const Color(0xFFCE7AE0)
                : conquered
                ? _honey
                : gradeColor(sp.grade).withValues(alpha: found ? 0.7 : 0.18),
            width: complete ? 2 : (conquered ? 1.6 : 1.2),
          ),
          boxShadow: complete
              ? [
                  BoxShadow(
                    color: const Color(0xFFCE7AE0).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              child: found
                  // 이색을 얻은 종은 도감 그림도 그 색으로 — 곤충이 사라져도
                  // "이 종의 이색을 가졌었다"가 눈에 남는다.
                  ? (variant
                        // 이색 기록이 있으면 **스킨과 같은 연출**(색+후광+반짝임)로
                        // 그린다 — 색만 바꾸면 "그림이 이상하다"로 읽힌다.
                        ? SkinAura(
                            effect: 'rainbow',
                            size: 54,
                            child: ColorFiltered(
                              colorFilter: bugSkinFilter('rainbow')!,
                              child: art,
                            ),
                          )
                        : art)
                  // 미발견: 같은 실루엣을 까맣게 칠한다. 크기·형태만 보이고
                  // 무슨 곤충인지는 모른다 — "뭐가 남았지"를 궁금하게 만든다.
                  : ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF0E1A0B),
                        BlendMode.srcIn,
                      ),
                      child: art,
                    ),
            ),
            const SizedBox(height: 3),
            Text(
              found ? sp.name.resolve(locale) : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: found ? Colors.white : const Color(0x66FFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              found ? formatSizeMm(entry.maxSizeMm) : '—',
              style: TextStyle(
                color: found ? _honey : const Color(0x44FFFFFF),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            // 진행 표식 — 무엇이 남았는지가 칸에서 바로 읽혀야 "하나씩
            // 모아 가는" 느낌이 난다. 완료는 왕관 하나로 갈음한다.
            SizedBox(
              height: 14,
              child: complete
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('👑', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 2),
                        Text(
                          'COMPLETE',
                          style: TextStyle(
                            color: Color(0xFFCE7AE0),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (conquered)
                          const Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: _honey,
                          ),
                        if (variant)
                          const Text('✨', style: TextStyle(fontSize: 10)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _detail(
    BuildContext context,
    AppLocalizations l,
    String locale,
    Species sp,
    DexEntry? entry,
  ) {
    final found = entry != null;
    showGameDialog<void>(
      context,
      title: found ? sp.name.resolve(locale) : '???',
      icon: Icons.menu_book_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!found)
            Text(
              l.dexNotFound,
              style: const TextStyle(color: Color(0x99FFFFFF), height: 1.4),
            )
          else ...[
            Text(
              gradeLabel(l, sp.grade),
              style: TextStyle(
                color: gradeColor(sp.grade),
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
            if (sp.desc != null) ...[
              const SizedBox(height: 6),
              Text(
                sp.desc!.resolve(locale),
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _row(l.dexMaxSize, formatSizeMm(entry.maxSizeMm)),
            _row(l.dexMaxPotential, '${entry.maxPotential}★'),
            _row(
              l.dexConquered,
              entry.raisedToAdult ? l.dexConqueredYes : l.dexConqueredNo,
            ),
            _row(
              l.dexVariant,
              entry.variantFound ? l.dexConqueredYes : l.dexConqueredNo,
            ),
            if (entry.raisedToAdult && entry.variantFound) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x33CE7AE0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCE7AE0)),
                ),
                child: Text(
                  '👑 ${l.dexComplete}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE9C2FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ],
          // 패시브는 **미발견이어도 보여준다** — "이 종을 잡으면 뭐가 좋은지"가
          // 보여야 도감이 목표가 된다. 정체(이름·생김새)만 감춘다.
          if (sp.passive != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x22EBA52F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _honey.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.speciesPassiveTitle,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    passiveText(l, sp.passive!),
                    style: const TextStyle(
                      color: _honey,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.speciesPassiveHint,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );
}
