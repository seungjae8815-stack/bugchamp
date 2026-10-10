import 'dart:async';
import 'dart:convert';

import 'package:core_save/core_save.dart' show isAvatarId;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/combat_power.dart';
import '../domain/providers.dart';
import '../domain/pvp_backend.dart';
import '../domain/save_controller.dart';
import '../l10n/app_localizations.dart';
import 'art.dart';
import 'colors.dart';
import 'game_dialog.dart';
import 'toast.dart';

/// 프로필 그림(2026-10-10 사장님 확정, 1.0.19) — 모두 무료. 목록·순서·그림 경로는 `assets/data/avatars.json`.
///
/// 내 프로필 창에서 고르면 세이브(`SaveGame.avatar`)와 Supabase `profiles.avatar` 에 들어가고, 채팅(트리거가 찍는다)·
/// 랭킹·결투 순위표·결투 후보·왕충 선발대회에 보인다. 고르지 않은 사람·모르는 그림(새 버전 그림)은 기본 프로필.
/// 그림은 "색 원 + 곤충"만 — 갈색 테는 여기서 그린다(작게 줄여도 또렷하고 굵기가 같게).
class AvatarDef {
  const AvatarDef({
    required this.id,
    required this.image,
    this.name = const {},
  });

  final String id;
  final String image;
  final Map<String, String> name;

  String nameFor(String lang) => name[lang] ?? name['en'] ?? id;

  factory AvatarDef.fromJson(Map<String, dynamic> j) => AvatarDef(
    id: j['id'] as String,
    image: j['image'] as String,
    name: {
      for (final e in ((j['name'] as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    },
  );
}

class AvatarCatalog {
  const AvatarCatalog({required this.avatars, required this.defaultId});

  final List<AvatarDef> avatars;
  final String defaultId;

  AvatarDef? byId(String? id) {
    for (final a in avatars) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 보여 줄 그림 — 고르지 않았거나 모르는 id 면 기본 프로필.
  AvatarDef? shown(String? id) => byId(id) ?? byId(defaultId);

  factory AvatarCatalog.fromJson(Map<String, dynamic> j) => AvatarCatalog(
    avatars: [
      for (final a in (j['avatars'] as List).cast<Map<String, dynamic>>())
        AvatarDef.fromJson(a),
    ],
    defaultId: j['default'] as String,
  );
}

final avatarCatalogProvider = FutureProvider<AvatarCatalog>((ref) async {
  final raw = await rootBundle.loadString('assets/data/avatars.json');
  return AvatarCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

const _rim = Color(0xFF5B3A1E);
const _sage = Color(0xFF7E9481);

/// 동그란 프로필 그림(갈색 테 + 안쪽 꿀빛 선). [id] 가 null·모르는 값이면 기본 프로필.
class AvatarCircle extends ConsumerWidget {
  const AvatarCircle({super.key, required this.id, this.size = 32});

  final String? id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(avatarCatalogProvider).value?.shown(id);
    final ring = (size * 0.075).clamp(1.4, 3.5);
    final inner = size - ring * 2;
    // 목록을 아직 못 읽었거나 그림이 없으면 기본 프로필과 같은 모양(회녹색 + 곤충 아이콘).
    final fallback = Container(
      width: inner,
      height: inner,
      color: _sage,
      alignment: Alignment.center,
      child: Icon(
        Icons.bug_report_rounded,
        size: inner * 0.55,
        color: const Color(0xFFF4ECD8),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _rim,
        boxShadow: size >= 28
            ? const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Container(
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: kHoney.withValues(alpha: 0.85),
            width: (ring * 0.45).clamp(0.7, 1.6),
          ),
        ),
        child: ClipOval(
          child: def == null
              ? fallback
              : gameImage(
                  def.image,
                  width: inner,
                  height: inner,
                  fit: BoxFit.cover,
                  fallback: fallback,
                ),
        ),
      ),
    );
  }
}

/// 프로필 그림 고르기 창(내 프로필 창에서 연다). 고르면 세이브에 넣고 랭킹 프로필(`profiles.avatar`)도 바로 올린다.
Future<void> showAvatarPicker(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  // 이미 읽어 둔 목록이 있으면 바로 연다(동그란 프로필이 화면 어딘가에서 이미 읽게 한다).
  var loaded = ref.read(avatarCatalogProvider).value;
  if (loaded == null) {
    try {
      loaded = await ref.read(avatarCatalogProvider.future);
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
  }
  final AvatarCatalog cat = loaded!;
  final cur = ref.read(saveControllerProvider).value?.avatar ?? cat.defaultId;
  final nav = Navigator.of(context);
  final picked = await showGameDialog<String>(
    context,
    title: l.avatarPickTitle,
    icon: Icons.face_rounded,
    subtitle: l.avatarPickHint,
    content: SizedBox(
      width: double.maxFinite,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in cat.avatars)
            Tooltip(
              message: a.nameFor(lang),
              child: GestureDetector(
                key: ValueKey('avatarPick:${a.id}'),
                onTap: () => nav.pop(a.id),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: a.id == cur ? kHoney : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: a.id == cur
                        ? [
                            BoxShadow(
                              color: kHoney.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: AvatarCircle(id: a.id, size: 54),
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      gameDialogButton(l.actionCancel, () {
        if (nav.canPop()) nav.pop();
      }, primary: false),
    ],
  );
  if (picked == null ||
      picked == cur ||
      !isAvatarId(picked) ||
      !context.mounted) {
    return;
  }
  await ref.read(saveControllerProvider.notifier).setAvatar(picked);
  pushMyRankProfile(ref);
  if (context.mounted) showCenterToast(context, l.avatarChanged);
}

/// 랭킹 프로필(닉네임·그림·진행도…)을 지금 올린다 — 채팅·순위표가 새 그림을 바로 보게.
void pushMyRankProfile(WidgetRef ref) {
  final save = ref.read(saveControllerProvider).value;
  final backend = ref.read(pvpBackendProvider);
  if (save == null || !backend.isRemote) return;
  final power = displayCombatPower(
    save,
    ref.read(gameDataProvider).value,
    ref.read(clockProvider).now().toUtc(),
  );
  unawaited(backend.pushTrophies(me: PvpProfile.me(save, power: power)));
}
