import 'package:core_models/core_models.dart';
import 'package:test/test.dart';

/// 닉네임 문자 구성 규칙.
///
/// 배경(2026-08-27 실기): 조합되지 않는 한글 자모로 만든 닉네임이 랭킹 2위에
/// 올라와 있었다. 결합 문자는 **세로로 쌓여** `maxLines: 1` 을 뚫고 줄 높이를
/// 밀어낸다 — 순위표·채팅·전투 화면이 통째로 흐트러진다. 길이 제한이 8자여도
/// 자모 8개면 충분히 뭉갠다.
///
/// ⚠️ 이 테스트의 절반은 **막지 말아야 할 것**을 지킨다. 글로벌 출시(ko/en/ja)라
/// 가나·한자를 막으면 깨진 닉네임보다 훨씬 큰 사고다.
void main() {
  const rules = ChatRules(bannedWords: [], reservedNames: []);

  group('허용해야 한다 (막으면 사고)', () {
    for (final ok in [
      '곤충왕',
      '조은둥이',
      'Weevil',
      'aaa',
      'Player_1',
      'a.b-c',
      '카나타', // 한글
      'かぶとむし', // 히라가나
      'カブトムシ', // 가타카나
      '甲虫王者', // 한자
      'ｶﾌﾞﾄ', // 반각 가타카나
      'ゲーム好き', // 가나 + 장음부호
      '곤충 왕', // 공백
    ]) {
      test('"$ok"', () {
        expect(rules.nicknameCharsOk(ok), isTrue);
        expect(rules.nicknameAllowed(ok), isTrue);
        expect(rules.maskNickname(ok), ok, reason: '가려지면 안 된다');
      });
    }
  });

  group('막아야 한다', () {
    for (final bad in [
      'ㅃㅃㅁㅁ', // 조합 안 된 자모(호환 자모)
      '\u1100\u1161\u11A8', // 첫가끝 자모(U+1100 블록)
      'a\u0301\u0302\u0303', // 결합 악센트 쌓기(Zalgo)
      '가\u0336\u0336', // 취소선 결합 문자
      '\u200B\u200B', // 폭 없는 공백
      '🐛🐛', // 이모지 — 줄 높이를 밀어낸다
      '', // 빈 이름
      '   ', // 공백뿐
    ]) {
      test(bad.codeUnits.toString(), () {
        expect(rules.nicknameCharsOk(bad), isFalse);
        expect(rules.nicknameAllowed(bad), isFalse);
      });
    }
  });

  /// 등록을 막기 **전에** 만들어진 이름은 되돌릴 수 없다 —
  /// 금칙어와 같은 원칙으로 보여줄 때 대체한다.
  test('이미 등록된 깨진 이름은 표시할 때 가린다', () {
    expect(rules.maskNickname('ㅃㅃㅁㅁ', fallback: '이용자'), '이용자');
  });

  /// 운영자 메시지까지 가리면 안 된다.
  test('isAdmin 이면 그대로 둔다', () {
    expect(rules.maskNickname('ㅃㅃ', isAdmin: true), 'ㅃㅃ');
  });
}
