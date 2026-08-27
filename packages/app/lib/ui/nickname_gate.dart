import 'package:core_models/core_models.dart' show ChatRules;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import '../domain/pvp_backend.dart';
import '../domain/save_controller.dart';
import '../domain/server_sync.dart';
import '../l10n/app_localizations.dart';

/// 닉네임 검증 한 곳: 빈 값 → 금칙어 → **중복(온라인)** 순.
/// 통과하면 null, 아니면 사용자에게 보여줄 오류 문구를 돌려준다.
///
/// 중복 검사는 [PvpBackend.isNicknameTaken] — 로컬/실패 시 false 라
/// 이름 짓기를 막지 않는다(완전한 차단은 서버 unique 인덱스 담당).
Future<String?> validateNickname(
  WidgetRef ref,
  AppLocalizations l,
  String name,
) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return l.nicknameRequiredBody;
  final rules =
      ref.read(gameDataProvider).value?.chatRules ?? const ChatRules();
  // 문자 구성과 금칙어를 **따로 안내한다** — 한 문구로 뭉치면 유저가 뭘
  // 고쳐야 할지 모른다(이모지를 넣었는데 "표현이 부적절"이라고 나온다).
  if (!rules.nicknameCharsOk(trimmed)) return l.nicknameBadChars;
  if (!rules.nicknameAllowed(trimmed)) return l.nicknameBlockedWord;
  // 내 현재 닉네임 그대로면 중복 검사 불필요(변경 아님).
  final save = ref.read(saveControllerProvider).value;
  if (save != null && save.nicknameSet && save.nickname == trimmed) return null;
  if (await ref.read(pvpBackendProvider).isNicknameTaken(trimmed)) {
    return l.nicknameTaken;
  }
  return null;
}

/// 닉네임 미확정이면 **정할 때까지 닫히지 않는** 다이얼로그를 띄운다.
///
/// 앱 시작 게이트(버전·점검) 통과 직후 호출 — 랭킹·채팅·PvP 에 기본 닉네임
/// ("채집가")이 도배되는 것을 막고, 첫 설정은 무료라 비용 문제도 없다.
Future<void> ensureNicknameSet(BuildContext context, WidgetRef ref) async {
  final save = ref.read(saveControllerProvider).value;
  if (save == null || save.nicknameSet) return;
  final l = AppLocalizations.of(context);
  final controller = TextEditingController();
  var checking = false;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xF21F2E13),
          title: Text(
            l.nicknameRequiredTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.nicknameRequiredBody,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 8,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l.settingsNicknameHint,
                  hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
                  errorText: error,
                  filled: true,
                  fillColor: const Color(0x22000000),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) {
                  if (error != null) setDialog(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: checking
                  ? null
                  : () async {
                      setDialog(() => checking = true);
                      final err = await validateNickname(
                        ref,
                        l,
                        controller.text,
                      );
                      if (!ctx.mounted) return;
                      if (err != null) {
                        setDialog(() {
                          error = err;
                          checking = false;
                        });
                        return;
                      }
                      await ref
                          .read(saveControllerProvider.notifier)
                          .renamePlayer(controller.text.trim());
                      // ⚠️ 즉시 서버에 올린다. 주기 업로드(60초)를 기다리다
                      //    앱을 끄면, 다음 실행에 서버의 옛 세이브를 채택하면서
                      //    닉네임이 날아가고 이 창이 매번 다시 뜬다.
                      await pushSaveNow(ref);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEBA52F),
                foregroundColor: const Color(0xFF3A2600),
              ),
              child: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.actionSave),
            ),
          ],
        ),
      ),
    ),
  );
}
