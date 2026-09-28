import 'package:app/domain/chat_service.dart';
import 'package:app/domain/game_server.dart';
import 'package:app/domain/providers.dart';
import 'package:app/features/battle/league_board_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _BoardServer implements GameServer {
  _BoardServer(this.league, this.abyss);

  final Map<String, dynamic>? league;
  final Map<String, dynamic>? abyss;

  @override
  bool get available => true;

  @override
  Future<ServerResult> pvpLeagueBoard() async => league == null
      ? const ServerResult.fail('store_unavailable', 503)
      : ServerResult.ok(league!);

  @override
  Future<ServerResult> abyssBoard() async => abyss == null
      ? const ServerResult.fail('store_unavailable', 503)
      : ServerResult.ok(abyss!);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _pump(WidgetTester tester, _BoardServer server) async {
  // 폰 폭(360)에서 그린다 — 줄이 넘치지 않아야 한다.
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameServerProvider.overrideWithValue(server),
        gameDataProvider.overrideWith((ref) => Future.error('no data')),
        chatMyUserIdProvider.overrideWithValue('me'),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LeagueBoardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _row(int rank, {String? id}) => {
  'rank': rank,
  'user_id': id ?? 'u$rank',
  'nickname': '곤충왕$rank',
  'trophies': 200 - rank,
  'floor': 60 - rank,
  'boss_pm': 400,
  'power': 1.2e9,
  'sp': 'stag_giant',
};

void main() {
  final ends = DateTime.now()
      .toUtc()
      .add(const Duration(days: 2, hours: 3))
      .toIso8601String();

  testWidgets('결투 리그 — 머리·승강 안내·목록·하단 내 줄', (tester) async {
    await _pump(
      tester,
      _BoardServer({
        'season': '2026-09-28',
        'league': 'diamond',
        'endsAt': ends,
        'total': 30,
        'promote': 6,
        'demote': 6,
        'me': {'rank': 4, 'trophies': 196},
        'top': [
          for (var r = 1; r <= 30; r++) _row(r, id: r == 4 ? 'me' : null),
        ],
      }, null),
    );
    expect(find.text('순위표'), findsOneWidget);
    expect(find.text('다이아 리그'), findsOneWidget);
    expect(find.textContaining('새 시즌 시작'), findsOneWidget);
    expect(find.text('상위 6명 승급 · 하위 6명 강등'), findsOneWidget);
    expect(find.text('곤충왕1'), findsOneWidget);
    // 내 줄은 목록과 하단 고정 두 군데에 보인다.
    expect(find.text('곤충왕4'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('심연 탭 — 층·벽 보스 피해 · 기록 없으면 안내', (tester) async {
    await _pump(
      tester,
      _BoardServer(
        {
          'league': 'bronze',
          'endsAt': ends,
          'total': 0,
          'promote': 0,
          'demote': 0,
          'top': const [],
        },
        {
          'week': '2026-09-28',
          'endsAt': ends,
          'total': 3,
          'top': [for (var r = 1; r <= 3; r++) _row(r)],
        },
      ),
    );
    expect(find.text('아직 이번 주 기록이 없어요'), findsOneWidget);
    await tester.tap(find.text('심연'));
    await tester.pumpAndSettle();
    expect(find.text('심연 주간 순위'), findsOneWidget);
    expect(find.text('59층'), findsOneWidget);
    expect(find.text('이번 주 심연 1층을 깨면 순위에 올라요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
