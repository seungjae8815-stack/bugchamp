import 'dart:math' as math;

import 'package:core_run/core_run.dart';

/// 개발판 미리보기 — 서버가 없을 때 순위표·상대 프로필이 **어떻게 보이는지** 확인하려고 만드는 가짜 데이터.
///
/// ⚠️ 릴리즈 빌드에서는 부르지 않는다(`kReleaseMode` 로 막는다). 숫자는 모양 확인용이지 게임 값이 아니다.
/// 같은 화면을 다시 열어도 같은 명단이 나오게 시드를 고정한다.

const kPreviewMyId = 'preview-me';

Map<String, dynamic> previewLeagueBoard({
  required String league,
  required String myNickname,
  required int myTrophies,
  required double myPower,
  required List<String> speciesIds,
  required BattleConfig cfg,
  required DateTime now,
  String? myId,
}) {
  final rng = math.Random(7);
  const total = 60;
  const myRank = 7;
  final rows = <Map<String, dynamic>>[];
  var trophies = 150;
  for (var r = 1; r <= total; r++) {
    final mine = r == myRank;
    trophies = math.max(0, trophies - rng.nextInt(6));
    rows.add({
      'rank': r,
      'user_id': mine ? (myId ?? kPreviewMyId) : 'preview-$r',
      'nickname': mine ? myNickname : '${_names[(r * 7) % _names.length]}$r',
      'trophies': mine ? math.max(myTrophies, trophies) : trophies,
      'power': mine
          ? myPower
          : myPower * (1.6 - r * 0.018) * (0.9 + rng.nextDouble() * 0.2),
      'badge': '',
      'sp': speciesIds[rng.nextInt(speciesIds.length)],
    });
  }
  final zones = cfg.leagueZones(total);
  final closed = seasonClosed(now, cfg);
  return {
    'season': 'preview',
    'league': league,
    'closed': closed,
    'endsAt': (closed ? seasonEndAt(now, cfg) : seasonCloseAt(now, cfg))
        .toIso8601String(),
    'newSeasonAt': seasonEndAt(now, cfg).toIso8601String(),
    'total': total,
    'promote': zones.promote,
    'demote': zones.demote,
    'me': {'rank': myRank, 'trophies': rows[myRank - 1]['trophies']},
    'top': rows,
  };
}

Map<String, dynamic> previewAbyssBoard({
  required String myNickname,
  required List<String> speciesIds,
  required BattleConfig cfg,
  required DateTime now,
  String? myId,
}) {
  final rng = math.Random(11);
  const total = 40;
  const myRank = 12;
  var floor = 68;
  final rows = <Map<String, dynamic>>[];
  for (var r = 1; r <= total; r++) {
    final mine = r == myRank;
    floor = math.max(2, floor - rng.nextInt(3));
    rows.add({
      'rank': r,
      'user_id': mine ? (myId ?? kPreviewMyId) : 'preview-a$r',
      'nickname': mine ? myNickname : '${_names[(r * 5) % _names.length]}$r',
      'floor': floor,
      'boss_pm': rng.nextInt(1000),
      'power': 5e8 * (1.5 - r * 0.02),
      'sp': speciesIds[rng.nextInt(speciesIds.length)],
    });
  }
  // 실제 순위 기준대로 — 층 → 보스 피해 %(높은 쪽이 위). 무작위로 두면 같은 층에서 순서가 뒤집혀 보인다.
  final me = rows[myRank - 1];
  rows.sort((a, b) {
    final f = (b['floor'] as int).compareTo(a['floor'] as int);
    return f != 0 ? f : (b['boss_pm'] as int).compareTo(a['boss_pm'] as int);
  });
  for (var i = 0; i < rows.length; i++) {
    rows[i]['rank'] = i + 1;
  }
  final closed = seasonClosed(now, cfg);
  return {
    'week': 'preview',
    'closed': closed,
    'endsAt': (closed ? seasonEndAt(now, cfg) : seasonCloseAt(now, cfg))
        .toIso8601String(),
    'newSeasonAt': seasonEndAt(now, cfg).toIso8601String(),
    'total': total,
    'me': {'rank': me['rank'], 'floor': me['floor']},
    'top': rows,
  };
}

/// 상대 프로필 미리보기 — 곤충 3마리(종·오행·전투력).
Map<String, dynamic> previewProfile(
  String userId,
  List<String> speciesIds,
  double power,
) {
  final rng = math.Random(userId.hashCode);
  const elements = ['wood', 'fire', 'earth', 'metal', 'water'];
  return {
    'userId': userId,
    'team': [
      for (var i = 0; i < 3; i++)
        () {
          final sp = speciesIds[rng.nextInt(speciesIds.length)];
          final el = elements[rng.nextInt(elements.length)];
          final p = power / 3 * (0.8 + rng.nextDouble() * 0.4);
          const tms = [
            'aggressive',
            'cautious',
            'cunning',
            'steadfast',
            'fickle',
          ];
          const spcs = ['strike', 'grip', 'toss'];
          return {
            'sp': sp,
            'element': el,
            'power': p,
            'bug': {
              'id': 'pv$i',
              'name': sp,
              'sp': sp,
              'el': el,
              'tm': tms[rng.nextInt(tms.length)],
              'spc': spcs[rng.nextInt(spcs.length)],
              'size': 40 + rng.nextInt(40),
              'hp': p * 2.2,
              'atk': p * 0.35,
              'def': p * 0.2,
              'spd': p * 0.12,
              if (rng.nextBool()) 'crit': 0.04,
              if (rng.nextBool()) 'eva': 0.03,
            },
          };
        }(),
    ],
  };
}

const _names = [
  '장수왕',
  '사슴벌레킹',
  '풍뎅이',
  '곤충박사',
  '숲지기',
  '반딧불',
  '매미소리',
  '톱날턱',
  '하늘소',
  '물장군',
];
