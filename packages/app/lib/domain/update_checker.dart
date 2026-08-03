import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 앱 버전 점검 결과.
enum UpdateVerdict {
  /// 최신 — 아무것도 안 함.
  none,

  /// 새 버전 권장 — 닫을 수 있는 안내.
  soft,

  /// 최소 지원 버전 미달 — 업데이트 전엔 못 넘어감(서버 규약이 깨질 때).
  hard,

  /// 서버 점검 중 — 입장 차단(재시도 가능). Cloud Run 의 `MAINTENANCE=1` 로 켠다.
  maintenance,

  /// 서버에 닿지 못함(네트워크 없음·서버 다운) — 입장 차단 + 재시도.
  ///
  /// 통과시키면 안 되는 이유: 비행기 모드로 버전·점검 게이트를 우회해
  /// 구버전/치팅 세이브를 계속 굴릴 수 있고, 채팅·PvP 가 빠진 반쪽 게임이
  /// 아무 안내 없이 돌아간다. 온라인 게임임을 시작 시점에 확정한다.
  offline,
}

const _serverUrl = String.fromEnvironment('GAME_SERVER_URL');
const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.bugchamp.app';

/// 서버의 `/version`(min·latest·maintenance)과 내 versionCode 를 비교한다.
///
/// **시작 시 온라인 필수**(2026-08 전환): 서버에 닿지 못하면 [UpdateVerdict.offline]
/// 로 입장을 막는다. 예전엔 실패 시 통과시켰는데, 그러면 비행기 모드로 버전·점검
/// 게이트를 우회할 수 있었다. 서버 미설정(개발 실행)일 때만 검사 없이 통과.
Future<UpdateVerdict> checkAppVersion({http.Client? client}) async {
  if (_serverUrl.isEmpty) return UpdateVerdict.none; // 개발 실행 — 서버 없음
  final c = client ?? http.Client();
  try {
    // 타임아웃 8초: Cloud Run 콜드스타트(스케일 0→1)를 감안한 여유.
    final res = await c
        .get(Uri.parse('$_serverUrl/version'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return UpdateVerdict.offline;
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    if (d['maintenance'] == true) return UpdateVerdict.maintenance;
    final min = (d['min'] as num?)?.toInt() ?? 0;
    final latest = (d['latest'] as num?)?.toInt() ?? 0;

    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    if (build <= 0) return UpdateVerdict.none;

    if (min > 0 && build < min) return UpdateVerdict.hard;
    if (latest > 0 && build < latest) return UpdateVerdict.soft;
    return UpdateVerdict.none;
  } catch (_) {
    return UpdateVerdict.offline;
  } finally {
    if (client == null) c.close();
  }
}

/// 스토어 앱 페이지를 연다(외부 앱).
Future<void> openStore() async {
  await launchUrl(Uri.parse(_storeUrl), mode: LaunchMode.externalApplication);
}
