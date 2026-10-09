import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth_service.dart';
import '../domain/providers.dart';
import '../l10n/app_localizations.dart';
import 'game_dialog.dart';

/// 이 경고를 마지막으로 띄운 날(기기 로컬, yyyy-MM-dd).
const _kDateKey = 'guest.warnedDate';

/// 게스트(익명) 상태에서 진척 지점마다 **하루 1회** 데이터 유실 경고 + 로그인 유도.
///
/// 띄우는 조건:
/// 1. 로그인하지 않은 게스트
/// 2. 사냥터 보스를 잡고 넘어간 시점([stage] 는 기록용) — 오늘 아직 안 띄웠음
///    또는 [afterPurchase] — 결제 직후에는 **하루 상한 없이** 띄운다(산 물건을 잃는 게 가장 큰 손해).
///
/// ⚠️ 예전 조건 "스테이지가 10의 배수"는 사냥터 구조(스테이지가 1·101·201… 로만 움직임)에서 **한 번도
/// 맞지 않아** 경고가 영영 안 떴다 — 게스트로 하다 앱을 지워 계정(과 산 스킨)을 잃고 새 계정을 만드는 유저가
/// 나왔다(2026-10-09 결제 이상 알림). 하루 1회 상한은 그대로 둔다 — 반복 팝업은 확실한 이탈 요인이다.
Future<void> maybeWarnGuest(
  BuildContext context,
  WidgetRef ref,
  int stage, {
  bool afterPurchase = false,
}) async {
  final auth = ref.read(authServiceProvider);
  if (!auth.available || auth.isSignedIn) return;

  if (!afterPurchase) {
    final prefs = await SharedPreferences.getInstance();
    final now = ref.read(clockProvider).now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString(_kDateKey) == today) return;
    await prefs.setString(_kDateKey, today);
  }

  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final signIn = await showGameDialog<bool>(
    context,
    title: l.guestWarnTitle,
    icon: Icons.cloud_off_rounded,
    content: Text(
      afterPurchase ? l.guestWarnPurchaseBody : l.guestWarnBody,
      style: const TextStyle(
        color: Color(0xD9FFFFFF),
        fontSize: 13.5,
        height: 1.45,
      ),
    ),
    actions: [
      gameDialogButton(l.actionClose, () => Navigator.pop(context, false)),
      gameDialogButton(l.guestNudgeSignIn, () => Navigator.pop(context, true)),
    ],
  );
  if (signIn != true || !context.mounted) return;

  try {
    // iOS 는 Apple, 그 외는 구글. (Apple 4.8 — 제3자 로그인이 있으면 함께 제공)
    if (auth.appleAvailable) {
      await auth.signInWithApple();
    } else {
      await auth.signInWithGoogle();
    }
  } catch (e) {
    debugPrint('게스트 경고에서 로그인 실패: $e');
  }
}
