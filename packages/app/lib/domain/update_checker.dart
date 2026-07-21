import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 앱 버전 점검 결과.
enum UpdateVerdict {
  /// 최신(또는 판단 불가) — 아무것도 안 함.
  none,

  /// 새 버전 권장 — 닫을 수 있는 안내.
  soft,

  /// 최소 지원 버전 미달 — 업데이트 전엔 못 넘어감(서버 규약이 깨질 때).
  hard,
}

const _serverUrl = String.fromEnvironment('GAME_SERVER_URL');
const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.bugchamp.app';

/// 서버의 `/version`(min·latest)과 내 versionCode 를 비교한다.
///
/// 서버 미설정·네트워크 실패 시 [UpdateVerdict.none] — **막지 않는다.**
/// 버전 체크가 앱 실행을 방해하면 안 되므로, 확실할 때만 안내한다.
Future<UpdateVerdict> checkAppVersion({http.Client? client}) async {
  if (_serverUrl.isEmpty) return UpdateVerdict.none;
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse('$_serverUrl/version'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return UpdateVerdict.none;
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    final min = (d['min'] as num?)?.toInt() ?? 0;
    final latest = (d['latest'] as num?)?.toInt() ?? 0;

    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    if (build <= 0) return UpdateVerdict.none;

    if (min > 0 && build < min) return UpdateVerdict.hard;
    if (latest > 0 && build < latest) return UpdateVerdict.soft;
    return UpdateVerdict.none;
  } catch (_) {
    return UpdateVerdict.none;
  } finally {
    if (client == null) c.close();
  }
}

/// 스토어 앱 페이지를 연다(외부 앱).
Future<void> openStore() async {
  await launchUrl(Uri.parse(_storeUrl), mode: LaunchMode.externalApplication);
}
