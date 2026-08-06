/// 앱 빌드 식별자 — 폰에 설치한 빌드가 **어떤 업데이트인지** 설정 화면에서 눈으로 확인하기 위함.
///
/// ⚠️ 버전·빌드번호는 **손으로 적지 않는다.** 예전엔 여기 const 로 박아두고
/// 릴리스마다 갱신했는데, 빠뜨리기 쉬워 실제 설치본과 어긋났다(설정 화면이
/// 1.0.2/20260738 로 굳어 있는데 설치본은 1.0.3+20260740 이었다).
/// 이제 `pubspec.yaml` 의 `version:` 을 PackageInfo 로 그대로 읽는다 —
/// 한 곳만 고치면 되고 어긋날 수가 없다.
///
/// 표시 전용이다. 버전 게이트 판정은 `update_checker.dart` 가 따로 한다.
library;

import 'package:package_info_plus/package_info_plus.dart';

/// 시맨틱 버전 이름(pubspec `version:` 앞부분). [loadAppVersion] 전엔 '-'.
String kAppVersionName = '-';

/// 빌드번호(pubspec `version:` 의 `+` 뒤). [loadAppVersion] 전엔 '-'.
String kBuildNumber = '-';

/// 설정 화면에 표시할 라벨. 예: "v1.0.3 (20260740)".
/// 빌드번호까지 보여야 "지금 폰에 깔린 게 어느 빌드냐"에 바로 답할 수 있다.
String get kBuildLabel => 'v$kAppVersionName ($kBuildNumber)';

/// 앱 시작 시 1회 호출. 실패해도 표시만 '-' 로 남고 게임 진행에는 영향이 없다.
Future<void> loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    kAppVersionName = info.version;
    kBuildNumber = info.buildNumber;
  } catch (_) {
    // 표시 전용이라 조용히 넘어간다.
  }
}

// ── 아래 둘은 릴리스마다 손으로 갱신한다(코드로는 알 수 없는 편집 정보) ──────

/// 이 빌드를 만든 날짜(YYYY-MM-DD).
const String kBuildDate = '2026-08-04';

/// 이 빌드에 새로 들어간 것 — 설치 후 무엇을 확인하면 되는지 힌트.
const String kBuildHighlights = '사운드 24종 · 로드맵 보스 칸 · 랭킹 팝업 · 채집함 상한';
