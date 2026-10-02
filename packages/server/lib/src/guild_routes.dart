import 'dart:convert';
import 'dart:io' show stderr;

import 'package:core_models/core_models.dart' show FairyGrade, MaterialKind;
import 'package:core_run/core_run.dart'
    show FairyConfig, GuildShopItem, RunConfig, materialAmountMult;
import 'package:core_save/core_save.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'guild_actions.dart';
import 'guild_boss_actions.dart';
import 'guild_mission_actions.dart';
import 'guild_war_actions.dart';
import 'state_store.dart' show StateStoreException;

/// `/guild/*` 라우트(docs/design_guild.md §7.2). 로직은 [GuildActions], 여기는 요청 해석만.
///
/// ⚠️ 앱은 **길드 화면이 열려 있을 때와 시작할 때만** 부른다 — 화면 밖 폴링은 Cloud Run 요금에 선형이다.
void mountGuildRoutes(
  Router authed, {
  required GuildActions guild,
  required String Function(Request) userIdOf,
  required Future<SaveGame?> Function(String userId) loadSave,

  /// 서버 세이브에서 젤리를 뺀 결과(부족하면 null) — `GameActions.spendJelly`.
  required SaveGame? Function(SaveGame save, int amount) spendJelly,
  required Future<void> Function(String userId, SaveGame save) storeSave,
  required GuildMissionActions missions,
  required GuildBossActions boss,
  required GuildWarActions war,
  required RunConfig run,
  FairyConfig? fairy,
}) {
  Response json(int status, Map<String, dynamic> body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );

  /// 본문을 읽고 [run] 을 돌린다. 저장소 오류는 503 으로 감싼다.
  Handler post(
    String tag,
    Future<GuildResult> Function(String uid, Map<String, dynamic> body) run,
  ) => (Request req) async {
    final uid = userIdOf(req);
    final Map<String, dynamic> body;
    try {
      final raw = await req.readAsString();
      body = raw.isEmpty ? const {} : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return json(400, {'error': 'bad_request'});
    }
    try {
      final (status, out) = await run(uid, body);
      return json(status, out);
    } on StateStoreException catch (e) {
      stderr.writeln('[guild/$tag] $uid: $e');
      return json(503, {'error': 'store_unavailable'});
    }
  };

  String s(Map<String, dynamic> b, String k) => b[k]?.toString() ?? '';
  double pw(Map<String, dynamic> b) => (b['power'] as num?)?.toDouble() ?? 0;

  /// 상점 품목을 서버 세이브에 넣는다. 재료는 **자기 사냥터 몇 시간치**(정액이면 후반엔 껌값).
  (SaveGame, Map<String, dynamic>) grantItem(SaveGame save, GuildShopItem it) {
    switch (it.kind) {
      case 'materials':
        final each =
            (materialAmountMult(run, save.stageNumber) *
                    run.exchangeKillsPerHour *
                    it.hours /
                    3)
                .round();
        final mats = Map<MaterialKind, int>.from(save.materials);
        for (final k in [
          MaterialKind.chitin,
          MaterialKind.mineral,
          MaterialKind.sap,
        ]) {
          mats[k] = save.materialCount(k) + each;
        }
        return (
          save.copyWith(materials: mats),
          {'chitin': each, 'mineral': each, 'sap': each},
        );
      case 'fossil':
        return (
          save.copyWith(
            materials: {
              ...save.materials,
              MaterialKind.fossil:
                  save.materialCount(MaterialKind.fossil) + it.amount,
            },
          ),
          {'fossil': it.amount},
        );
      case 'fairyDust':
        return (
          save.copyWith(
            fairy: save.fairy.copyWith(dust: save.fairy.dust + it.amount),
          ),
          {'fairyDust': it.amount},
        );
      case 'fairyEgg':
        final grade = FairyGrade.values
            .where((g) => g.key == it.grade)
            .firstOrNull;
        if (fairy == null || grade == null) return (save, const {});
        final op = grantFairyEggs(
          save.fairy,
          fairy,
          List.filled(it.amount, grade),
        );
        return op.isOk
            ? (save.copyWith(fairy: op.state), {'fairyEggs': it.amount})
            : (save, const {});
      case 'skillShard':
        return (
          save.copyWith(
            skillGradeShards: {
              ...save.skillGradeShards,
              it.grade: (save.skillGradeShards[it.grade] ?? 0) + it.amount,
            },
          ),
          {'skillShard': it.amount, 'grade': it.grade},
        );
    }
    return (save, const {});
  }

  /// 수령 결과를 서버 세이브에 넣는다 — 재료·화석은 더하고, 요정 알은 요정함 규칙으로(넘치면 가루).
  SaveGame grant(SaveGame save, GuildMissionClaim r) {
    final mats = Map<MaterialKind, int>.from(save.materials);
    void add(MaterialKind k, int n) {
      if (n > 0) mats[k] = save.materialCount(k) + n;
    }

    add(MaterialKind.chitin, r.reward.chitin);
    add(MaterialKind.mineral, r.reward.mineral);
    add(MaterialKind.sap, r.reward.sap);
    add(MaterialKind.fossil, r.reward.fossil);
    var out = save.copyWith(materials: mats);
    final grade = FairyGrade.values
        .where((g) => g.key == missions.c.eggGrade)
        .firstOrNull;
    if (r.eggs > 0 && fairy != null && grade != null) {
      final op = grantFairyEggs(out.fairy, fairy, List.filled(r.eggs, grade));
      if (op.isOk) out = out.copyWith(fairy: op.state);
    }
    return out;
  }

  authed
    ..get('/guild/me', (Request req) async {
      final uid = userIdOf(req);
      try {
        final (status, out) = await guild.me(uid);
        return json(status, out);
      } on StateStoreException catch (e) {
        stderr.writeln('[guild/me] $uid: $e');
        return json(503, {'error': 'store_unavailable'});
      }
    })
    ..get('/guild/list', (Request req) async {
      final uid = userIdOf(req);
      final q = req.url.queryParameters;
      try {
        final (status, out) = await guild.list(
          uid,
          lang: q['lang'] ?? 'ko',
          query: q['q'] ?? '',
        );
        return json(status, out);
      } on StateStoreException catch (e) {
        stderr.writeln('[guild/list] $uid: $e');
        return json(503, {'error': 'store_unavailable'});
      }
    })
    ..post(
      '/guild/create',
      post('create', (uid, b) async {
        // 개설 비용(젤리)은 서버 세이브로 치른다 — 앱이 보낸 값을 믿지 않는다.
        // 길드가 **만들어진 뒤에** 차감한다: 이름 중복·동시 가입으로 실패하면 젤리를 안 쓴다.
        // (차감 저장이 실패하면 길드만 남는다 — 반대 순서면 젤리만 사라진다. 덜 나쁜 쪽.)
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        final cost = guild.config.createJellyCost;
        final r = await guild.create(
          uid,
          jelly: save.materialCount(MaterialKind.jelly),
          name: s(b, 'name'),
          lang: s(b, 'lang'),
          joinMode: s(b, 'joinMode'),
        );
        if (r.$1 != 200) return r;
        final paid = spendJelly(save, cost);
        if (paid != null) await storeSave(uid, paid);
        return (200, {...r.$2, 'jellySpent': cost});
      }),
    )
    ..get('/guild/missions', (Request req) async {
      final uid = userIdOf(req);
      try {
        final (status, out) = await missions.view(uid);
        return json(status, out);
      } on StateStoreException catch (e) {
        stderr.writeln('[guild/missions] $uid: $e');
        return json(503, {'error': 'store_unavailable'});
      }
    })
    ..post(
      '/guild/mission/start',
      post('mission/start', (uid, b) async {
        // 사냥터(보상 규모)·닉네임은 서버 세이브에서. 전투력은 앱 값 — 요구치가 같이 오르므로 부풀려도 얻는 게 없다.
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        return missions.start(
          uid,
          slot: (b['slot'] as num?)?.toInt() ?? -1,
          waitSec: (b['wait'] as num?)?.toInt() ?? 0,
          power: pw(b),
          stage: save.stageNumber,
          nickname: save.nickname,
        );
      }),
    )
    ..post(
      '/guild/mission/help',
      post('mission/help', (uid, b) async {
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        return missions.help(
          uid,
          s(b, 'missionId'),
          power: pw(b),
          stage: save.stageNumber,
          nickname: save.nickname,
        );
      }),
    )
    ..post(
      '/guild/mission/claim',
      post('mission/claim', (uid, _) async {
        // 세이브가 없으면 **수령 기록을 남기기 전에** 멈춘다(기록만 남고 못 받는 일이 없게).
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        final r = await missions.claimAll(uid);
        if (r.missions == 0) return (409, {'error': 'nothing_to_claim'});
        final next = grant(save, r);
        await storeSave(uid, next);
        return (
          200,
          {
            'save': next.toJson(),
            'granted': {...r.reward.toJson(), 'eggs': r.eggs},
            'missions': r.missions,
          },
        );
      }),
    )
    ..get('/guild/boss', (Request req) async {
      final uid = userIdOf(req);
      try {
        final (status, out) = await boss.view(uid);
        return json(status, out);
      } on StateStoreException catch (e) {
        stderr.writeln('[guild/boss] $uid: $e');
        return json(503, {'error': 'store_unavailable'});
      }
    })
    ..post(
      '/guild/boss/attack',
      post('boss/attack', (uid, _) => boss.attack(uid)),
    )
    ..post(
      '/guild/boss/claim',
      post('boss/claim', (uid, _) async {
        // 세이브가 없으면 수령 기록을 남기기 **전에** 멈춘다.
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        final (st, out, jelly) = await boss.claimLastWeek(uid);
        if (st != 200) return (st, out);
        final next = save.copyWith(
          materials: {
            ...save.materials,
            MaterialKind.jelly: save.materialCount(MaterialKind.jelly) + jelly,
          },
        );
        await storeSave(uid, next);
        return (200, {...out, 'save': next.toJson(), 'jelly': jelly});
      }),
    )
    ..get('/guild/war', (Request req) async {
      final uid = userIdOf(req);
      try {
        final (status, out) = await war.view(uid);
        return json(status, out);
      } on StateStoreException catch (e) {
        stderr.writeln('[guild/war] $uid: $e');
        return json(503, {'error': 'store_unavailable'});
      }
    })
    ..post(
      '/guild/war/claim',
      post('war/claim', (uid, _) async {
        // 세이브가 없으면 수령 기록을 남기기 **전에** 멈춘다.
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        final (st, out, jelly) = await war.claim(uid);
        if (st != 200) return (st, out);
        final next = save.copyWith(
          materials: {
            ...save.materials,
            MaterialKind.jelly: save.materialCount(MaterialKind.jelly) + jelly,
          },
        );
        await storeSave(uid, next);
        return (200, {...out, 'save': next.toJson(), 'jelly': jelly});
      }),
    )
    ..post('/guild/donate', post('donate', (uid, _) => guild.donate(uid)))
    ..post(
      '/guild/skill/up',
      post('skill/up', (uid, b) => guild.skillUp(uid, s(b, 'skillId'))),
    )
    ..post(
      '/guild/skill/reset',
      post('skill/reset', (uid, _) => guild.skillReset(uid)),
    )
    ..post(
      '/guild/shop/buy',
      post('shop/buy', (uid, b) async {
        // 세이브가 없으면 코인을 쓰기 **전에** 멈춘다.
        final save = await loadSave(uid);
        if (save == null) return (409, {'error': 'no_save'});
        final (st, out) = await guild.buy(uid, s(b, 'itemId'));
        if (st != 200) return (st, out);
        final it = GuildShopItem.fromJson(out['item'] as Map<String, dynamic>);
        final (next, granted) = grantItem(save, it);
        await storeSave(uid, next);
        final (_, view) = await guild.me(uid);
        return (200, {...view, 'save': next.toJson(), 'granted': granted});
      }),
    )
    ..post(
      '/guild/join',
      post('join', (uid, b) => guild.join(uid, s(b, 'guildId'))),
    )
    ..post(
      '/guild/request/cancel',
      post('cancel', (uid, b) => guild.cancelRequest(uid, s(b, 'guildId'))),
    )
    ..post('/guild/leave', post('leave', (uid, _) => guild.leave(uid)))
    ..post(
      '/guild/kick',
      post('kick', (uid, b) => guild.kick(uid, s(b, 'userId'))),
    )
    ..post(
      '/guild/role',
      post(
        'role',
        (uid, b) => guild.setRole(uid, s(b, 'userId'), s(b, 'role')),
      ),
    )
    ..post(
      '/guild/request/answer',
      post(
        'answer',
        (uid, b) => guild.answerRequest(
          uid,
          s(b, 'userId'),
          accept: b['accept'] == true,
        ),
      ),
    )
    ..post(
      '/guild/settings',
      post(
        'settings',
        (uid, b) => guild.settings(
          uid,
          notice: b['notice'] as String?,
          joinMode: b['joinMode'] as String?,
        ),
      ),
    );
}
