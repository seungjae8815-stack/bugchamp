import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 아래 시트 머리 줄 맨 오른쪽의 닫기(X).
///
/// 내용이 긴 시트(`isScrollControlled`)는 화면을 꽉 채워 바깥을 누를 자리가 없고, 안이 스크롤이라
/// 끌어내리기도 잘 안 먹는다. 안드로이드는 뒤로가기로 닫히지만 **아이폰은 갇혔다**
/// (2026-10-19 사장님 — 채집함 곤충 상세에서 장착한 뒤 빠져나갈 수 없었다). 그런 시트는 머리 줄에 이걸 둔다.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.color = const Color(0xCCFFFFFF)});

  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).actionClose,
    visualDensity: VisualDensity.compact,
    icon: Icon(Icons.close_rounded, color: color, size: 22),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}
