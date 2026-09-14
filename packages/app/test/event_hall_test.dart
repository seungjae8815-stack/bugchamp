import 'package:app/domain/game_server.dart';
import 'package:app/domain/providers.dart';
import 'package:app/features/event/event_hall.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `/event/hall` 응답을 흉내낸다. null 이면 실패(오프라인·구버전 서버).
class _HallServer implements GameServer {
  _HallServer(this.data);

  final Map<String, dynamic>? data;

  @override
  bool get available => true;

  @override
  Future<ServerResult> eventHall() async => data == null
      ? const ServerResult.fail('not_found', 404)
      : ServerResult.ok(data!);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic>? data) async {
  // 폰 폭(360)에서 그린다 — 시상대 세 칸과 참가자 줄이 넘치지 않아야 한다.
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameServerProvider.overrideWithValue(_HallServer(data)),
        gameDataProvider.overrideWith((ref) => Future.error('no data')),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: EventHallSection())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _entry(int rank, String name, {bool me = false}) => {
  'rank': rank,
  'nickname': name,
  'score': 1000000 * (30 - rank),
  'wave': 30 - rank,
  'badge': rank == 1
      ? 'champion:1'
      : (rank <= 10 ? 'finalist:1' : 'participant:1'),
  'isMe': me,
};

void main() {
  testWidgets('시상대 · 4~10위 · 참가자가 한 화면에 그려진다', (tester) async {
    await _pump(tester, {
      'round': {'no': 1, 'roundId': '2026-0901'},
      'next': {'no': 2, 'roundId': '2026-0928'},
      'entries': [
        for (var r = 1; r <= 14; r++) _entry(r, '곤충왕$r', me: r == 12),
      ],
      'truncated': false,
    });

    expect(find.text('명예의 전당'), findsOneWidget);
    expect(find.text('1회차 · 참가 14명'), findsOneWidget);
    // 시상대(1~3위)
    expect(find.text('곤충왕1'), findsOneWidget);
    expect(find.text('곤충왕3'), findsOneWidget);
    // 4~10위 줄에는 입상 뱃지가 붙는다.
    expect(find.text('4~10위'), findsOneWidget);
    expect(find.text('1회차 입상'), findsNWidgets(7));
    // 11위 이하는 참가자 이름표로.
    expect(find.text('함께한 참가자'), findsOneWidget);
    expect(find.text('곤충왕14'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '폰 폭에서 넘치면 안 된다');
  });

  testWidgets('명단이 잘렸으면 인원에 + 와 "외 다수"가 붙는다', (tester) async {
    await _pump(tester, {
      'round': {'no': 1},
      'entries': [for (var r = 1; r <= 12; r++) _entry(r, 'u$r')],
      'truncated': true,
    });
    expect(find.text('1회차 · 참가 12+명'), findsOneWidget);
    expect(find.text('외 다수'), findsOneWidget);
  });

  /// 못 읽었는데 "아직 아무도 없어요"라고 말하면 사실이 아니다.
  testWidgets('서버가 답하지 않으면 섹션을 통째로 감춘다', (tester) async {
    await _pump(tester, null);
    expect(find.text('명예의 전당'), findsNothing);
    expect(find.text('아직 명예의 전당에 오른 사람이 없어요'), findsNothing);
  });
}
