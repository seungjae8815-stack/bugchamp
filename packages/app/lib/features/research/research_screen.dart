import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 연구소 탭 — 자리만 잡아 둔다(화면은 연구소 작업에서 채운다).
class ResearchScreen extends StatelessWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navResearch)),
      body: const SizedBox.shrink(),
    );
  }
}
