import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';
import 'skill_panel.dart';

/// 스킬 탭 — 옛 캐릭터 탭의 스킬 패널(2026-10-22 하단 탭 2쪽).
///
/// 채집 씬은 넣지 않는다 — 재료·장착 칸·12종 목록이 다 들어가야 해서 씬이 100px 을 먹으면
/// 목록이 두 줄만 보인다(실기 지적 2026-09-16).
class SkillTab extends ConsumerWidget {
  const SkillTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final save = ref.watch(saveControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: Text(l.navSkills)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: SkillPanel(save: save),
        ),
      ),
    );
  }
}
