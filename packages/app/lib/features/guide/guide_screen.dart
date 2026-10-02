import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart' hide Element;
import 'package:core_models/core_models.dart' as cm show Element;
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/element_wheel.dart';
import '../../ui/labels.dart';
import '../battle/training_screen.dart' show trainStatLabel;

const _honey = Color(0xFFEBA52F);

/// 공략집 — 설정 → 공략집. 곤충 개체 변수(오행·주특기·기질·크기·포텐셜·특성·이색)와
/// 결투·훈련·짝짓기 용어를 한 곳에서 설명한다(2026-10-01 사장님 요청 — 오행 관계도가
/// 대회 화면 안에만 숨어 있어 어디에도 안 보였다).
///
/// 숫자는 **JSON 에서 읽는다**(§6) — 상극 배율·훈련 상한 보정·특성 %·이색 확률을 문구에
/// 박으면 밸런스를 바꿀 때 공략집만 옛 값으로 남는다(관계도 "1.5배"가 그렇게 남았다).
class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.guideTitle)),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                  child: Text(
                    l.guideIntro,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
                ..._sections(l, data),
              ],
            ),
    );
  }

  List<Widget> _sections(AppLocalizations l, GameData data) {
    final battle = data.battleConfig ?? const BattleConfig();
    final train = battle.training;
    final duel = DuelParams.fromJson(battle.duelJson);
    final pet = data.petConfig;
    String pct(double v) => '${(v * 100).round()}%';
    // 확률은 데이터에 소수(0.0033)로 있어 1/303 처럼 보인다 — 100 이상은 10 단위로 읽기 좋게.
    String odds(double p) {
      if (p <= 0) return '-';
      final n = 1 / p;
      return '1/${n >= 100 ? (n / 10).round() * 10 : n.round()}';
    }

    String mods(Map<TrainStat, int>? m) {
      if (m == null || m.isEmpty) return '';
      return [
        for (final s in TrainStat.values)
          if ((m[s] ?? 0) != 0)
            '${trainStatLabel(l, s)} ${m[s]! > 0 ? '+' : ''}${m[s]}',
      ].join(' · ');
    }

    return [
      _Section(
        icon: Icons.brightness_7_rounded,
        title: l.guideElementTitle,
        initiallyExpanded: true,
        children: [
          _p(l.guideElementBody(duel.restrainMult.toStringAsFixed(1))),
          const SizedBox(height: 10),
          const Center(child: ElementWheel(size: 240)),
          const SizedBox(height: 8),
          for (final e in ElementWheel.cycle)
            _line(
              l.guideElementLine(
                elementLabel(l, e),
                elementLabel(l, _beats(e)),
              ),
            ),
        ],
      ),
      _Section(
        icon: Icons.sports_mma_rounded,
        title: l.guideSpecialtyTitle,
        children: [
          _p(l.guideSpecialtyBody),
          for (final (s, desc) in [
            (Specialty.strike, l.guideSpecialtyStrike),
            (Specialty.grip, l.guideSpecialtyGrip),
            (Specialty.toss, l.guideSpecialtyToss),
          ])
            _item(specialtyLabel(l, s), desc, mods(train.specialtyMods[s]), l),
        ],
      ),
      _Section(
        icon: Icons.psychology_rounded,
        title: l.guideTemperamentTitle,
        children: [
          _p(l.guideTemperamentBody),
          for (final (t, desc) in [
            (Temperament.aggressive, l.guideTempAggressive),
            (Temperament.cautious, l.guideTempCautious),
            (Temperament.cunning, l.guideTempCunning),
            (Temperament.steadfast, l.guideTempSteadfast),
            (Temperament.fickle, l.guideTempFickle),
          ])
            _item(
              temperamentLabel(l, t),
              desc,
              mods(train.temperamentMods[t]),
              l,
            ),
        ],
      ),
      _Section(
        icon: Icons.straighten_rounded,
        title: l.guideSizeTitle,
        children: [
          _p(
            l.guideSizeBody(
              kStatMultiplierMin.toStringAsFixed(2),
              kStatMultiplierMax.toStringAsFixed(2),
            ),
          ),
        ],
      ),
      _Section(
        icon: Icons.star_rounded,
        title: l.guidePotentialTitle,
        children: [
          _p(
            l.guidePotentialBody(train.capPerPotential, pet?.synthFodder ?? 3),
          ),
        ],
      ),
      _Section(
        icon: Icons.auto_awesome_rounded,
        title: l.guideTraitTitle,
        children: [
          _p(l.guideTraitBody),
          for (final t in const [
            BugTrait.fierce,
            BugTrait.sturdy,
            BugTrait.vital,
            BugTrait.noble,
          ])
            _item(
              traitLabel(l, t),
              l.guideTraitEffect(
                pct(pet?.traitAttackBonus[t] ?? 0),
                pct(pet?.traitHpBonus[t] ?? 0),
              ),
              mods(train.traitMods[t]),
              l,
              color: traitColor(t),
            ),
        ],
      ),
      _Section(
        icon: Icons.favorite_rounded,
        title: l.guideBreedTitle,
        children: [
          _p(
            l.guideBreedBody(
              pct(pet?.breedingElementInherit ?? 0),
              pct(pet?.breedingTemperamentInherit ?? 0),
              pct(pet?.breedingTraitInherit ?? 0),
            ),
          ),
        ],
      ),
      _Section(
        icon: Icons.palette_rounded,
        title: l.guideVariantTitle,
        children: [
          _p(
            l.guideVariantBody(
              odds(pet?.variantWildChance ?? 0),
              odds(pet?.variantBreedChance ?? 0),
              odds(pet?.variantBreedParentChance ?? 0),
              odds(pet?.gachaVariantChance ?? 0),
              pct(pet?.variantAttackBonus ?? 0),
              pct(
                (pet?.variantAttackBonus ?? 0) * (pet?.variantBattleScale ?? 0),
              ),
            ),
          ),
        ],
      ),
      _Section(
        icon: Icons.egg_rounded,
        title: l.guideLifeTitle,
        children: [_p(l.guideLifeBody)],
      ),
      _Section(
        icon: Icons.stadium_rounded,
        title: l.guideDuelTitle,
        children: [
          _p(
            l.guideDuelBody(
              duel.roundSeconds.round(),
              duel.weakMult.toStringAsFixed(1),
            ),
          ),
        ],
      ),
      _Section(
        icon: Icons.fitness_center_rounded,
        title: l.guideTrainTitle,
        children: [_p(l.guideTrainBody(train.baseCap))],
      ),
    ];
  }

  /// [e] 가 이기는(상극) 오행.
  static cm.Element _beats(cm.Element e) {
    for (final o in cm.Element.values) {
      if (e.restrains(o)) return o;
    }
    return e;
  }

  static Widget _p(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        color: Color(0xE6FFFFFF),
        fontSize: 13,
        height: 1.45,
      ),
    ),
  );

  static Widget _line(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 3),
    child: Text(
      '· $t',
      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5),
    ),
  );

  static Widget _item(
    String name,
    String desc,
    String trainMods,
    AppLocalizations l, {
    Color color = _honey,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: BoxDecoration(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            color: color,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        if (trainMods.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            l.guideTrainCapMods(trainMods),
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: const Color(0x22000000),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // 펼침 타일의 위아래 구분선을 없앤다(카드 안이라 이중선이 된다).
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: _honey, size: 22),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
            ),
          ),
          iconColor: _honey,
          collapsedIconColor: const Color(0x99FFFFFF),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}
