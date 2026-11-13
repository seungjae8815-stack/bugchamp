import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 신규 유저 이정표 기록(2026-11-09 사장님 확정) — 어디서 떠나는지를 **시각과 함께** 남긴다.
///
/// 이탈 조사(2026-11-09)를 세이브 상태로 거꾸로 추정해야 했다(언제 거기 닿았는지를 몰랐다).
/// 이제 이정표마다 처음 닿은 순간 한 줄을 Supabase `funnel_events` 에 남긴다
/// (시각은 서버가 찍고, 설치 뒤 경과는 조회 때 가입 시각과 뺀다 — `docs/_sql_20261109_funnel_events.sql`).
///
/// - 세이브가 아니라 별도 테이블이다 — 세이브 스키마·구버전 호환(`feat`)·업로드 크기를 건드리지 않는다.
/// - 보내는 것은 **이정표 이름뿐**이다(개인 데이터 없음 — Meta 로는 보내지 않는다, [MarketingService]).
/// - 판정은 세이브 상태에서 파생([funnelMilestones]) — `SaveController._commit` 한 곳에서 보므로
///   실시간·오프라인 정산·서버 세이브 채택 어느 경로로 닿아도 빠지지 않는다(도감 갱신과 같은 원칙).
/// - 이 기기·이 계정에서 **처음 볼 때 이미 지난 이정표는 보내지 않는다**(기준선) — 업데이트 직후 기존 유저의
///   옛 이정표가 한꺼번에 "지금" 시각으로 찍히지 않게. 다른 기기에서 서버 세이브를 받아도 DB 가 계정당 한 줄만 받는다.
/// - 실패하면 보내지 않은 것으로 남겨 5분 뒤 저장 때 다시 보낸다(요청 10초 제한). 절대 던지지 않는다(게임은 그대로).
///
/// ⚠️ 이름을 더하면 SQL 의 `check (event in (...))` 목록도 함께 늘린다 — 없는 이름은 DB 가 거절한다.
const kFunnelEvents = [
  'zone2', // 쉬움 첫 보스 처치(사냥터 2 도착)
  'zone3',
  'zone5',
  'easy_clear', // 쉬움 최종 보스(보통 진입)
  'egg', // 첫 곤충(알) 획득
  'hatch', // 알이 아닌 곤충 보유(첫 부화)
  'pet', // 첫 펫 장착
  'daily', // 첫 일일보상 수령
  'level10',
  'duel_win', // 이번 주 결투 점수가 생김(첫 승)
];

/// 이 세이브가 이미 닿은 이정표.
Set<String> funnelMilestones(SaveGame s) {
  final pastEasy = s.topTier > 0;
  return {
    if (pastEasy || s.bestStage >= 101) 'zone2',
    if (pastEasy || s.bestStage >= 201) 'zone3',
    if (pastEasy || s.bestStage >= 401) 'zone5',
    if (pastEasy) 'easy_clear',
    if (s.bugs.isNotEmpty) 'egg',
    if (s.bugs.any((b) => b.stage != LifeStage.egg)) 'hatch',
    if (s.equippedBugIds.isNotEmpty) 'pet',
    if (s.dailyClaims.containsKey('lunch') ||
        s.dailyClaims.containsKey('dinner'))
      'daily',
    if (s.level >= 10) 'level10',
    if (s.pvpTrophies > 0) 'duel_win',
  };
}

class FunnelLog {
  FunnelLog._();
  static final FunnelLog instance = FunnelLog._();

  static const _kDonePrefix = 'funnel.done.';

  bool _busy = false;

  /// 실패하면 이 시각까지 다시 보내지 않는다 — 저장은 방치 중 몇 초마다 일어나서, SQL 적용 전처럼 계속
  /// 실패하면 저장마다 요청이 나갔다(2026-11-09 검토).
  DateTime? _retryAfter;

  /// 세이브를 저장할 때마다 부른다(기다리지 않아도 된다).
  Future<void> observe(SaveGame s) async {
    if (_busy) return;
    final retry = _retryAfter;
    if (retry != null && DateTime.now().isBefore(retry)) return;
    _busy = true;
    try {
      final SupabaseClient client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        return; // Supabase 를 안 쓰는 빌드(키 없음)
      }
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kDonePrefix$uid';
      final reached = funnelMilestones(s);
      final stored = prefs.getStringList(key);
      if (stored == null) {
        // 처음 본다 — 이미 지난 이정표는 보내지 않고 기준선으로만 남긴다.
        await prefs.setStringList(key, reached.toList());
        return;
      }
      final fresh = reached.difference(stored.toSet());
      if (fresh.isEmpty) return;
      // 계정당 이정표 하나에 한 줄(기본키) — 다른 기기에서 이미 보낸 것은 DB 가 조용히 버린다.
      await client
          .from('funnel_events')
          .upsert(
            [
              for (final e in fresh) {'event': e},
            ],
            onConflict: 'user_id,event',
            ignoreDuplicates: true,
          )
          .timeout(const Duration(seconds: 10));
      await prefs.setStringList(key, {...stored, ...fresh}.toList());
      _retryAfter = null;
    } catch (e) {
      _retryAfter = DateTime.now().add(const Duration(minutes: 5));
      debugPrint('[funnel] 기록 실패(5분 뒤 다시): $e');
    } finally {
      _busy = false;
    }
  }
}
