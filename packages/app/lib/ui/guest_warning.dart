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

/// 몇 스테이지마다 상기시킬지. 보스는 스테이지마다 나오므로(habitatsPerStage=20)
/// 보스마다 띄우면 수 분에 한 번씩 방해하게 된다 — 로드맵 칸 단위로 띄운다.
const _kEveryStages = 10;

/// 게스트(익명) 상태에서 진척 지점마다 **하루 1회** 데이터 유실 경고 + 로그인 유도.
///
/// 띄우는 조건 — 셋 다 만족할 때만:
/// 1. 로그인하지 않은 게스트
/// 2. [stage] 가 [_kEveryStages] 의 배수(로드맵 칸을 하나 넘긴 시점)
/// 3. 오늘 아직 안 띄웠음
///
/// ⚠️ 상한을 없애지 말 것. 방치형 게임에서 반복 팝업은 가장 확실한 이탈 요인이다.
Future<void> maybeWarnGuest(
  BuildContext context,
  WidgetRef ref,
  int stage,
) async {
  if (stage <= 0 || stage % _kEveryStages != 0) return;

  final auth = ref.read(authServiceProvider);
  if (!auth.available || auth.isSignedIn) return;

  final prefs = await SharedPreferences.getInstance();
  final now = ref.read(clockProvider).now();
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  if (prefs.getString(_kDateKey) == today) return;
  await prefs.setString(_kDateKey, today);

  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final signIn = await showGameDialog<bool>(
    context,
    title: l.guestWarnTitle,
    icon: Icons.cloud_off_rounded,
    content: Text(
      l.guestWarnBody,
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
