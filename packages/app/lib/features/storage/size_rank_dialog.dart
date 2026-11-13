import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_server.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/avatar.dart';
import '../../ui/format.dart';
import '../../ui/game_dialog.dart';

/// 종별 최대 크기 순위 창(2026-11-10) — 서버가 상위 30 + 내 순위를 대신 읽어 준다.
/// 기록은 업로드 때 도감 최고 크기(수컷 기록)가 오른 종만 쌓인다.
Future<void> showSizeRankDialog(
  BuildContext context,
  String speciesId,
  String speciesName,
) {
  final l = AppLocalizations.of(context);
  final future = ProviderScope.containerOf(
    context,
  ).read(gameServerProvider).speciesSizeRank(speciesId);
  return showGameDialog<void>(
    context,
    title: l.sizeRankTitle(speciesName),
    icon: Icons.straighten_rounded,
    content: FutureBuilder<ServerResult>(
      future: future,
      builder: (context, snap) {
        final res = snap.data;
        if (res == null) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = res.isOk ? res.data : null;
        final raw = data == null ? null : data['top'];
        final top = raw is List ? raw : const [];
        if (top.isEmpty) {
          return Text(
            res.isOk ? l.sizeRankEmpty : l.sizeRankOffline,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          );
        }
        final me = res.data?['me'] as Map?;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              if (me != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l.sizeRankMine(
                      '${me['rank']}',
                      formatSizeMm((me['size'] as num).toDouble()),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFD977),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              for (final r in top.cast<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${r['rank']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      AvatarCircle(id: r['avatar'] as String?, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r['nickname'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: r['me'] == true
                                ? const Color(0xFFFFD977)
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${formatSizeMm((r['size'] as num).toDouble())}mm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
    actions: [gameDialogButton(l.actionClose, popOnTap(context))],
  );
}
