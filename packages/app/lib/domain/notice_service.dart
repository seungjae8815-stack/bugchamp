import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_server.dart';
import 'save_controller.dart';
import 'server_sync.dart';

/// 운영이 보낸 공지 1건.
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    this.createdAt,
  });

  /// 서버 일련번호. **증가하는 값**이라 "이 값보다 크면 새 공지"로 판단한다
  /// (SaveGame.lastReadNoticeId).
  final int id;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? createdAt;

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
    id: (j['id'] as num?)?.toInt() ?? 0,
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    pinned: j['pinned'] == true,
    createdAt: j['created_at'] == null
        ? null
        : DateTime.tryParse(j['created_at'].toString())?.toUtc(),
  );
}

/// 운영이 보낸 우편 1통(점검 보상·이벤트 지급 등).
///
/// 재화 구성은 깜짝선물([GiftMail])과 같은 5종이다 — 편지함이 이미 그 모양으로
/// 그리고 있어서 표시를 그대로 재사용한다.
class ServerMail {
  const ServerMail({
    required this.id,
    required this.title,
    required this.body,
    required this.gold,
    required this.jelly,
    required this.chitin,
    required this.mineral,
    required this.sap,
    this.endsAt,
  });

  final String id;
  final String title;
  final String body;
  final int gold;
  final int jelly;
  final int chitin;
  final int mineral;
  final int sap;

  /// 수령 기한(UTC). null 이면 무기한.
  final DateTime? endsAt;

  Map<MaterialKind, int> get materials => {
    if (chitin > 0) MaterialKind.chitin: chitin,
    if (mineral > 0) MaterialKind.mineral: mineral,
    if (sap > 0) MaterialKind.sap: sap,
    if (jelly > 0) MaterialKind.jelly: jelly,
  };

  static int _n(Object? v) {
    final i = (v is num) ? v.toInt() : 0;
    return i < 0 ? 0 : i;
  }

  factory ServerMail.fromJson(Map<String, dynamic> j) => ServerMail(
    id: '${j['id']}',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    gold: _n(j['gold']),
    jelly: _n(j['jelly']),
    chitin: _n(j['chitin']),
    mineral: _n(j['mineral']),
    sap: _n(j['sap']),
    endsAt: j['ends_at'] == null
        ? null
        : DateTime.tryParse(j['ends_at'].toString())?.toUtc(),
  );
}

/// 진행 중인 공지. 서버가 없거나 실패하면 **빈 목록**(화면을 막지 않는다).
final noticesProvider = FutureProvider<List<Notice>>((ref) async {
  final server = ref.watch(gameServerProvider);
  if (!server.available) return const [];
  final res = await server.notices();
  final rows = res.data?['notices'];
  if (rows is! List) return const [];
  return [
    for (final r in rows.cast<Map<String, dynamic>>()) Notice.fromJson(r),
  ];
});

/// 아직 안 받은 운영 우편. 수령 후에는 `ref.invalidate` 로 다시 부른다.
final serverMailProvider = FutureProvider<List<ServerMail>>((ref) async {
  final server = ref.watch(gameServerProvider);
  if (!server.available) return const [];
  final res = await server.mail();
  final rows = res.data?['mail'];
  if (rows is! List) return const [];
  return [
    for (final r in rows.cast<Map<String, dynamic>>()) ServerMail.fromJson(r),
  ];
});

/// 안 읽은 공지가 있는지(느낌표 표시용). 로딩 중·실패면 false.
final hasUnreadNoticeProvider = Provider<bool>((ref) {
  final save = ref.watch(saveControllerProvider).value;
  final notices = ref.watch(noticesProvider).value;
  if (save == null || notices == null) return false;
  return notices.any((n) => save.isNewNotice(n.id));
});

/// 선물코드·우편 수령 결과. 실패 사유를 삼키지 않고 화면에 그대로 옮긴다.
enum RedeemResult {
  ok,

  /// 없는 코드.
  badCode,

  /// 기간이 지났다.
  expired,

  /// 수량이 모두 소진됐다.
  exhausted,

  /// 이 계정은 이미 사용했다 / 이미 받은 우편.
  alreadyUsed,

  /// 서버 미연결·통신 실패.
  failed,
}

/// 우편 수령 · 선물코드 사용을 서버에 요청하고 결과 세이브를 채택한다.
///
/// **지급을 앱이 직접 하지 않는 이유**: 재화를 앱이 더하면 다음 세이브 업로드에서
/// 골드 급증 상한(`GameActions._goldSanityFloor`)에 걸려 정당한 보상이 잘린다.
/// 구매(`/purchase`)와 같은 방식으로 서버가 확정한 세이브를 그대로 받는다.
class RewardClaimer {
  const RewardClaimer(this.ref);

  final Ref ref;

  Future<RedeemResult> claimMail(String id) =>
      _run(() => ref.read(gameServerProvider).claimMail(id));

  Future<RedeemResult> redeemCode(String code) =>
      _run(() => ref.read(gameServerProvider).redeemCode(code.trim()));

  Future<RedeemResult> _run(Future<ServerResult> Function() call) async {
    final server = ref.read(gameServerProvider);
    if (!server.available) return RedeemResult.failed;

    // **먼저 최신 로컬 세이브를 올린다.** 서버는 자기 저장본(최대 60초 낡음)에
    // 보상을 얹어 돌려주고 앱이 그걸 채택하므로, 이 단계를 건너뛰면 최근 1분의
    // 진행이 사라진다. 올리지 못했으면 수령을 진행하지 않는다 — 보상보다
    // 진행도를 잃지 않는 쪽이 중요하다(다음에 다시 받으면 된다).
    final save = ref.read(saveControllerProvider).value;
    if (!await flushSaveBeforeServerAction(server, save)) {
      return RedeemResult.failed;
    }

    final res = await call();
    if (res.isOk && res.save != null) {
      await ref
          .read(saveControllerProvider.notifier)
          .adoptServerSave(res.save!);
      ref.invalidate(serverMailProvider);
      return RedeemResult.ok;
    }
    return switch (res.error) {
      'code_expired' => RedeemResult.expired,
      'code_exhausted' => RedeemResult.exhausted,
      'code_already_used' || 'already_claimed' => RedeemResult.alreadyUsed,
      // 우편이 목록에 없다 = 남의 것/기간 지남/이미 받음. 사용자에겐 "이미 받음"이
      // 가장 흔하고 이해되는 설명이다.
      'mail_not_found' => RedeemResult.alreadyUsed,
      'bad_code' => RedeemResult.badCode,
      _ => RedeemResult.failed,
    };
  }
}

final rewardClaimerProvider = Provider<RewardClaimer>(RewardClaimer.new);
