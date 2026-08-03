import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 시작 랭킹 팝업에 보여줄 한 컷.
@immutable
class RankReport {
  const RankReport({
    required this.rank,
    required this.previous,
    required this.daysAtTop,
  });

  /// 이번에 확인한 순위(1-based).
  final int rank;

  /// 직전에 확인했던 순위. 처음 확인이면 null.
  final int? previous;

  /// 1위를 며칠째 지키고 있는지(1위가 아니면 0, 오늘 막 1위가 됐으면 1).
  final int daysAtTop;

  /// 순위가 오른 폭(양수). 하락·변동없음·첫 확인이면 0.
  int get gained =>
      previous == null || previous! <= rank ? 0 : previous! - rank;

  /// 순위가 내린 폭(양수). 상승·변동없음·첫 확인이면 0.
  int get lost => previous == null || previous! >= rank ? 0 : rank - previous!;

  bool get isFirst => previous == null;
  bool get isSame => previous == rank;
  bool get isTop => rank == 1;
}

/// 랭킹 변동 이력(기기 로컬).
///
/// 세이브에 넣지 않는 이유: 표시 전용 기록이라 서버 권위와 무관하고,
/// 세이브에 넣으면 업로드 페이로드만 커진다(§ 비용). 기기를 바꾸면 초기화되며
/// 그때는 "처음 확인"으로 취급된다.
class RankHistory {
  RankHistory._();
  static final RankHistory instance = RankHistory._();

  static const _kRank = 'rank.last';
  static const _kTopSince = 'rank.topSince'; // 1위가 된 날(yyyy-MM-dd)

  /// [rank] 를 기록하고 직전 값과의 차이를 담은 리포트를 돌려준다.
  ///
  /// [today] 는 **로컬 날짜**(`DateTime.now()`) 기준 — 1위 유지 일수는 사용자가
  /// 체감하는 달력 날짜로 세는 게 자연스럽다.
  Future<RankReport> record(int rank, {required DateTime today}) async {
    SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('RankHistory: prefs 실패 — 변동 없이 표시 ($e)');
      return RankReport(
        rank: rank,
        previous: null,
        daysAtTop: rank == 1 ? 1 : 0,
      );
    }

    final previous = p.getInt(_kRank);
    final todayKey = _dateKey(today);

    var daysAtTop = 0;
    if (rank == 1) {
      final since = p.getString(_kTopSince);
      final start = since ?? todayKey;
      if (since == null) await p.setString(_kTopSince, todayKey);
      daysAtTop = _daysBetween(start, todayKey) + 1; // 당일 = 1일째
    } else {
      await p.remove(_kTopSince); // 1위에서 내려오면 연속 기록 종료
    }

    await p.setInt(_kRank, rank);
    return RankReport(rank: rank, previous: previous, daysAtTop: daysAtTop);
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 'yyyy-MM-dd' 두 개의 날짜 차이(일). 파싱 실패 시 0.
  static int _daysBetween(String from, String to) {
    final a = DateTime.tryParse(from);
    final b = DateTime.tryParse(to);
    if (a == null || b == null) return 0;
    final d = b.difference(a).inDays;
    return d < 0 ? 0 : d;
  }
}
