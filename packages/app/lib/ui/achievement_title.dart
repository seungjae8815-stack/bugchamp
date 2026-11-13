import 'package:core_run/core_run.dart';

/// 업적 id → 칭호 이름(지금 언어). 모르는 id(새 버전 업적)·없음이면 null — 그리지 않는다.
String? achievementTitleName(RunConfig? run, String? id, String lang) {
  if (run == null || id == null) return null;
  for (final d in run.achievements) {
    if (d.id == id) return d.title[lang] ?? d.title['en'] ?? d.title['ko'];
  }
  return null;
}
