/// 텔레그램 운영 명령 — 해석·서식 도구(2026-09-15).
///
/// 실행(DB·지급)은 `app.dart` 의 운영 패널 코드와 **같은 함수**를 쓴다. 여기는 입력을 쪼개고
/// 보기 좋게 찍는 순수 함수만 둔다(테스트하기 쉽게).
library;

/// `/명령@봇이름 나머지` → (명령, 나머지). 명령은 소문자.
({String name, String rest}) splitCommand(String text) {
  final t = text.trim();
  final space = t.indexOf(RegExp(r'\s'));
  final head = space < 0 ? t : t.substring(0, space);
  final rest = space < 0 ? '' : t.substring(space).trim();
  final name = head.replaceFirst('/', '').split('@').first.toLowerCase();
  return (name: name, rest: rest);
}

/// `a | b | c` → ['a','b','c'](양끝 공백 제거, 빈 칸 유지).
List<String> splitPipe(String rest) =>
    rest.isEmpty ? const [] : [for (final p in rest.split('|')) p.trim()];

/// 보상 문구 해석 — `젤리 100 골드 5만 키틴 1.5천` → {jelly:100, gold:50000, chitin:1500}.
///
/// 단위: 천·만·억·k·m. 모르는 단어는 무시하지 않고 [unknown] 에 담는다 — 오타를 조용히
/// 넘기면 "젤리를 줬는데 안 갔다"가 된다.
({Map<String, int> reward, List<String> unknown}) parseReward(String text) {
  const names = {
    '골드': 'gold',
    'gold': 'gold',
    '젤리': 'jelly',
    'jelly': 'jelly',
    '키틴': 'chitin',
    'chitin': 'chitin',
    '미네랄': 'mineral',
    'mineral': 'mineral',
    '수액': 'sap',
    'sap': 'sap',
  };
  final out = <String, int>{};
  final unknown = <String>[];
  final re = RegExp(
    r'([^\s\d.,]+)\s*([\d.,]+)\s*(천|만|억|k|m)?',
    caseSensitive: false,
  );
  var consumed = text;
  for (final m in re.allMatches(text)) {
    final key = names[m.group(1)!.toLowerCase()];
    final num = double.tryParse(m.group(2)!.replaceAll(',', ''));
    if (key == null || num == null) {
      unknown.add(m.group(0)!.trim());
      continue;
    }
    final mult = switch (m.group(3)?.toLowerCase()) {
      '천' || 'k' => 1000,
      '만' => 10000,
      'm' => 1000000,
      '억' => 100000000,
      _ => 1,
    };
    out[key] = (out[key] ?? 0) + (num * mult).round();
    consumed = consumed.replaceFirst(m.group(0)!, ' ');
  }
  final left = consumed.trim();
  if (left.isNotEmpty) unknown.add(left);
  return (reward: out, unknown: unknown);
}

/// 보상 한 줄 요약(확인 창·결과 알림용).
String rewardLabel(Map<String, dynamic> reward) {
  const labels = {
    'gold': '골드',
    'jelly': '젤리',
    'chitin': '키틴',
    'mineral': '미네랄',
    'sap': '수액',
  };
  final parts = [
    for (final e in labels.entries)
      if (((reward[e.key] as num?) ?? 0) > 0)
        '${e.value} ${_num(reward[e.key] as num)}',
  ];
  return parts.isEmpty ? '보상 없음' : parts.join(' · ');
}

String _num(num n) {
  final v = n.round();
  String unit(int base, String name) {
    final whole = v ~/ base;
    final frac = (v % base) * 10 ~/ base;
    return frac == 0 ? '$whole$name' : '$whole.$frac$name';
  }

  if (v >= 100000000 && v % 10000000 == 0) return unit(100000000, '억');
  if (v >= 10000 && v % 1000 == 0) return unit(10000, '만');
  return '$v';
}

/// 최근 채팅 목록 서식 — 오래된 것이 위(대화 순서대로 읽힌다).
String formatChat(List<Map<String, dynamic>> rows, {String? title}) {
  if (rows.isEmpty) return '💬 채팅이 없습니다';
  final ordered = rows.reversed.toList();
  final b = StringBuffer(title ?? '💬 최근 채팅 ${rows.length}건\n');
  for (final r in ordered) {
    final at = DateTime.tryParse('${r['created_at']}')?.toUtc();
    final kst = at?.add(const Duration(hours: 9));
    final time = kst == null
        ? '--:--'
        : '${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')}';
    final admin = r['is_admin'] == true ? '📢' : '';
    b.writeln('#${r['id']} $time $admin${r['nickname']}: ${r['body']}');
  }
  return b.toString().trimRight();
}

const telegramHelp = '''🛠 곤충키우기 운영 명령

조회
/stats — 지금 사용자·결제 통계
/user 닉네임 또는 uid — 계정 조회
/chat — 최근 채팅 20건 · /chat 50 · /chat 닉네임
/chatmin 10 — 채팅 요약을 몇 건마다 보낼지(기본 5)

채팅
/say 내용 — 운영자 이름으로 게임 채팅에 쓰기
/del 번호 — 채팅 삭제(목록의 #번호)

보내기 (버튼으로 한 번 더 확인)
/notice 제목 | 본문
/mail 닉네임또는uid | 제목 | 본문 | 젤리 100 골드 5만
/mailall 제목 | 본문 | 젤리 100
/code 코드명 | 젤리 50 | 사용횟수(선택)
/grant 닉네임또는uid | 상품id

문의 알림에 답장하면 그 사람에게 우편으로 갑니다.''';
