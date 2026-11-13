import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_data.dart';
import '../../domain/game_server.dart';
import '../../domain/providers.dart';
import '../../domain/save_controller.dart';
import '../../domain/server_sync.dart'
    show flushSaveBeforeServerAction, withServerSaveLock;
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';
import '../../ui/bug_grade.dart';
import '../../ui/avatar.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';
import '../../ui/labels.dart';
import '../../ui/toast.dart';
import '../storage/specimen_box.dart';
import 'duel_bug_build.dart';

/// 왕중왕전 그림 자리(2026-11-12) — `assets/images/ui/kotk_*.webp`. 없으면 이미 있는 그림으로 대신한다.
Widget _kotkImage(
  String name,
  List<String> fallbacks, {
  required double size,
  required IconData icon,
}) => gameImageChain(
  ['assets/images/ui/kotk_$name.webp', ...fallbacks],
  size: size,
  fallback: Icon(icon, size: size * 0.8, color: _gold),
);

/// 왕중왕전 트로피(홈 배너·팝업 제목).
Widget kotkTrophyIcon({double size = 30}) => _kotkImage(
  'trophy',
  const ['assets/images/ui/rank/trophy.webp'],
  size: size,
  icon: Icons.emoji_events_rounded,
);

const _gold = Color(0xFFFFD977);
const _goldDeep = Color(0xFFB8862B);

/// 왕중왕전(2026-11-10 사장님 확정) — 주마다 곤충 1마리로 겨루는 단판 토너먼트.
///
/// 접수는 결투 시즌 마감(일 09시)까지, 대진·결과는 서버가 정한다. **지면 그 곤충은 표본**이 되어
/// 결투·대회·펫에 다시 못 쓰고(채집함 칸 밖), 16강 이상은 명예의 전당에 남는다.
/// 홈 아이콘 줄 아래 배너에서 들어온다(2026-11-12 — 왕충 선발대회 자리).
class KotkScreen extends ConsumerStatefulWidget {
  const KotkScreen({super.key});

  @override
  ConsumerState<KotkScreen> createState() => _KotkScreenState();
}

class _KotkScreenState extends ConsumerState<KotkScreen> {
  late Future<ServerResult> _status = _load();

  Future<ServerResult> _load() => ref.read(gameServerProvider).kotkStatus();

  void _reload() => setState(() => _status = _load());

  String _place(AppLocalizations l, int p) => switch (p) {
    1 => l.kotkPlace1,
    2 => l.kotkPlace2,
    _ => l.kotkPlaceN('$p'),
  };

  String _species(String? id) {
    final data = ref.read(gameDataProvider).value;
    final sp = id == null ? null : data?.speciesById[id];
    if (sp == null) return id ?? '';
    return sp.name.resolve(Localizations.localeOf(context).languageCode);
  }

  Future<void> _enter(AppLocalizations l) async {
    final save = ref.read(saveControllerProvider).value;
    final data = ref.read(gameDataProvider).value;
    if (save == null || data == null) return;
    final cfg = data.petConfig;
    final now = ref.read(clockProvider).now().toUtc();
    final adults = save.bugs.where((b) {
      if (save.retiredBugs.contains(b.id)) return false;
      final st = cfg == null
          ? b.stage
          : effectiveStage(b.stage, b.stageSince, now, cfg);
      return st == LifeStage.adult;
    }).toList();
    // 전투력 높은 순(2026-11-12 점검 — 같은 종이 여럿이면 어느 것인지 몰라 아끼던 곤충을 잘못 낼 수 있었다).
    final lang = Localizations.localeOf(context).languageCode;
    final power = {
      for (final b in adults)
        b.id: duelPowerOf(duelBugFor(b, data, save, lang), data),
    };
    adults.sort((a, b) => power[b.id]!.compareTo(power[a.id]!));
    if (adults.isEmpty) {
      showCenterToast(context, l.kotkNoAdult);
      return;
    }
    final picked = await showGameDialog<IndividualBug>(
      context,
      title: l.kotkPickTitle,
      iconWidget: kotkTrophyIcon(),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in adults)
              ListTile(
                dense: true,
                leading: data.speciesById[b.speciesId] == null
                    ? null
                    : bugAvatar(data.speciesById[b.speciesId]!, size: 36),
                title: Text(
                  _species(b.speciesId),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  [
                    if (data.speciesById[b.speciesId] case final sp?)
                      gradeLabel(l, bugRarityOf(data, b, sp)),
                    '${formatSizeMm(b.sizeMm)}mm',
                    'Lv.${b.level}',
                    if (save.isEquipped(b.id)) l.equippedBadge,
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Text(
                  formatCompact(power[b.id]!.round()),
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(b),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await showGameDialog<bool>(
      context,
      title: l.kotkConfirmTitle,
      // 지면 표본이 된다 — 표본함 그림으로 경고한다.
      iconWidget: specimenBoxIcon(),
      content: Text(
        [
          l.kotkConfirmBody(_species(picked.speciesId)),
          if (save.isEquipped(picked.id)) l.kotkPetWarn,
        ].join('\n'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
      ),
      actions: [
        gameDialogButton(
          l.actionCancel,
          popOnTap(context, false),
          primary: false,
        ),
        gameDialogButton(l.kotkConfirmGo, popOnTap(context, true)),
      ],
    );
    if (ok != true || !mounted) return;
    final res = await _locked(
      () => ref.read(gameServerProvider).kotkEnter(picked.id),
      (r) => ref
          .read(saveControllerProvider.notifier)
          .adoptKotkEntry(
            week: r.data?['ktP'] as String?,
            bugId: r.data?['ktE'] as String?,
          ),
    );
    if (!mounted) return;
    if (res == null || !res.isOk) {
      showCenterToast(context, switch (res?.error) {
        'kotk_closed' => l.kotkClosedNow,
        'kotk_preparing' => l.kotkPreparingErr,
        'bug_retired' => l.kotkRetiredBug,
        _ => l.kotkFailed,
      });
      return;
    }
    showCenterToast(context, l.kotkEntered);
    _reload();
  }

  /// 서버 행동을 **최신 세이브를 올린 뒤** 한 줄로 돈다(2026-11-12 점검 — 다른 서버 행동과 같은 [withServerSaveLock]).
  /// 안 그러면 주기 업로드가 읽어 둔 저장본으로 참가 기록(`ktP`·`ktE`)을 지우거나, 참가 안의 지난주 결과 반영과
  /// 엇갈렸다. 올리기에 실패하면 null.
  Future<ServerResult?> _locked(
    Future<ServerResult> Function() call,
    Future<void> Function(ServerResult) adopt,
  ) {
    final ctrl = ref.read(saveControllerProvider.notifier);
    final server = ref.read(gameServerProvider);
    return withServerSaveLock(() async {
      if (!await flushSaveBeforeServerAction(server, () => ctrl.latestSave)) {
        return null;
      }
      final r = await call();
      if (r.isOk) await adopt(r);
      return r;
    });
  }

  Future<void> _withdraw(AppLocalizations l) async {
    final res = await _locked(
      () => ref.read(gameServerProvider).kotkWithdraw(),
      (_) => ref.read(saveControllerProvider.notifier).adoptKotkEntry(),
    );
    if (!mounted) return;
    if (res == null || !res.isOk) {
      showCenterToast(context, l.kotkFailed);
      return;
    }
    showCenterToast(context, l.kotkWithdrawn);
    _reload();
  }

  static const _h = TextStyle(
    color: _gold,
    fontWeight: FontWeight.w900,
    fontSize: 15,
  );
  static const _b = TextStyle(color: Colors.white, fontSize: 13, height: 1.4);

  /// 금테 카드 + 머리 줄(그림 아이콘 · 제목).
  Widget _card({
    required Widget icon,
    required String title,
    required Widget child,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xE62A1F12), Color(0xE6140F09)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x99D4A64A), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: _h)),
          ],
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x00D4A64A), Color(0xAAD4A64A), Color(0x00D4A64A)],
            ),
          ),
        ),
        child,
      ],
    ),
  );

  Widget _goldButton(String label, VoidCallback onTap) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFFE08A), _goldDeep]),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF6B4A12)),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2B1D07),
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// 맨 위 무대 — 경기장 그림 위에 접수 상태·참가 수.
  Widget _hero(AppLocalizations l, Map d, bool open) {
    final preparing = d['preparing'] == true;
    final round = d['round'];
    final status = preparing
        ? l.kotkPreparing
        : open
        ? l.kotkOpen
        : l.kotkClosedNow;
    return Container(
      height: 170,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCD4A64A), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          gameImageChain(
            const [
              'assets/images/ui/kotk_hero.webp',
              'assets/images/ui/event/arena_bg.webp',
            ],
            size: 400,
            fit: BoxFit.cover,
            fallback: const ColoredBox(color: Color(0xFF2A1F12)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC000000)],
                stops: [0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                kotkTrophyIcon(size: 46),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: open
                              ? const Color(0xCC2E7D32)
                              : preparing
                              ? const Color(0xCC5D4A8A)
                              : const Color(0xCC6D4C41),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          round is num
                              ? '${l.kotkRound('$round')} · $status'
                              : status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // 준비 중 — 일정 문장은 아래 참가 카드에만(위아래로 같은 문장이 두 번 보였다).
                        preparing
                            ? '${l.kotkRound('1')} ${l.kotkTitle}'
                            : l.kotkCount(
                                '${d['count'] ?? 0}',
                                '${d['maxSize'] ?? 32}',
                              ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 제1회 일정 — battle.json → kotk.firstWeek(월요일) 09시 접수 시작, 그 주 일요일 09시 결과.
  String _preparingText(AppLocalizations l) {
    final first = DateTime.tryParse(
      ref.read(gameDataProvider).value?.battleConfig?.kotk.firstWeek ?? '',
    );
    if (first == null) return l.kotkPreparingErr;
    final end = first.add(const Duration(days: 6));
    // 날짜 묶음(11월 22일(일) 09시)은 줄바꿈 없는 공백으로 — '11월/22일'로 끊겼다.
    return l
        .kotkPreparingBody(
          '${first.month}',
          '${first.day}',
          '${end.month}',
          '${end.day}',
        )
        .replaceAllMapped(
          // ko `11월 22일(일) 09시` · en `11/22 (Sun) 09:00` (ja 는 띄어쓰기가 없다).
          // 한국어 문구는 이미 단어 결합자(U+2060)가 글자 사이에 들어 있다(KeepWordsKo) — 그 글자도 허용한다.
          RegExp(
            '[\\d\u2060]+\u2060?월 [\\d\u2060]+\u2060?일\\S* [\\d\u2060]+\u2060?시'
            r'|\d+/\d+ \(\w+\) \d+:\d+',
          ),
          (m) => noBreak(m[0]!),
        );
  }

  /// 성적 보상 표(battle.json → kotk.rewards).
  Widget _rewards(AppLocalizations l) {
    final rewards =
        ref.read(gameDataProvider).value?.battleConfig?.kotk.rewards ??
        const <KotkReward>[];
    if (rewards.isEmpty) return const SizedBox.shrink();
    String items(KotkReward r) => [
      if (r.jelly > 0) l.kotkRewardJelly(formatThousands(r.jelly)),
      if (r.potions > 0) l.kotkRewardPotion('${r.potions}'),
      if (r.fossil > 0) l.kotkRewardFossil(formatThousands(r.fossil)),
      if (r.elementStones > 0) l.kotkRewardElement('${r.elementStones}'),
      if (r.temperamentStones > 0) l.kotkRewardTemper('${r.temperamentStones}'),
    ].map(noBreak).join(' · ');
    return _card(
      icon: kotkTrophyIcon(size: 26),
      title: l.kotkRewardsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in [
            for (final r in rewards) (place: r.maxPlace, text: items(r)),
            // 32강 탈락은 보상 없이 표본 — 들어가기 전에 보이게(2026-11-12 점검, 대진의 절반이 여기).
            if (rewards.last.maxPlace < 32) (place: 32, text: l.kotkRewardNone),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      _place(l, row.place),
                      style: _b.copyWith(
                        color: _gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      keepWords(row.text),
                      style: _b.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              rankImageDlg('crown', size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.kotkRewardChamp,
                  style: _b.copyWith(
                    fontSize: 12,
                    color: const Color(0xFFFFE082),
                  ),
                ),
              ),
            ],
          ),
          // 최소 인원(2026-11-12 사장님 확정) — 들어가기 전에 알게.
          if ((ref
                      .read(gameDataProvider)
                      .value
                      ?.battleConfig
                      ?.kotk
                      .minEntrants ??
                  0) >
              0) ...[
            const SizedBox(height: 4),
            Text(
              keepWords(
                l.kotkMinNote(
                  '${ref.read(gameDataProvider).value!.battleConfig!.kotk.minEntrants}',
                ),
              ),
              style: _b.copyWith(fontSize: 11.5, color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }

  /// 대진 요약 — 내 순위 · 우승 · 라운드별 경기.
  Widget _bracket(AppLocalizations l, Map data, String title) {
    final ents = (data['entrants'] as List? ?? const []).cast<Map>();
    final rounds = (data['rounds'] as List? ?? const []).cast<List>();
    String name(int i) => i < 0 || i >= ents.length
        ? l.kotkBye
        : '${ents[i]['nickname']} · ${_species(ents[i]['species'] as String?)}';
    // 참가자가 없던 주(대진 없음)는 카드를 띄우지 않는다 — 빈 카드만 남았다(2026-11-12 실기).
    if (ents.isEmpty) return const SizedBox.shrink();
    final me = ents.where((e) => e['me'] == true).firstOrNull;
    final champ = ents.where((e) => e['place'] == 1).firstOrNull;
    return _card(
      icon: _kotkImage(
        'bracket',
        const ['assets/images/ui/rank_stage.webp'],
        size: 26,
        icon: Icons.account_tree_rounded,
      ),
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (champ != null)
            Row(
              children: [
                rankImageDlg('crown', size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${champ['nickname']} · ${_species(champ['species'] as String?)}',
                    style: _b.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _gold,
                    ),
                  ),
                ),
              ],
            ),
          if (me != null && me['place'] != null)
            Text(
              l.kotkMyPlace(_place(l, (me['place'] as num).toInt())),
              style: _b.copyWith(color: const Color(0xFFFFE082)),
            ),
          if (rounds.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.kotkBracket, style: _b),
              iconColor: Colors.white70,
              collapsedIconColor: Colors.white70,
              children: [
                for (var r = 0; r < rounds.length; r++) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rounds[r].length == 1
                          ? l.kotkFinal
                          : l.kotkPlaceN('${rounds[r].length * 2}'),
                      style: _h.copyWith(fontSize: 12),
                    ),
                  ),
                  for (final m in rounds[r].cast<Map>())
                    if ((m['a'] as num) >= 0 && (m['b'] as num) >= 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${name((m['a'] as num).toInt())}  ${m['wa']}:${m['wb']}  ${name((m['b'] as num).toInt())}',
                          style: _b.copyWith(fontSize: 11.5),
                        ),
                      ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// 내 참가 곤충 — 그림을 크게.
  Widget _myEntry(AppLocalizations l, Map mine) {
    final data = ref.read(gameDataProvider).value;
    final save = ref.read(saveControllerProvider).value;
    final bug = save?.bugs.where((b) => b.id == mine['bugId']).firstOrNull;
    final sp = data?.speciesById[mine['species']];
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x22FFD977),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (sp != null)
            bugStageImage(
              sp.id,
              LifeStage.adult,
              size: 64,
              sex: bug?.sex ?? Sex.male,
              fallback: bugAvatar(sp, size: 52),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.kotkMine(_species(mine['species'] as String?)),
                  style: _b.copyWith(
                    color: const Color(0xFFFFE082),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (bug != null)
                  Text(
                    '${formatSizeMm(bug.sizeMm)}mm · Lv.${bug.level}',
                    style: _b.copyWith(fontSize: 11.5, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider).value;
    return Scaffold(
      backgroundColor: const Color(0xFF120E08),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC1A130A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            kotkTrophyIcon(size: 26),
            const SizedBox(width: 6),
            Text(
              l.kotkTitle,
              style: const TextStyle(color: _gold, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 배경 — 그림(ui/kotk_bg.webp)이 없으면 어두운 금빛 조명.
          Positioned.fill(
            child: gameImage(
              'assets/images/ui/kotk_bg.webp',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              fallback: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.9),
                    radius: 1.3,
                    colors: [Color(0xFF4A3613), Color(0xFF120E08)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<ServerResult>(
              future: _status,
              builder: (context, snap) {
                final res = snap.data;
                if (res == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!res.isOk || res.data == null) {
                  return Center(
                    child: Text(
                      l.kotkOffline,
                      style: _b,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final d = res.data!;
                final open = d['open'] == true;
                final mine = d['mine'] as Map?;
                final hall = (d['hall'] as List? ?? const []).cast<Map>();
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _hero(l, d, open),
                    _card(
                      icon: _kotkImage(
                        'entry',
                        const ['assets/images/ui/dlg/ticket.webp'],
                        size: 26,
                        icon: Icons.confirmation_number_rounded,
                      ),
                      title: l.kotkEntryTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 접수가 닫히고 확정 전(일 09시~월 09시) — 표본·보상은 월요일에.
                          if (d['pending'] == true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                keepWords(l.kotkPendingNote),
                                style: _b.copyWith(
                                  color: const Color(0xFFFFE082),
                                ),
                              ),
                            ),
                          if (mine != null) _myEntry(l, mine),
                          if (mine == null && !open)
                            Text(
                              d['preparing'] == true
                                  ? keepWords(_preparingText(l))
                                  : l.kotkClosedNow,
                              style: _b,
                            ),
                          if (open)
                            Row(
                              children: [
                                Expanded(
                                  child: _goldButton(
                                    mine == null ? l.kotkEnter : l.kotkChange,
                                    () => _enter(l),
                                  ),
                                ),
                                if (mine != null) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                        color: Color(0x88FFFFFF),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                        horizontal: 14,
                                      ),
                                    ),
                                    onPressed: () => _withdraw(l),
                                    child: Text(l.kotkWithdraw),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    _card(
                      icon: _kotkImage(
                        'rules',
                        const ['assets/images/ui/dlg/notice.webp'],
                        size: 26,
                        icon: Icons.menu_book_rounded,
                      ),
                      title: l.kotkRulesTitle,
                      child: Text(keepWords(l.kotkRules), style: _b),
                    ),
                    _rewards(l),
                    if (d['current'] is Map)
                      _bracket(l, d['current'] as Map, l.kotkThisWeek),
                    if (d['previous'] is Map)
                      _bracket(l, d['previous'] as Map, l.kotkLastWeek),
                    _card(
                      icon: _kotkImage(
                        'hall',
                        const ['assets/images/ui/rank/crown.webp'],
                        size: 26,
                        icon: Icons.account_balance_rounded,
                      ),
                      title: l.kotkHall,
                      child: Column(
                        children: [
                          if (hall.isEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                keepWords(l.kotkHallEmpty),
                                style: _b,
                              ),
                            ),
                          for (final h in hall) _hallRow(l, data, h),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hallRow(AppLocalizations l, GameData? data, Map h) {
    final place = (h['place'] as num).toInt();
    final me = h['me'] == true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: place == 1 ? const Color(0x33FFD977) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: me ? Border.all(color: const Color(0xAAFFE082)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: place == 1
                ? rankImageDlg('crown', size: 24)
                : rankImageDlg('trophy', size: 20),
          ),
          const SizedBox(width: 6),
          if (data?.speciesById[h['species']] case final Species sp)
            bugAvatar(sp, size: 40)
          else
            const SizedBox(width: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_place(l, place)} · ${_species(h['species'] as String?)}',
                  style: _b.copyWith(
                    fontWeight: FontWeight.w800,
                    color: me || place == 1
                        ? const Color(0xFFFFE082)
                        : Colors.white,
                  ),
                ),
                Text(
                  '${h['nickname']} · ${h['round'] is num ? l.kotkRound('${h['round']}') : h['week']}',
                  style: _b.copyWith(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          AvatarCircle(id: h['avatar'] as String?, size: 26),
        ],
      ),
    );
  }
}
