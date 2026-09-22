import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../domain/audio_service.dart';
import '../l10n/app_localizations.dart';
import 'art.dart';
import 'format.dart';
import 'labels.dart';

const _honey = Color(0xFFEBA52F);

/// 팝업 내용 여백. 액자 테두리(26논리px)보다 넉넉해야 글자가 나무를 타지 않는다.
const kDialogFramePadding = EdgeInsets.fromLTRB(30, 28, 30, 26);

/// 액자 애셋이 없을 때 — 조용히 그라데이션 틀만 쓴다(폴백, §6).
void _frameMissing(Object e, StackTrace? s) {}

/// 등급·영예 아트를 팝업 제목에 쓴다(트로피·계급장·왕관).
Widget rankImageDlg(String name, {double size = 30}) => rankImage(
  name,
  size: size,
  fallback: Icon(
    switch (name) {
      'promote' => Icons.military_tech_rounded,
      'crown' => Icons.workspace_premium_rounded,
      _ => Icons.emoji_events_rounded,
    },
    size: size * 0.75,
    color: _honey,
  ),
);

/// 팝업 버튼 아트(9분할). `backgroundBuilder` 는 버튼의 배경색 **위에** 그려지고
/// 버튼 모양으로 잘린다 — 그래서 호출부가 준 `backgroundColor` 를 덮는다.
/// 애셋이 없으면 아무것도 그리지 않아 예전 색 버튼이 그대로 보인다(폴백, §6).
///
/// ⚠️ **팝업 안에서만** 쓴다(GameDialog 가 테마를 덮어쓴다). 앱 전체에 걸면
/// 홈·상점의 버튼 94개까지 나무로 바뀐다 — 요청 범위를 넘는다.
ButtonStyle _artButtonStyle(String asset, Rect slice) => ButtonStyle(
  shape: const WidgetStatePropertyAll(StadiumBorder()),
  // ⚠️ **글자색을 반드시 준다.** 배경은 아트가 그리는데 글자는 머티리얼
  // 기본색(FilledButton=onPrimary · TextButton=primary)이라, 나무·황동 위에서
  // 글자가 묻어 버튼이 비어 보였다(실기 지적 2026-09-20: 확률 보기·닫기·
  // 소탕·승급이 전부 안 읽혔다). 크림색 + 검은 그림자는 두 아트 모두에서 읽힌다.
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? const Color(0x99FFF3D0)
        : const Color(0xFFFFF3D0),
  ),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 13.5,
      shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)],
    ),
  ),
  iconColor: const WidgetStatePropertyAll(Color(0xFFFFF3D0)),
  // 아트가 배경을 담당하므로 그림자는 끈다(나무 위에 회색 그늘이 겹친다).
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  backgroundBuilder: (context, states, child) => Opacity(
    // 비활성은 흐리게 — 색 버튼일 때 disabledBackgroundColor 가 하던 일.
    opacity: states.contains(WidgetState.disabled) ? 0.4 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: ExactAssetImage(asset, scale: 3),
          centerSlice: slice,
          fit: BoxFit.fill,
          onError: _frameMissing,
        ),
      ),
      child: child,
    ),
  ),
);

final _primaryBtn = _artButtonStyle(
  'assets/images/ui/dialog/btn_primary.webp',
  const Rect.fromLTRB(57, 2, 549, 130),
);
final _secondaryBtn = _artButtonStyle(
  'assets/images/ui/dialog/btn_secondary.webp',
  const Rect.fromLTRB(54, 2, 443, 130),
);

/// 게임 톤(다크그린 + 허니 테두리)으로 통일된 다이얼로그. 모든 팝업은 이걸 쓴다.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required String title,
  IconData? icon,

  /// 아이콘 대신 그림을 넣고 싶을 때(장비 등). [icon] 보다 우선한다.
  Widget? iconWidget,
  String? subtitle,
  required Widget content,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0xB3000000),
    barrierDismissible: barrierDismissible,
    builder: (ctx) => GameDialog(
      title: title,
      icon: icon,
      iconWidget: iconWidget,
      subtitle: subtitle,
      actions: actions,
      child: content,
    ),
  );
}

class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.iconWidget,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final IconData? icon;
  final Widget? iconWidget;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Theme(
        // 팝업 안의 버튼만 나무 아트로. 확인·실행 = 황동, 취소·닫기 = 회색 나무.
        //
        // ⚠️ **merge 는 수신자가 이긴다**(`a.merge(b)` = a 의 값을 남기고
        // 빈 칸만 b 로 채운다). 전역 테마를 앞에 두면 거기서 정한 값이
        // 팝업 스타일을 덮어 버린다 — `main.dart` 의 `styleFrom` 이
        // disabled 색만 주려고 해도 `foregroundColor` **속성 전체**를
        // 채워 놓기 때문에, 팝업이 준 글자색이 통째로 무시됐다
        // (2026-09-20: 글자색을 넣었는데 화면이 그대로였던 원인).
        // 그래서 **팝업 스타일을 앞에** 둔다.
        data: theme.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: _primaryBtn.merge(theme.filledButtonTheme.style),
          ),
          textButtonTheme: TextButtonThemeData(
            style: _secondaryBtn.merge(theme.textButtonTheme.style),
          ),
          // 승급 팝업의 재료 목록(체크박스)·등급 칩도 같은 판 위에 있다.
          checkboxTheme: theme.checkboxTheme.copyWith(
            fillColor: WidgetStateProperty.resolveWith(
              (st) => st.contains(WidgetState.selected)
                  ? _honey
                  : const Color(0x22FFFFFF),
            ),
            checkColor: const WidgetStatePropertyAll(Color(0xFF3A2600)),
            side: const BorderSide(color: Color(0x88FFFFFF)),
          ),
          chipTheme: theme.chipTheme.copyWith(
            backgroundColor: const Color(0x22FFFFFF),
            selectedColor: _honey,
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            secondaryLabelStyle: const TextStyle(
              color: Color(0xFF3A2600),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
            side: const BorderSide(color: Color(0x33FFFFFF)),
            checkmarkColor: const Color(0xFF3A2600),
          ),
        ),
        child: Container(
          // 나무 액자 아트(9분할) — 애셋이 없으면 예전 그라데이션 틀로 떨어진다.
          // 내용 여백은 **테두리 두께(26)보다 커야** 글자가 나무에 올라타지 않는다.
          padding: kDialogFramePadding,
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: ExactAssetImage(
                'assets/images/ui/dialog/frame.webp',
                // 3배 해상도로 저장했다 — scale 을 주지 않으면 centerSlice 의
                // 모서리가 원본 픽셀(77) 그대로 찍혀 테두리가 3배로 두꺼워진다.
                scale: 3,
              ),
              centerSlice: Rect.fromLTRB(77, 76, 499, 494),
              fit: BoxFit.fill,
              onError: _frameMissing,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF21F2E13), Color(0xF20E1608)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 18),
            ],
          ),
          child: Container(
            // 나무 액자 가운데는 밝은 올리브다 — 그 위에 흰 글씨를 바로 얹으면
            // 대비가 모자라 흐릿하게 읽힌다. **어두운 속판**을 깔아 글씨를
            // 받치고, 나무는 테두리로만 보이게 한다.
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xD9121C0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33000000)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 머리말도 **가운데**로. 본문은 대부분 가운데 정렬인데 제목만
                // 왼쪽이라 창 전체가 어긋나 보였다(실기 지적 2026-09-18).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconWidget != null) ...[
                      SizedBox(width: 40, height: 40, child: iconWidget),
                      const SizedBox(width: 10),
                    ] else if (icon != null) ...[
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x33EBA52F),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x88EBA52F)),
                        ),
                        child: Icon(icon, color: _honey, size: 19),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16.5,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _honey,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0x33EBA52F)),
                ),
                // 본문은 **스크롤 가능**해야 한다 — 설정·계정처럼 줄이 많은 창은
                // 작은 화면에서 다이얼로그가 화면보다 커진다(세로 오버플로우).
                // 머리말·버튼은 고정하고 본문만 흐르게 둔다.
                Flexible(child: SingleChildScrollView(child: child)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  // 버튼은 **줄바꿈**한다. 한 줄 고정이면 버튼이 3개만 넘어도
                  // 가로로 넘쳐 잘린다(계정 창 = 닫기·로그인·삭제·약관).
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 게임 다이얼로그용 주/보조 버튼.
Widget gameDialogButton(
  String label,
  VoidCallback onPressed, {
  bool primary = true,
  Color? color,
}) {
  if (primary) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? _honey,
        foregroundColor: const Color(0xFF3A2600),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: const Color(0xCCFFFFFF)),
    child: Text(label),
  );
}

/// 보상(골드 + 재료들)을 종류별로 나열하는 위젯. 팝업 본문에 넣는다.
Widget gameRewardList(
  BuildContext context, {
  int gold = 0,
  int xp = 0,
  Map<MaterialKind, int> materials = const {},
}) {
  final l = AppLocalizations.of(context);
  final rows = <Widget>[];
  if (gold > 0) {
    rows.add(_rewardRow(goldIcon(size: 26), l.curGold, formatCompact(gold)));
  }
  if (xp > 0) {
    rows.add(
      _rewardRow(
        gameImage(
          'assets/images/upgrades/xp.webp',
          width: 26,
          height: 26,
          fallback: const Text('🔷', style: TextStyle(fontSize: 20)),
        ),
        l.offlineXpLabel,
        formatCompact(xp),
      ),
    );
  }
  for (final k in MaterialKind.values) {
    final v = materials[k] ?? 0;
    if (v <= 0) continue;
    rows.add(
      _rewardRow(
        materialImage(k, size: 26, fallback: Icon(materialIcon(k), size: 22)),
        materialLabel(l, k),
        formatCompact(v),
      ),
    );
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        rows[i],
      ],
    ],
  );
}

Widget _rewardRow(Widget icon, String name, String amount) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0x22000000),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0x1AFFFFFF)),
  ),
  child: Row(
    children: [
      SizedBox(width: 26, height: 26, child: Center(child: icon)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      Text(
        '+$amount',
        style: const TextStyle(
          color: _honey,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    ],
  ),
);

/// 보상 획득 결과 팝업(획득한 재화 종류별 나열).
Future<void> showRewardPopup(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.card_giftcard_rounded,

  /// 아이콘 대신 그림. [icon] 보다 우선한다(팝업 제목 아트).
  Widget? iconWidget,
  int gold = 0,
  Map<MaterialKind, int> materials = const {},
}) {
  final l = AppLocalizations.of(context);
  AudioService.instance.sfxReward();
  return showGameDialog<void>(
    context,
    title: title,
    iconWidget: iconWidget,
    subtitle: subtitle,
    icon: icon,
    content: gameRewardList(context, gold: gold, materials: materials),
    actions: [gameDialogButton(l.actionClose, () => Navigator.pop(context))],
  );
}
