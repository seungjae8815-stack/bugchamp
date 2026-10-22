import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'fairy_panel.dart';

/// 요정 탭 — 옛 캐릭터 탭의 요정 패널(2026-10-22 하단 탭 2쪽). 요정함 칸이 들어가야 해서 씬을 넣지 않는다.
class FairyTab extends StatelessWidget {
  const FairyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navFairy)),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: FairyPanel(),
        ),
      ),
    );
  }
}
