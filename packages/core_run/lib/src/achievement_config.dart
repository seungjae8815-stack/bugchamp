import 'package:meta/meta.dart';

/// 업적 · 칭호(2026-11-10 사장님 확정, `run_config.json → achievements`).
///
/// 보상은 **칭호만**(꾸밈 — 능력치·재화 없음). 재화를 주면 서버가 업로드마다 그 몫을 따로 인정해야 하고,
/// 칭호는 세이브에서 바로 계산되는 달성 여부만 보면 된다(core_save `achievementDone` — 앱·서버 같은 함수).
/// [kind]: `dexDiscover` 발견 종 · `dexConquer` 정복 종 · `dexVariant` 이색 종 · `bosses` 보스 수집 ·
/// `tier` 가 본 최고 난이도(0 쉬움 ~ 3 극한) · `abyss` 심연 역대 최고 층 · `league` 결투 리그(0 브론즈 ~ 4 다이아) ·
/// `level` 캐릭터 레벨 · `forge` 공방 레벨 · `kotk` 왕중왕전 최고 성적(64 ÷ 순위) · `specimens` 표본 수.
@immutable
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.kind,
    required this.goal,
    this.title = const {},
    this.desc = const {},
  });

  final String id;
  final String kind;
  final int goal;
  final Map<String, String> title;
  final Map<String, String> desc;

  static const kinds = {
    'dexDiscover',
    'dexConquer',
    'dexVariant',
    'bosses',
    'tier',
    'abyss',
    'league',
    'level',
    'forge',
    'kotk',
    'specimens',
  };

  factory AchievementDef.fromJson(Map<String, dynamic> j) {
    Map<String, String> text(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    return AchievementDef(
      id: j['id'] as String,
      kind: j['kind'] as String,
      goal: (j['goal'] as num).toInt(),
      title: text(j['title']),
      desc: text(j['desc']),
    );
  }
}
