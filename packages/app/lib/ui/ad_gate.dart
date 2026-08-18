import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ad_service.dart';
import '../domain/providers.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'toast.dart';

// ── 무효 트래픽 방어 (2026-08-18 애드몹 정지 후 도입) ─────────────────
//
// 초기 앱은 기기 수가 적어서, **한 기기가 하루 수십 번** 보상형을 끝까지 보면
// 그 몇 대가 트래픽의 대부분이 된다 — 광고망이 보기엔 전형적인 무효 트래픽이다.
// (기능별 상한 합계가 광고 40회+/일 이었다: 티켓 30 + 버프 12 + 새로고침 등.)
//
// 그래서 기능별 상한과 **별도로**, 기기 전체에 두 겹을 더 깐다:
//   · 연속 시청 쿨다운 — 사람이 아니라 기계처럼 보이는 패턴을 끊는다
//   · 기기 일일 총량 — 어떤 기능 조합으로도 이 위를 못 넘는다
//
// 광고망을 바꿔도(유니티·앱러빈…) 이 관문은 그대로 쓴다 — `AdService` 구현만
// 갈아끼우면 되고, 방어는 구현이 아니라 이 관문에 있다.
//
// 수치는 밸런스가 아니라 **계정 생존 조건**이라 JSON 이 아닌 여기 둔다(§6 예외).
const _adCooldown = Duration(seconds: 45);
const _adDeviceDailyCap = 20;
const _adGuardKey = 'ad_guard_v1'; // "날짜|횟수|마지막epoch초"

/// 보상형 광고를 보여주고 **보상을 줘도 되는지** 돌려준다.
///
/// 광고가 걸린 보상은 전부 이 함수를 거친다 — 보상 지급 조건을 한 곳에 모아둬야
/// "어떤 화면에선 광고 안 보고도 받아지더라" 같은 구멍이 안 생긴다.
///
/// true 가 아닐 땐 이유에 맞는 안내를 띄우고 false 를 돌려주므로,
/// 호출부는 `if (await watchAdForReward(...)) { 지급 }` 만 하면 된다.
///
/// [feature]·[dailyLimit] 을 주면 **하루 시청 횟수 상한**을 먼저 확인한다.
/// 지금은 결투 티켓만 상한이 있다(다른 보상형 광고는 구조적 상한이 이미 있음).
/// 실제 카운트 증가는 보상을 확정하는 쪽(서버 엔드포인트 / SaveController)에서
/// 한다 — 여기서 올리면 "광고는 봤는데 지급은 실패" 때 횟수만 날아간다.
Future<bool> watchAdForReward(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l, {
  String? feature,
  int dailyLimit = 0,
}) async {
  final save = ref.read(saveControllerProvider).value;
  final now = ref.read(clockProvider).now().toUtc();

  // 안내는 화면 **가운데**로(ui/toast.dart). 하단 SnackBar 는 탭바·버튼과
  // 겹쳐 잘 안 보인다 — 2026-08-06 결정.
  void snack(String msg) {
    if (context.mounted) showCenterToast(context, msg);
  }

  // 하루 상한(서버가 세는 값과 같은 UTC 날짜 기준).
  if (save != null && feature != null && dailyLimit > 0) {
    final used = save.adUseCount(feature, dailyDateKey(now));
    if (used >= dailyLimit) {
      snack(l.adDailyLimit(dailyLimit));
      return false;
    }
  }

  // 광고 제거·패스 구매자는 광고를 **건너뛰고 즉시 보상**받는다.
  // (사장님 결정 2026-08-06) 강제 광고만 없애면 보상형 광고를 계속 봐야 해서
  // "광고 제거"를 산 의미가 없다. 대신 하루 상한은 위에서 똑같이 적용되므로
  // 결제로 판수를 더 사는 것이 아니라 **시간만** 아끼는 게 된다.
  if (save != null && save.adsHidden(now)) return true;

  final svc = ref.read(adServiceProvider);

  // 무효 트래픽 방어 — **실광고일 때만**. 개발용 더미(NoAdService)는 광고
  // 요청이 없으므로 막을 트래픽도 없고, 막으면 개발만 번거로워진다.
  SharedPreferences? prefs;
  if (svc.isReal) {
    prefs = await SharedPreferences.getInstance();
    final parts = (prefs.getString(_adGuardKey) ?? '||').split('|');
    final today = dailyDateKey(now);
    final count = parts[0] == today ? (int.tryParse(parts[1]) ?? 0) : 0;
    final lastEpoch = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0;
    final sinceLast = now.difference(
      DateTime.fromMillisecondsSinceEpoch(lastEpoch * 1000, isUtc: true),
    );
    if (count >= _adDeviceDailyCap) {
      snack(l.adDailyLimit(_adDeviceDailyCap));
      return false;
    }
    if (sinceLast < _adCooldown) {
      snack(l.adCooldown((_adCooldown - sinceLast).inSeconds + 1));
      return false;
    }
  }

  final result = await svc.showRewarded();
  if (result == AdResult.rewarded) {
    // 끝까지 본 것만 센다 — 실패·중도 이탈은 트래픽으로 안 잡힌다.
    if (prefs != null) {
      final today = dailyDateKey(now);
      final parts = (prefs.getString(_adGuardKey) ?? '||').split('|');
      final count = parts[0] == today ? (int.tryParse(parts[1]) ?? 0) : 0;
      await prefs.setString(
        _adGuardKey,
        '$today|${count + 1}|${now.millisecondsSinceEpoch ~/ 1000}',
      );
    }
    return true;
  }

  final msg = switch (result) {
    AdResult.dismissed => l.adDismissed,
    AdResult.notReady => l.adNotReady,
    AdResult.failed => l.adFailed,
    AdResult.rewarded => '', // 위에서 반환됨
  };
  if (context.mounted) snack(msg);
  return false;
}
