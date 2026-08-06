import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_version.dart';
import '../../domain/audio_service.dart';
import '../../domain/auth_service.dart';
import '../../domain/server_sync.dart';
import '../../domain/update_checker.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_dialog.dart';
import '../../ui/nickname_gate.dart';
import '../app_shell.dart';

/// 앱 대문. **게임 화면 위에 다이얼로그를 겹치던 구조를 여기로 옮긴다.**
///
/// 순서: 버전/점검 게이트 → (첫 실행이면) 로그인 선택 → 서버 세이브 채택
///       → 닉네임 → [AppShell] 진입.
///
/// 게이트를 여기서 처리하는 이유: 예전엔 게임 화면이 먼저 뜨고 그 위에 차단
/// 다이얼로그가 얹혀서, 못 들어가는 상태인데 뒤로 게임이 보였다. 또 서버 동기화
/// 전에 닉네임을 묻는 경합도 있었다 — 여기서 한 줄로 세우면 둘 다 사라진다.
///
/// **2회차부터는 로그인 선택을 보여주지 않는다.** 매일 켜는 방치형 게임에서
/// 시작 탭이 하나 늘면 그대로 이탈로 이어진다 — 타이틀만 잠깐 보이고 자동 진입.
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

enum _Phase {
  /// 버전/점검 확인 중.
  checking,

  /// 입장 차단(업데이트 필요·점검·오프라인) — 재시도로만 풀린다.
  blocked,

  /// 첫 실행 — 로그인 선택을 기다린다.
  chooseLogin,

  /// 동기화·닉네임 처리 중.
  entering,
}

/// 로그인 선택 화면을 이미 본 적 있는지(기기 로컬).
const _kSeenKey = 'title.loginChoiceSeen';

class _TitleScreenState extends ConsumerState<TitleScreen> {
  _Phase _phase = _Phase.checking;
  UpdateVerdict _verdict = UpdateVerdict.none;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        AudioService.instance.init().then(
          (_) => AudioService.instance.startBgm(),
        ),
      );
      unawaited(_start());
    });
  }

  /// 버전 게이트부터 진입까지. 차단 상태면 [_Phase.blocked] 로 멈춘다.
  Future<void> _start() async {
    final verdict = await checkAppVersion();
    if (!mounted) return;

    // soft(권장 업데이트)는 막지 않는다 — 안내만 하고 통과시킨다.
    if (verdict != UpdateVerdict.none && verdict != UpdateVerdict.soft) {
      setState(() {
        _verdict = verdict;
        _phase = _Phase.blocked;
      });
      return;
    }
    if (verdict == UpdateVerdict.soft) await _showSoftUpdate();
    if (!mounted) return;

    // 이미 로그인했거나 선택 화면을 본 적 있으면 곧장 들어간다.
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kSeenKey) ?? false;
    final signedIn = ref.read(authServiceProvider).isSignedIn;
    if (!mounted) return;

    if (seen || signedIn) {
      await _enterGame();
      return;
    }
    setState(() => _phase = _Phase.chooseLogin);
  }

  Future<void> _showSoftUpdate() async {
    final l = AppLocalizations.of(context);
    await showGameDialog<void>(
      context,
      title: l.updateAvailableTitle,
      icon: Icons.system_update_rounded,
      content: Text(
        l.updateAvailableBody,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13.5),
      ),
      actions: [
        gameDialogButton(l.updateLater, () => Navigator.pop(context)),
        gameDialogButton(l.updateNow, () {
          unawaited(openStore());
          Navigator.pop(context);
        }),
      ],
    );
  }

  /// 차단 상태에서 "다시 시도" — 풀렸으면 그대로 진입한다.
  Future<void> _retry() async {
    setState(() => _busy = true);
    final next = await checkAppVersion();
    if (!mounted) return;
    if (next == UpdateVerdict.none || next == UpdateVerdict.soft) {
      setState(() {
        _busy = false;
        _phase = _Phase.checking;
      });
      await _start();
      return;
    }
    setState(() {
      _verdict = next;
      _busy = false;
    });
  }

  Future<void> _signIn({required bool apple}) async {
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    var ok = false;
    try {
      ok = apple ? await auth.signInWithApple() : await auth.signInWithGoogle();
    } catch (e) {
      debugPrint('로그인 실패: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // 취소·실패면 선택 화면에 그대로 머문다(게스트로도 갈 수 있게).
    if (ok) await _enterGame();
  }

  /// "게스트로 시작하기" — 바로 들여보내지 않고 **한 번 더 권유**한다.
  /// 계정 연동율이 낮아(설치 대비 한 자릿수) 여기서 한 번 잡아주는 게 크다.
  Future<void> _guestTapped() async {
    final l = AppLocalizations.of(context);
    final auth = ref.read(authServiceProvider);
    final signIn = await showGameDialog<bool>(
      context,
      title: l.guestNudgeTitle,
      icon: Icons.cloud_off_rounded,
      content: Text(
        l.guestNudgeBody,
        style: const TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 13.5,
          height: 1.45,
        ),
      ),
      actions: [
        gameDialogButton(
          l.guestNudgeContinue,
          () => Navigator.pop(context, false),
        ),
        if (auth.available)
          gameDialogButton(
            l.guestNudgeSignIn,
            () => Navigator.pop(context, true),
          ),
      ],
    );
    if (!mounted) return;
    if (signIn == true) {
      await _signIn(apple: auth.appleAvailable && !kIsWeb && Platform.isIOS);
      return;
    }
    await _enterGame();
  }

  /// 서버 세이브 채택 → 닉네임 → 게임 진입.
  Future<void> _enterGame() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.entering);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);

    // ⚠️ 닉네임보다 **동기화가 먼저**다. 서버 세이브를 채택하기 전에 물으면
    //    이미 닉네임이 있는 계정에도 입력창이 뜬다.
    await syncWithServer(ref);
    if (!mounted) return;
    await ensureNicknameSet(context, ref);
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 타이틀 아트. 없으면 숲 그라데이션으로 폴백(애셋 규칙 §6).
          Image.asset(
            'assets/images/ui/title_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2E5B37),
                    Color(0xFF1E3B28),
                    Color(0xFF11190B),
                  ],
                ),
              ),
            ),
          ),
          // 하단을 어둡게 — 버튼·버전 글씨가 배경 밝기와 무관하게 읽혀야 한다.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC000000)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                Text(
                  l.appTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 12),
                      Shadow(color: Color(0xFFE3A62F), blurRadius: 26),
                    ],
                  ),
                ),
                const Spacer(flex: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _body(l),
                ),
                const SizedBox(height: 18),
                Text(
                  kBuildLabel,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l) => switch (_phase) {
    _Phase.checking || _Phase.entering => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFFEBA52F),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.titleLoading,
          style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12.5),
        ),
      ],
    ),
    _Phase.blocked => _blocked(l),
    _Phase.chooseLogin => _loginChoice(l),
  };

  /// 업데이트 필요 / 점검 중 / 오프라인 — 게임으로 못 넘어간다.
  Widget _blocked(AppLocalizations l) {
    final (title, body) = switch (_verdict) {
      UpdateVerdict.hard => (l.updateRequiredTitle, l.updateRequiredBody),
      UpdateVerdict.maintenance => (l.maintenanceTitle, l.maintenanceBody),
      _ => (l.connectionRequiredTitle, l.connectionRequiredBody),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6121A0C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _pill(
              _verdict == UpdateVerdict.hard ? l.updateNow : l.retryButton,
              _busy
                  ? null
                  : (_verdict == UpdateVerdict.hard ? openStore : _retry),
              primary: true,
            ),
          ),
        ],
      ),
    );
  }

  /// 첫 실행 — 로그인 선택. 게스트를 **가장 크게** 둔다: 로그인을 강제하면
  /// 첫 진입 이탈이 커지고, Apple 심사에도 데모 계정을 내야 한다.
  Widget _loginChoice(AppLocalizations l) {
    final auth = ref.read(authServiceProvider);
    final showApple = auth.available && auth.appleAvailable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: _pill(
            l.titleStartGuest,
            _busy ? null : _guestTapped,
            primary: true,
          ),
        ),
        if (auth.available) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0x44FFFFFF))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  l.titleOr,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 12,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0x44FFFFFF))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _pill(
              l.accountSignIn,
              _busy ? null : () => _signIn(apple: false),
            ),
          ),
          if (showApple) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _pill(
                l.accountSignInApple,
                _busy ? null : () => _signIn(apple: true),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _pill(String label, VoidCallback? onTap, {bool primary = false}) =>
      FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary
              ? const Color(0xFFEBA52F)
              : const Color(0xCC1F2E13),
          foregroundColor: primary ? const Color(0xFF3A2600) : Colors.white,
          disabledBackgroundColor: const Color(0x55FFFFFF),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: primary
                ? BorderSide.none
                : const BorderSide(color: Color(0x55FFFFFF)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      );
}
