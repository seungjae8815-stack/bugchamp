import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/data/game_data.dart';
import 'package:app/data/save_repository.dart';
import 'package:app/domain/chat_service.dart';
import 'package:app/domain/providers.dart';
import 'package:app/domain/save_controller.dart';
import 'package:app/features/chat/chat_screen.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:core_models/core_models.dart';
import 'package:core_save/core_save.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements SaveRepository {
  _Repo(this._g);
  SaveGame _g;
  @override
  SaveLoadFailure? get lastFailure => null;
  @override
  Future<SaveGame> load() async => _g;
  @override
  Future<void> save(SaveGame g) async => _g = g;
  @override
  Future<void> clear() async {}
}

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f').readAsStringSync())
        as Map<String, dynamic>;

GameData _data() => GameData.fromDecoded(
  species: _read('species.json'),
  traps: _read('traps.json'),
  fields: _read('fields.json'),
  spawns: _read('spawns.json'),
  runConfig: _read('run_config.json'),
  chatRules: _read('chat.json'),
);

ChatMessage _msg(String id, String body, {String? guild}) => ChatMessage(
  id: id,
  userId: 'u-$id',
  nickname: '닉$id',
  body: body,
  createdAt: DateTime.utc(2026, 10, 5, 3, int.parse(id)),
  guildId: guild,
);

/// 서버(DB 정책 = 전체 + 내 길드 글) 흉내 — 받는 쪽 거르기는 앱의 [chatMessageVisible].
class _FakeChat implements ChatService {
  final all = <ChatMessage>[
    _msg('1', '전체 인사'),
    _msg('2', '길드 공지', guild: 'g1'),
    _msg('3', '남의 길드 글', guild: 'g9'),
  ];
  final sent = <({String body, String? guildId})>[];
  final _events = StreamController<ChatMessage>.broadcast();

  @override
  bool get available => true;

  @override
  Future<List<ChatMessage>> recent({
    int limit = 50,
    String? guildId,
    bool mixed = false,
  }) async => [
    for (final m in all)
      // DB 정책이 남의 길드 글은 애초에 안 준다.
      if (m.guildId != 'g9' &&
          chatMessageVisible(m, guildId: guildId, mixed: mixed))
        m,
  ];

  @override
  Stream<ChatMessage> subscribe({String? guildId, bool mixed = false}) =>
      _events.stream.where(
        (m) => chatMessageVisible(m, guildId: guildId, mixed: mixed),
      );

  @override
  Future<bool> send({
    required String nickname,
    required String body,
    String badge = '',
    String? guildId,
  }) async {
    sent.add((body: body, guildId: guildId));
    return true;
  }

  @override
  Future<bool> report({
    required String messageId,
    required String reason,
  }) async => true;

  @override
  Future<bool> deleteOwn({required String messageId}) async => true;

  @override
  void dispose() {}
}

Future<_FakeChat> _pump(WidgetTester tester, {String? guildId}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final chat = _FakeChat();
  final container = ProviderContainer(
    overrides: [
      chatServiceProvider.overrideWithValue(chat),
      gameDataProvider.overrideWith((ref) => _data()),
      saveRepositoryProvider.overrideWithValue(
        _Repo(SaveGame.initial(createdAt: DateTime.utc(2026, 10))),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(saveControllerProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // 길드가 닫힌 빌드(kGuildOpen=false)에서는 guildId 가 곧 내 길드다.
        home: ChatScreen(guildId: guildId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chat;
}

void main() {
  test('채팅 탭 필터 — 전체 탭 = 전체 + 내 길드 · 길드 탭 = 내 길드만 · 길드 없음 = 전체만', () {
    final global = _msg('1', 'a');
    final mine = _msg('2', 'b', guild: 'g1');
    final other = _msg('3', 'c', guild: 'g9');
    bool all(ChatMessage m) =>
        chatMessageVisible(m, guildId: 'g1', mixed: true);
    bool guild(ChatMessage m) => chatMessageVisible(m, guildId: 'g1');
    bool none(ChatMessage m) => chatMessageVisible(m);
    expect([global, mine, other].where(all), [global, mine]);
    expect([global, mine, other].where(guild), [mine]);
    expect([global, mine, other].where(none), [global]);
  });

  testWidgets('길드가 없으면 탭 없이 전체 채팅만', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('chatTab:1')), findsNothing);
    expect(find.text('전체 인사'), findsOneWidget);
    expect(find.text('길드 공지'), findsNothing);
  });

  testWidgets('전체 탭에는 길드 글이 [길드] 표시로 섞이고, 길드 탭에는 길드 글만 · 쓰는 곳도 탭을 따른다', (
    tester,
  ) async {
    final chat = await _pump(tester, guildId: 'g1');
    // 전체 탭(처음).
    expect(find.text('전체 인사'), findsOneWidget);
    expect(find.text('길드 공지'), findsOneWidget);
    expect(find.text('남의 길드 글'), findsNothing);
    expect(find.byKey(const ValueKey('chatGuildTag')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '모두 안녕');
    await tester.tap(find.byIcon(Icons.send_rounded).first);
    await tester.pumpAndSettle();
    expect(chat.sent.last.guildId, isNull, reason: '전체 탭에서 쓰면 전체 글');

    // 길드 탭.
    await tester.tap(find.byKey(const ValueKey('chatTab:1')));
    await tester.pumpAndSettle();
    final guildPane = find.byKey(const ValueKey('chatPane:guild:g1'));
    expect(
      find.descendant(of: guildPane, matching: find.text('길드 공지')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: guildPane, matching: find.text('전체 인사')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: guildPane,
        matching: find.byKey(const ValueKey('chatGuildTag')),
      ),
      findsNothing,
      reason: '길드 탭에는 표시가 필요 없다',
    );
    await tester.enterText(
      find.descendant(of: guildPane, matching: find.byType(TextField)),
      '길드원 안녕',
    );
    // 도배 방지(3초) 뒤에 보낸다.
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(
      find.descendant(of: guildPane, matching: find.byIcon(Icons.send_rounded)),
    );
    await tester.pumpAndSettle();
    expect(chat.sent.last, (body: '길드원 안녕', guildId: 'g1'));
    expect(tester.takeException(), isNull);
  });
}
