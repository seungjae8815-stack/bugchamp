/// 임시 진단 — Supabase 초기화 상태를 화면에 노출하기 위한 전역.
/// 로그인 문제 원인 확정 후 이 파일과 참조를 제거한다.
library;

/// Supabase 초기화/익명로그인 실패 시 예외 메시지(성공이면 빈 문자열).
String supabaseInitError = '';

/// 초기화 단계 추적(빈값=시작안함). 예: 'init', 'anon', 'ok'.
String supabaseInitStage = 'skip';
