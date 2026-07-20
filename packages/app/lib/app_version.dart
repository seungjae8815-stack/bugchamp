/// 앱 빌드 식별자 — 폰에 설치한 빌드가 **어떤 업데이트인지** 설정 화면에서 눈으로 확인하기 위함.
///
/// 새 빌드를 폰에 설치할 때마다 아래를 갱신한다(그리고 `pubspec.yaml` 의 `version`
/// 빌드번호도 맞춘다). package_info_plus 미도입 — 의존성 최소화를 위해 손으로 관리.
library;

/// 시맨틱 버전 이름. (pubspec `version:` 의 앞부분과 일치시킨다.)
const String kAppVersionName = '1.0.0';

/// 이 빌드를 만든 날짜(YYYY-MM-DD). 설치본 구분 기준.
const String kBuildDate = '2026-07-20';

/// 이 빌드에 새로 들어간 것 — 설치 후 무엇을 확인하면 되는지 힌트.
const String kBuildHighlights = '스킨 실제 적용(황금·알비노·아레나 테마) · 상점(IAP)·패스 효과 · 전투 장소·상성 · 상성 휠';

/// 설정 화면에 표시할 짧은 라벨(날짜 없이 버전만). 예: "v1.0.0".
/// 날짜·기능 상세는 ⓘ 아이콘을 눌러 펼친다.
const String kBuildLabel = 'v$kAppVersionName';
