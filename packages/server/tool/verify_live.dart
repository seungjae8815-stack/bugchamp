// 배포된 실서버를 **진짜 Supabase 익명 토큰**으로 끝까지 돌려 보는 검증 툴.
//
// 로컬 테스트(가짜 http)가 못 잡는 것을 잡는다:
//   - 실 JWT 를 서버가 JWKS 로 검증하는가
//   - 실 DB 에 세이브·세션이 읽고 쓰이는가(RLS 우회는 service_role 로)
//   - 야생/수동 전투가 프로덕션 config(species.json 실적재)로 도는가
//
// 실행:  dart run tool/verify_live.dart
// 자격증명은 packages/app/supabase.env.json 에서 읽고 **출력하지 않는다**.

import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart' show UpgradeKind;
import 'package:core_save/core_save.dart';
import 'package:http/http.dart' as http;

const _serverUrl =
    'https://bugchamp-server-867649520275.asia-northeast3.run.app';

int _pass = 0, _fail = 0;

void check(String label, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
    print('  OK  $label');
  } else {
    _fail++;
    print('  XX  $label${detail.isEmpty ? '' : '  -- $detail'}');
  }
}

Future<void> main() async {
  final env =
      jsonDecode(File('../app/supabase.env.json').readAsStringSync())
          as Map<String, dynamic>;
  final supaUrl = env['SUPABASE_URL'].toString();
  final anonKey = env['SUPABASE_ANON_KEY'].toString();

  final c = http.Client();

  // 성충 3마리를 편성한 검증용 세이브(전투마다 이걸로 새 유저를 만든다).
  final now = DateTime.now().toUtc();
  final long = now.subtract(const Duration(days: 30));
  IndividualBug adult(String id, String sp, Element el) => IndividualBug(
    id: id,
    speciesId: sp,
    sizeMm: 45,
    potential: 3,
    temperament: Temperament.aggressive,
    sex: Sex.male,
    element: el,
    stage: LifeStage.adult,
    stageSince: long,
  );
  final save = SaveGame.initial(createdAt: now).copyWith(
    bugs: [
      adult('v-1', 'stag_dorcus', Element.wood),
      adult('v-2', 'stag_saw', Element.fire),
      adult('v-3', 'rhino_lesser', Element.earth),
    ],
    equippedBugIds: ['v-1', 'v-2', 'v-3'],
    gold: 5000,
  );

  /// 새 익명 유저 로그인 → 인증 헤더(없으면 null).
  Future<Map<String, String>?> signIn() async {
    final r = await c.post(
      Uri.parse('$supaUrl/auth/v1/signup'),
      headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'data': {}, 'gotrue_meta_security': {}}),
    );
    if (r.statusCode >= 300) return null;
    final tk = (jsonDecode(r.body) as Map)['access_token']?.toString();
    if (tk == null) return null;
    return {'Authorization': 'Bearer $tk', 'Content-Type': 'application/json'};
  }

  Future<http.Response> get(String p, Map<String, String> h) =>
      c.get(Uri.parse('$_serverUrl$p'), headers: h);
  Future<http.Response> post(String p, Object body, Map<String, String> h) =>
      c.post(Uri.parse('$_serverUrl$p'), headers: h, body: jsonEncode(body));

  /// 새 유저 + 성충 3마리 부트스트랩 → 인증 헤더.
  Future<Map<String, String>?> freshUserWithBugs() async {
    final h = await signIn();
    if (h == null) return null;
    final boot = await post('/state', {'save': save.toJson()}, h);
    return (boot.statusCode == 200 || boot.statusCode == 201) ? h : null;
  }

  // ── 1. 익명 로그인 ───────────────────────────────────────────
  print('\n[1] Supabase 익명 로그인');
  final auth = await signIn();
  check('토큰 발급 + 인증 헤더 구성', auth != null);
  if (auth == null) {
    print('     (프로젝트에서 Anonymous sign-ins 이 꺼져 있을 수 있음)');
    exit(1);
  }

  // ── 2. JWT 검증 ──────────────────────────────────────────────
  print('\n[2] JWT 검증 (서버가 JWKS 공개키로)');
  final health = await http.get(Uri.parse('$_serverUrl/health'));
  check('/health 200', health.statusCode == 200);
  final noAuth = await http.post(
    Uri.parse('$_serverUrl/sync'),
    headers: {'Content-Type': 'application/json'},
    body: '{}',
  );
  check('토큰 없으면 401', noAuth.statusCode == 401);
  final badAuth = await http.post(
    Uri.parse('$_serverUrl/sync'),
    headers: {
      'Authorization': 'Bearer garbage',
      'Content-Type': 'application/json',
    },
    body: '{}',
  );
  check(
    '가짜 토큰 거부 (401)',
    badAuth.statusCode == 401,
    'got ${badAuth.statusCode}',
  );

  // ── 3. 부트스트랩 (실 DB 쓰기) ───────────────────────────────
  print('\n[3] 세이브 부트스트랩 (실 DB 쓰기)');
  final boot = await post('/state', {'save': save.toJson()}, auth);
  check(
    '부트스트랩 성공',
    boot.statusCode == 200 || boot.statusCode == 201,
    'HTTP ${boot.statusCode} ${boot.body}',
  );
  final boot2 = await post('/state', {'save': save.toJson()}, auth);
  check(
    '중복 부트스트랩 거부 (409)',
    boot2.statusCode == 409,
    'got ${boot2.statusCode}',
  );
  final state = await get('/state', auth);
  check('세이브 조회 200', state.statusCode == 200);
  final loaded = (jsonDecode(state.body) as Map)['save'] as Map?;
  check(
    '업로드한 곤충이 서버에 있다',
    loaded != null && (loaded['bugs'] as List).length >= 3,
  );

  // ── 4. 야생 자동 전투 ────────────────────────────────────────
  print('\n[4] 야생 자동 전투 (서버가 상대 생성·승패 확정)');
  final wild = await post('/battle', {
    'teamBugIds': ['v-1', 'v-2', 'v-3'],
    'tierId': 'even',
  }, auth);
  check(
    '야생 전투 200',
    wild.statusCode == 200,
    'HTTP ${wild.statusCode} ${wild.body}',
  );
  if (wild.statusCode == 200) {
    final b = jsonDecode(wild.body) as Map<String, dynamic>;
    check('승패(outcome) 확정', b['outcome'] != null);
    check('시드를 재생용으로 준다', b['seed'] != null);
    final foe = b['foe'] as List?;
    check('서버가 싸운 상대를 돌려준다 (3마리)', foe != null && foe.length == 3);
    check(
      '상대에 종 id 포함(스프라이트용)',
      foe != null && foe.every((f) => (f['sp']?.toString() ?? '').isNotEmpty),
    );
    check('갱신된 세이브 포함', b['save'] != null);
  }

  // ── 5. 조작 시도 차단 ────────────────────────────────────────
  print('\n[5] 조작 시도 차단');
  final badTier = await post('/battle', {
    'teamBugIds': ['v-1', 'v-2', 'v-3'],
    'tierId': 'i-made-this-up',
  }, auth);
  check(
    '없는 티어 거부 (400)',
    badTier.statusCode == 400,
    'got ${badTier.statusCode}',
  );
  final notMine = await post('/battle', {
    'teamBugIds': ['not-my-bug', 'v-2', 'v-3'],
    'tierId': 'even',
  }, auth);
  check(
    '내 곤충이 아니면 거부 (400)',
    notMine.statusCode == 400,
    'got ${notMine.statusCode}',
  );

  // ── 6. 야생 수동 전투 — 부상 없는 새 유저로 ──────────────────
  // (앞의 자동 전투에서 KO 된 곤충은 회복 타이머로 편성 불가 — 정상 동작.
  //  실제로 [4] 뒤에 같은 팀으로 시작하면 서버가 bug_injured 로 거부한다.)
  print('\n[6] 야생 수동 전투 (세션·시드 은닉)');
  final mAuth = await freshUserWithBugs();
  check('수동 검증용 새 유저 준비', mAuth != null);
  if (mAuth != null) {
    final start = await post('/battle/manual/start', {
      'teamBugIds': ['v-1', 'v-2', 'v-3'],
      'tierId': 'even',
    }, mAuth);
    check(
      '수동 전투 시작 200',
      start.statusCode == 200,
      'HTTP ${start.statusCode} ${start.body}',
    );
    if (start.statusCode == 200) {
      final b = jsonDecode(start.body) as Map<String, dynamic>;
      final sid = b['sessionId']?.toString();
      check('세션 id 발급', sid != null);
      check('시드를 주지 않는다', !start.body.contains('seed'));
      check('상대 3마리 + 종 id', (b['foe'] as List?)?.length == 3);

      if (sid != null) {
        Map<String, dynamic>? last;
        var steps = 0;
        for (var i = 0; i < 70; i++) {
          final step = await post('/battle/manual/step', {
            'sessionId': sid,
            'stance': 'attack',
          }, mAuth);
          if (step.statusCode != 200) {
            check(
              '스텝 200 (${i + 1}번째)',
              false,
              'HTTP ${step.statusCode} ${step.body}',
            );
            break;
          }
          steps++;
          last = jsonDecode(step.body) as Map<String, dynamic>;
          if (last['done'] == true) break;
        }
        check('여러 수 진행됨', steps > 0);
        check('결착에 도달', last?['done'] == true);
        check('결착 시 보상 확정', last?['gold'] != null && last?['outcome'] != null);
        check(
          '스텝 응답에도 시드 없음',
          last != null && !jsonEncode(last).contains('seed'),
        );

        final again = await post('/battle/manual/step', {
          'sessionId': sid,
          'stance': 'attack',
        }, mAuth);
        check(
          '끝난 세션 재진행 거부 (409)',
          again.statusCode == 409,
          'got ${again.statusCode}',
        );
      }
    }
  }

  // ── 7. 돌파 (레벨 상한 확장 — 스탯 직결) ─────────────────────
  print('\n[7] 돌파 (재화 소비 + 티어 상승)');
  // 이미 레벨 상한(10)을 채우고 재화를 가진 유저를 부트스트랩한다
  // (기존 플레이어가 수련을 끝낸 상황과 같다).
  final bAuth = await signIn();
  check('돌파 검증용 새 유저 준비', bAuth != null);
  if (bAuth != null) {
    final ready = SaveGame.initial(createdAt: now).copyWith(
      bugs: [adult('bt-1', 'stag_dorcus', Element.wood).copyWith(level: 10)],
      gold: 50000,
      materials: {
        MaterialKind.chitin: 200,
        MaterialKind.mineral: 200,
        MaterialKind.sap: 200,
        MaterialKind.jelly: 999,
      },
    );
    final boot = await post('/state', {'save': ready.toJson()}, bAuth);
    check(
      '돌파 준비 세이브 부트스트랩',
      boot.statusCode == 200 || boot.statusCode == 201,
      'HTTP ${boot.statusCode} ${boot.body}',
    );

    final start = await post('/breakthrough', {'bugId': 'bt-1'}, bAuth);
    check(
      '돌파 시작 200',
      start.statusCode == 200,
      'HTTP ${start.statusCode} ${start.body}',
    );
    if (start.statusCode == 200) {
      final b = jsonDecode(start.body) as Map<String, dynamic>;
      final saved = b['save'] as Map<String, dynamic>;
      // 재화가 실제로 빠졌는가.
      check('돌파 시작 시 골드 차감', (saved['gold'] as num) < 50000);
      final bug = (saved['bugs'] as List).first as Map<String, dynamic>;
      check('돌파 타이머가 걸린다', bug['breakthroughEndsAt'] != null);

      // 젤리로 즉시완료 → 티어 상승.
      final done = await post('/breakthrough/complete', {
        'bugId': 'bt-1',
        'viaJelly': true,
      }, bAuth);
      check(
        '젤리 즉시완료 200',
        done.statusCode == 200,
        'HTTP ${done.statusCode} ${done.body}',
      );
      if (done.statusCode == 200) {
        final d = jsonDecode(done.body) as Map<String, dynamic>;
        final bug2 =
            ((d['save'] as Map)['bugs'] as List).first as Map<String, dynamic>;
        check('티어가 1 올랐다', (bug2['breakthroughTier'] as num) == 1);
        check('돌파 타이머가 해제됐다', bug2['breakthroughEndsAt'] == null);
      }
    }

    // 완료 전 무료 수령 조작 차단(다시 시작 후 타이머 남은 상태로 확인).
    final start2 = await post('/breakthrough', {'bugId': 'bt-1'}, bAuth);
    if (start2.statusCode == 200) {
      final free = await post('/breakthrough/complete', {
        'bugId': 'bt-1',
      }, bAuth);
      check(
        '타이머 안 끝났는데 무료 수령하면 거부(400)',
        free.statusCode == 400,
        'got ${free.statusCode}',
      );
    }
  }

  // ── 8. 방치 진행: sync 가 스테이지를 올린다 ──────────────────
  print('\n[8] 방치 진행 (sync 가 스테이지·미션·선물 확정)');
  final iAuth = await signIn();
  if (iAuth != null) {
    // 강한 캐릭터(스테이지를 밀 수 있게) + 오래 비운 세이브를 부트스트랩.
    final long = now.subtract(const Duration(hours: 3));
    final idleSave = SaveGame.initial(createdAt: long).copyWith(
      lastSeen: long,
      stageNumber: 1,
      level: 20,
      upgradeLevels: {UpgradeKind.attack: 80, UpgradeKind.attackSpeed: 30},
      nextGiftAt: long, // 선물 예정 시각을 과거로 → 스폰돼야 함
    );
    final boot = await post('/state', {'save': idleSave.toJson()}, iAuth);
    check(
      '방치 검증용 세이브 부트스트랩',
      boot.statusCode == 200 || boot.statusCode == 201,
      'HTTP ${boot.statusCode} ${boot.body}',
    );

    final sync = await post('/sync', const {}, iAuth);
    check(
      'sync 200',
      sync.statusCode == 200,
      'HTTP ${sync.statusCode} ${sync.body}',
    );
    if (sync.statusCode == 200) {
      final b = jsonDecode(sync.body) as Map<String, dynamic>;
      check('sync 가 스테이지를 올렸다', (b['newStage'] as num) > 1);
      check('방치 골드가 들어왔다', (b['gold'] as num) > 0);
      final saved = b['save'] as Map<String, dynamic>;
      check(
        '세이브에 오른 스테이지가 반영됐다',
        (saved['stageNumber'] as num) == b['newStage'],
      );
      check('선물이 스폰됐다', (saved['gifts'] as List).isNotEmpty);
    }
  }

  // ── 9. 보상 수령 (미션·일일·선물·챕터) ───────────────────────
  print('\n[9] 보상 수령 (서버가 지급 확정)');
  final rAuth = await signIn();
  if (rAuth != null) {
    // 일일보상은 시간 게이트가 UI 라 서버는 UTC 날짜 중복만 본다 → 바로 수령 가능.
    final base = SaveGame.initial(createdAt: now);
    await post('/state', {'save': base.toJson()}, rAuth);

    final daily = await post('/daily/claim', {'rewardId': 'lunch'}, rAuth);
    check(
      '일일보상(lunch) 수령 200',
      daily.statusCode == 200,
      'HTTP ${daily.statusCode} ${daily.body}',
    );
    if (daily.statusCode == 200) {
      final b = jsonDecode(daily.body) as Map<String, dynamic>;
      check('일일보상 골드 지급', (b['save']['gold'] as num) > 0);
    }
    final dup = await post('/daily/claim', {'rewardId': 'lunch'}, rAuth);
    check('같은 날 재수령 거부 (400)', dup.statusCode == 400, 'got ${dup.statusCode}');

    // 미션: 목표 미달이면 거부(진행도를 서버가 소유).
    final miss = await post('/mission/claim', {'missionId': 'hunt'}, rAuth);
    check(
      '목표 미달 미션 거부 (400)',
      miss.statusCode == 400,
      'got ${miss.statusCode}',
    );

    // 선물: 없으면 거부.
    final gift = await post('/gift/claim', {'giftId': 'nope'}, rAuth);
    check('없는 선물 거부 (400)', gift.statusCode == 400, 'got ${gift.statusCode}');

    // 챕터: 스테이지 미달이면 빈 목록(200).
    final road = await post('/roadmap/claim', const {}, rAuth);
    check(
      '챕터 수령 200(미달이면 빈 목록)',
      road.statusCode == 200,
      'HTTP ${road.statusCode}',
    );
  }

  print('\n${'-' * 40}');
  print('통과 $_pass / 실패 $_fail');
  c.close();
  exit(_fail == 0 ? 0 : 1);
}
