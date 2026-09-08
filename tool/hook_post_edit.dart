// PostToolUse 훅: 편집 직후 두 가지를 한다.
//
//  1. .dart 파일이면 그 파일 하나만 `dart format` 한다(§5 포맷 통과 필수).
//  2. 밸런스 JSON(packages/app/assets/data/*.json)이면 어떤 시뮬을 돌려야 하는지
//     Claude 에게 되짚어 준다 — CLAUDE.md 가 "반드시 돌린다"고 못 박은 절차인데
//     사람도 모델도 잊는다.
//
// 절대 편집을 막지 않는다. 무슨 일이 있어도 exit 0.
import 'dart:convert';
import 'dart:io';

/// 파일 이름 → 이 파일을 바꿨을 때 반드시 돌려야 하는 도구·테스트.
const _simByData = <String, String>{
  'pets.json':
      'dart run tool/jelly_sim.dart (젤리 수도꼭지) + '
      'dart test test/jelly_cost_test.dart',
  'run_config.json': 'dart run tool/balance_sim.dart (적응형 체력·성장 곡선)',
  'enhance.json': 'dart run tool/balance_sim.dart',
  'forge.json': 'dart run tool/forge_sim.dart',
  'missions.json': 'dart run tool/jelly_sim.dart',
  'daily.json': 'dart run tool/jelly_sim.dart',
  'gifts.json': 'dart run tool/jelly_sim.dart',
  'battle.json': 'dart run tool/jelly_sim.dart (리그·시즌 보상이 젤리 수입이다)',
  'dex.json': 'dart run tool/balance_sim.dart (도감 영구 보너스는 §7 기준 밖)',
  'species.json': 'flutter test test/data_test.dart (패시브 stat 키 유효성)',
};

String _norm(String p) => p.split(String.fromCharCode(92)).join('/');

void emit(String context) {
  stdout.write(
    jsonEncode({
      'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': context,
      },
    }),
  );
}

void main() {
  stdin.transform(utf8.decoder).join().then((text) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      exit(0);
    }
    final input =
        (payload['tool_input'] as Map?)?.cast<String, dynamic>() ?? {};
    final path = (input['file_path'] ?? '').toString();
    if (path.isEmpty) exit(0);
    final n = _norm(path);

    if (n.endsWith('.dart')) {
      try {
        Process.runSync('dart', ['format', path], runInShell: true);
      } catch (_) {
        // 포맷 실패는 조용히 넘긴다 — 훅이 작업을 세우면 안 된다.
      }
      exit(0);
    }

    if (n.contains('/packages/app/assets/data/') && n.endsWith('.json')) {
      final name = n.split('/').last;
      final sim = _simByData[name];
      final lines = <String>[
        '밸런스 데이터 $name 을(를) 고쳤습니다. CLAUDE.md §6 절차를 지키세요.',
      ];
      if (sim != null) {
        lines.add('필수 검증(packages/core_run 또는 packages/app 안에서): $sim');
      }
      lines.add('젤리 **소비** 금액은 5·10 단위로 떨어져야 합니다(수입에는 반올림 금지).');
      emit(lines.join('\n'));
    }
    exit(0);
  });
}
