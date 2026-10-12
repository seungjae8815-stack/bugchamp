import 'dart:async';

import 'package:shelf/shelf.dart';

/// 서버 운영 감시(2026-09-15) — 이상 신호를 **세고 모았다가** 전용 봇으로 보낸다.
///
/// 두 종류로 나눈다. 폭주하면 사람이 알림을 끄게 되고, 그러면 진짜 장애를 놓친다.
///  - **즉시**: 서버 오류(5xx) 급증 · 요청 상한(1MB) 초과 · 상한 근처의 큰 세이브.
///    같은 알림은 쿨타임 동안 한 번만.
///  - **1시간 요약**: 업로드 상한에 잘린 계정(무엇이 잘렸나) · 위조 곤충 편성 거부 · 큰 세이브 ·
///    느린 응답. **아무 일도 없으면 보내지 않는다.**
///
/// ⚠️ 메모리에만 센다. Cloud Run 인스턴스가 여러 개면 인스턴스마다 따로 요약하고, 0 으로 내려가면
/// 모은 것이 사라진다 — 추세를 보는 용도이지 정확한 집계가 아니다. 서버가 통째로 죽는 경우는
/// 바깥의 `ops-watchdog`(Supabase)이 본다.
class OpsMonitor {
  OpsMonitor({
    required this.send,
    DateTime Function()? clock,
    this.errorBurst = 20,
    this.errorWindow = const Duration(minutes: 10),
    this.alertCooldown = const Duration(minutes: 30),
    this.summaryEvery = const Duration(hours: 1),
    this.bigSaveBytes = 300 * 1024,
    this.hugeSaveBytes = 700 * 1024,
    this.slowRequest = const Duration(seconds: 10),
  }) : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _windowStart = _clock();
    _summaryStart = _clock();
  }

  /// 텔레그램 발송(성공 여부). 실패해도 요청 처리에는 영향이 없어야 한다.
  final Future<bool> Function(String text) send;
  final DateTime Function() _clock;

  final int errorBurst;
  final Duration errorWindow;
  final Duration alertCooldown;
  final Duration summaryEvery;
  final int bigSaveBytes;
  final int hugeSaveBytes;
  final Duration slowRequest;

  // ── 즉시 알림 상태 ──
  late DateTime _windowStart;
  int _windowErrors = 0;
  final Map<String, int> _windowErrorPaths = {};
  final Map<String, DateTime> _lastAlert = {};

  // ── 1시간 요약 ──
  late DateTime _summaryStart;
  int _requests = 0;
  int _errors = 0;
  int _slow = 0;

  /// 5xx 를 **어떤 요청이 · 몇 번 · 무슨 이유로** 냈는지(`POST /x 503` → 횟수·마지막 이유).
  /// 요약에 "오류 1"만 오면 무엇인지 알 수 없었다(2026-10-12 사장님 요청).
  final Map<String, int> _errorCount = {};
  final Map<String, String> _errorReason = {};
  final Map<String, Set<String>> _clampsByUser = {};
  final Map<String, int> _clampCount = {};
  final Map<String, String> _forged = {};
  final Map<String, int> _bigSaves = {};

  /// 요청 하나가 끝났다(미들웨어가 부른다).
  void recordResponse(
    String path,
    int status,
    Duration took, {
    String method = '',
    String? reason,
  }) {
    _requests++;
    if (took >= slowRequest) _slow++;
    if (status >= 500) {
      _errors++;
      final key = '${method.isEmpty ? '' : '$method '}$path $status';
      _errorCount[key] = (_errorCount[key] ?? 0) + 1;
      if (reason != null && reason.isNotEmpty) _errorReason[key] = reason;
      final now = _clock();
      if (now.difference(_windowStart) > errorWindow) {
        _windowStart = now;
        _windowErrors = 0;
        _windowErrorPaths.clear();
      }
      _windowErrors++;
      _windowErrorPaths[path] = (_windowErrorPaths[path] ?? 0) + 1;
      if (_windowErrors >= errorBurst) {
        final top =
            (_windowErrorPaths.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3)
                .map((e) => '${_featureOf(e.key)}(${e.key}) ${e.value}번')
                .join(' · ');
        final why = reason == null
            ? ''
            : '\n마지막 오류: ${_whatHappened(500, reason)}\n원문: ${_short(reason)}';
        _alertOnce(
          'error_burst',
          '🚨 서버 오류 급증\n'
              '${errorWindow.inMinutes}분 동안 5xx $_windowErrors건\n'
              '$top$why\n'
              '확인: gcloud run services logs read bugchamp-server --region asia-northeast3 --limit 50',
        );
      }
    }
    _maybeSummary();
  }

  /// 업로드가 상한에 잘렸다 — [reasons] 는 `mergeSave` 의 `clampReasons`.
  void recordClamp(String uid, List<String> reasons) {
    if (reasons.isEmpty) return;
    (_clampsByUser[uid] ??= <String>{}).addAll(reasons);
    _clampCount[uid] = (_clampCount[uid] ?? 0) + 1;
  }

  /// 위조 곤충으로 편성하려다 거부됐다.
  void recordForged(String uid, String detail) {
    _forged[uid] = detail;
  }

  /// 세이브 업로드 크기(바이트). 큰 것만 남기고, 상한 근처면 즉시 알린다.
  void recordSaveSize(String uid, int bytes) {
    if (bytes < bigSaveBytes) return;
    final prev = _bigSaves[uid] ?? 0;
    if (bytes > prev) _bigSaves[uid] = bytes;
    if (bytes >= hugeSaveBytes) {
      _alertOnce(
        'huge_save:$uid',
        '⚠️ 세이브가 너무 큼 · ${_kb(bytes)}\n'
            '요청 상한 1MB 에 가깝다 — 곧 저장이 거부된다\n'
            'uid $uid',
      );
    }
  }

  /// 요청 본문 상한(1MB)을 넘어 거절했다.
  void recordTooLarge(String path, int bytes) {
    _alertOnce(
      'too_large:$path',
      '⚠️ 요청 크기 초과로 거절 · $path · ${_kb(bytes)}\n'
          '세이브 비대화 가능성(2026-07 장애와 같은 경로)',
    );
  }

  void _alertOnce(String key, String text) {
    final now = _clock();
    final last = _lastAlert[key];
    if (last != null && now.difference(last) < alertCooldown) return;
    _lastAlert[key] = now;
    // 발송은 기다리지 않는다 — 요청 응답을 늦추지 않게.
    send(text);
  }

  void _maybeSummary() {
    final now = _clock();
    if (now.difference(_summaryStart) < summaryEvery) return;
    final text = summaryText(now);
    _summaryStart = now;
    _requests = 0;
    _errors = 0;
    _slow = 0;
    _errorCount.clear();
    _errorReason.clear();
    _clampsByUser.clear();
    _clampCount.clear();
    _forged.clear();
    _bigSaves.clear();
    if (text != null) send(text);
  }

  /// 지금까지 모은 요약. 알릴 것이 없으면 null(테스트에서도 쓴다).
  String? summaryText(DateTime now) {
    final notable =
        _errors > 0 ||
        _clampsByUser.isNotEmpty ||
        _forged.isNotEmpty ||
        _bigSaves.isNotEmpty ||
        _slow > 0;
    if (!notable) return null;
    String kst(DateTime t) {
      final k = t.toUtc().add(const Duration(hours: 9));
      return '${k.hour.toString().padLeft(2, '0')}:${k.minute.toString().padLeft(2, '0')}';
    }

    final b = StringBuffer()
      ..writeln('📊 서버 요약 ${kst(_summaryStart)}~${kst(now)} (KST)')
      ..writeln('요청 $_requests · 오류(5xx) $_errors · 느린 응답 $_slow');
    if (_errorCount.isNotEmpty) {
      final errs = _errorCount.entries.toList()
        ..sort((a, c) => c.value.compareTo(a.value));
      b.writeln('❌ 오류 ${_errors}건');
      for (final e in errs.take(6)) {
        b.writeln(explainError(e.key, e.value, _errorReason[e.key]));
      }
    }
    if (_clampsByUser.isNotEmpty) {
      final users = _clampsByUser.entries.toList()
        ..sort(
          (a, c) =>
              (_clampCount[c.key] ?? 0).compareTo(_clampCount[a.key] ?? 0),
        );
      b.writeln('🧮 상한에 잘린 업로드 · 계정 ${users.length}');
      for (final e in users.take(8)) {
        b.writeln(
          '  ${e.key.substring(0, e.key.length < 8 ? e.key.length : 8)} '
          '${e.value.map(_reasonLabel).toSet().join('·')} ×${_clampCount[e.key]}',
        );
      }
    }
    if (_forged.isNotEmpty) {
      b.writeln('🪲 위조 곤충 편성 거부 · 계정 ${_forged.length}');
      for (final e in _forged.entries.take(8)) {
        b.writeln('  ${e.key} ${e.value}');
      }
    }
    if (_bigSaves.isNotEmpty) {
      final top = _bigSaves.entries.toList()
        ..sort((a, c) => c.value.compareTo(a.value));
      b.writeln('💾 큰 세이브(${_kb(bigSaveBytes)}+) · 계정 ${top.length}');
      for (final e in top.take(5)) {
        b.writeln('  ${e.key} ${_kb(e.value)}');
      }
    }
    return b.toString().trimRight();
  }

  /// 오류 하나를 **사장님이 읽을 수 있는 말**로(2026-10-12 사장님 요청 — `POST /admin/user 503` 과
  /// 원문 예외만으로는 무엇인지 알 수 없었다). [key] = `방식 경로 상태`.
  ///
  /// ```
  /// • 운영 패널 · 유저 조회 — 1번
  ///   무슨 일: 계정 ID 칸에 닉네임 같은 다른 값이 들어가 DB가 거절했어요
  ///   유저 영향: 없음(운영 패널 — 사장님만 씀)
  ///   (POST /admin/user · 503 · 원문: …)
  /// ```
  static String explainError(String key, int count, String? reason) {
    final parts = key.split(' ');
    final status = int.tryParse(parts.last) ?? 500;
    final path = parts.length >= 2 ? parts[parts.length - 2] : key;
    final feature = _featureOf(path);
    final what = _whatHappened(status, reason);
    final impact = _impactOf(path, status);
    final raw = reason == null ? '' : ' · 원문: ${_short(reason)}';
    return '• $feature — $count번\n'
        '  무슨 일: $what\n'
        '  유저 영향: $impact\n'
        '  ($key$raw)';
  }

  /// 경로 → 기능 이름.
  static String _featureOf(String path) {
    const names = <String, String>{
      '/admin/user': '운영 패널 · 유저 조회',
      '/admin/grant': '운영 패널 · 상품 지급',
      '/admin/mail': '운영 패널 · 우편 보내기',
      '/admin': '운영 패널',
      '/save': '세이브 자동 저장(60초마다)',
      '/sync': '방치 보상 정산',
      '/state': '세이브 불러오기',
      '/session': '기기 접속 확인',
      '/duel': '결투',
      '/battle': '옛 결투(구버전 앱)',
      '/pvp/profile': '상대 프로필 보기',
      '/pvp': '결투 순위·상대 찾기',
      '/event': '왕충 선발대회',
      '/purchase': '결제 지급',
      '/mail': '우편함',
      '/notices': '공지',
      '/support': '문의하기',
      '/code': '쿠폰 코드',
      '/abyss': '심연',
      '/guild': '길드',
      '/fairy': '요정',
      '/telegram': '텔레그램 봇',
      '/version': '앱 버전 확인',
    };
    for (final e in names.entries) {
      if (path == e.key || path.startsWith('${e.key}/')) return e.value;
    }
    return '기타 기능';
  }

  /// 상태·원문 → 무슨 일이 있었나.
  static String _whatHappened(int status, String? reason) {
    final r = (reason ?? '').toLowerCase();
    if (r.contains('invalid input syntax for type uuid')) {
      return '계정 ID 칸에 닉네임 같은 다른 값이 들어가 DB가 거절했어요';
    }
    if (r.contains('timeout') || r.contains('timed out')) {
      return 'DB(저장소) 응답이 너무 늦어 포기했어요 — 잠깐 몰리면 생겨요';
    }
    if (r.contains('socketexception') ||
        r.contains('connection') ||
        r.contains('clientexception')) {
      return 'DB(저장소)와 연결이 잠깐 끊겼어요 — 대개 일시적이에요';
    }
    if (r.contains('statestoreexception') || r.contains('postgrest')) {
      return 'DB(저장소)에 읽기·쓰기를 요청했는데 실패했어요';
    }
    if (r.contains('null check') ||
        r.contains('typeerror') ||
        r.contains('rangeerror') ||
        r.contains('formatexception') ||
        r.contains('nosuchmethod')) {
      return '서버 코드가 예상 못 한 값을 만나 멈췄어요 — 버그일 가능성이 커요';
    }
    return switch (status) {
      503 => 'DB(저장소)나 외부 서비스에 닿지 못했어요',
      502 || 504 => '서버가 제때 응답하지 못했어요(시간 초과)',
      _ => '서버 안에서 처리하다 실패했어요 — 원문을 보고 확인이 필요해요',
    };
  }

  /// 유저에게 영향이 있었나.
  static String _impactOf(String path, int status) {
    if (path.startsWith('/admin') || path.startsWith('/telegram')) {
      return '없음(운영 도구 — 사장님만 씀)';
    }
    if (path == '/save') {
      return '거의 없음(60초 뒤 다시 올린다) · 계속 반복되면 그 유저 저장이 막힌 것';
    }
    if (path.startsWith('/purchase')) {
      return '있음 — 결제 지급이 늦어졌을 수 있어요(앱이 다시 시도) · 반복되면 확인 필요';
    }
    if (path.startsWith('/duel') || path.startsWith('/event')) {
      return '있음 — 그 판이 오류로 끝났을 수 있어요(티켓·참가권은 확인 필요)';
    }
    return '있음 — 그 기능을 누른 유저에게 오류가 보였어요(다시 누르면 대개 됨)';
  }

  /// 이유 한 줄 — 텔레그램이 길게 늘어지지 않게 자른다.
  static String _short(String s) {
    final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= 180 ? one : '${one.substring(0, 180)}…';
  }

  static String _kb(int bytes) => '${(bytes / 1024).round()}KB';

  static String _reasonLabel(String r) => switch (r) {
    'gold' => '골드',
    'jelly' => '젤리',
    'fossil' => '화석',
    'skill' => '스킬조각',
    'storage' => '채집함·스테이지',
    _ when r.startsWith('material') => '재료',
    _ => r,
  };
}

/// 모든 요청의 상태 코드·걸린 시간을 [OpsMonitor] 에 넘긴다.
///
/// 5xx 이면 **그 요청을 처리하며 서버가 남긴 마지막 로그 한 줄**(예: `[admin/user] StateStoreException…`)을
/// 이유로 함께 넘긴다 — 핸들러마다 고치지 않고 Zone 의 print 를 엿듣는다(출력은 그대로 나간다).
Middleware opsMiddleware(OpsMonitor monitor) => (Handler inner) {
  return (Request req) async {
    final sw = Stopwatch()..start();
    final path = '/${req.url.path}';
    String? lastLine;
    try {
      final res = await runZoned(
        () => Future.sync(() => inner(req)),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            lastLine = line;
            parent.print(zone, line);
          },
        ),
      );
      monitor.recordResponse(
        path,
        res.statusCode,
        sw.elapsed,
        method: req.method,
        reason: res.statusCode >= 500 ? lastLine : null,
      );
      if (res.statusCode == 413) {
        monitor.recordTooLarge(path, req.contentLength ?? 0);
      }
      return res;
    } catch (e) {
      // 처리되지 않은 예외는 shelf 가 500 으로 바꾼다 — 여기서 세고 다시 던진다.
      monitor.recordResponse(
        path,
        500,
        sw.elapsed,
        method: req.method,
        reason: '${e.runtimeType}: $e',
      );
      rethrow;
    }
  };
};
