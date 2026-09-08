// PreToolUse 훅: 아키텍처 규칙(CLAUDE.md §5)을 편집 **전에** 막는다.
//
//  1. 순수 패키지(core_*)에서 flutter/hive/riverpod/dart:ui import 금지.
//  2. 게임 로직에서 전역 Random() / DateTime.now() 기반 롤 금지(결정론).
//  3. 순수 패키지 안의 밸런스 매직넘버는 막지 않는다 — 오탐이 너무 많다(§6 은 리뷰로).
//
// stdin 으로 훅 JSON 을 받고, 위반이면 stderr 에 이유를 쓰고 exit 2 로 편집을 차단한다.
// 그 외에는 조용히 exit 0.
import 'dart:convert';
import 'dart:io';

const _forbiddenPureImports = <String, String>{
  'package:flutter/': 'flutter',
  'package:flutter_riverpod/': 'flutter_riverpod',
  'package:riverpod/': 'riverpod',
  'package:hive/': 'hive',
  'package:hive_flutter/': 'hive_flutter',
  'dart:ui': 'dart:ui',
};

/// 순수 패키지 = Flutter 를 모르는 패키지. CLAUDE.md §4 의 의존 방향 그림 그대로.
const _purePackages = <String>[
  'core_models',
  'core_battle',
  'core_run',
  'core_gathering',
  'core_save',
];

/// 시드 없는 Random() 을 금지하는 패키지. app 의 UI 는 예외(애니메이션 등).
const _noBareRandomPackages = <String>[
  'core_models',
  'core_battle',
  'core_run',
  'core_gathering',
  'core_save',
  'server',
];

/// DateTime.now() 를 금지하는 패키지 — 시간은 주입된 clock 으로 받는다.
/// core_save 는 세이브 생성 기본값에서, server 는 **자기가 시간의 권위**라서 제외한다.
const _noBareNowPackages = <String>[
  'core_models',
  'core_battle',
  'core_run',
  'core_gathering',
];

/// clock 인터페이스 구현 자체는 DateTime.now() 를 쓸 수밖에 없다.
const _nowExemptFiles = <String>['/core_models/lib/src/clock.dart'];

String _norm(String p) => p.split(String.fromCharCode(92)).join('/');

bool _inPackage(String path, List<String> pkgs) {
  final n = _norm(path);
  for (final p in pkgs) {
    if (n.contains('/packages/$p/lib/') || n.contains('/packages/$p/bin/')) {
      return true;
    }
  }
  return false;
}

bool _isTest(String path) {
  final n = _norm(path);
  return n.contains('/test/') || n.endsWith('_test.dart');
}

/// 편집 도구가 실제로 파일에 **새로 넣는** 텍스트만 모은다.
/// 기존 파일 전체를 검사하면 이미 있던 코드까지 걸려 편집이 영영 막힌다.
List<String> _addedText(String tool, Map<String, dynamic> input) {
  switch (tool) {
    case 'Write':
      return [(input['content'] ?? '').toString()];
    case 'Edit':
      return [(input['new_string'] ?? '').toString()];
    case 'MultiEdit':
      final edits = input['edits'];
      if (edits is List) {
        return edits
            .whereType<Map>()
            .map((e) => (e['new_string'] ?? '').toString())
            .toList();
      }
      return const [];
    case 'NotebookEdit':
      return [(input['new_source'] ?? '').toString()];
    default:
      return const [];
  }
}

void main() {
  final raw = stdin.transform(utf8.decoder).join();
  raw.then((text) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      exit(0); // 훅 입력을 못 읽으면 통과시킨다 — 훅이 작업을 막아선 안 된다.
    }

    final tool = (payload['tool_name'] ?? '').toString();
    final input =
        (payload['tool_input'] as Map?)?.cast<String, dynamic>() ?? {};
    final path = (input['file_path'] ?? '').toString();

    if (path.isEmpty || !path.endsWith('.dart')) exit(0);

    final added = _addedText(tool, input);
    if (added.isEmpty) exit(0);

    final violations = <String>[];

    if (_inPackage(path, _purePackages)) {
      for (final chunk in added) {
        for (final line in const LineSplitter().convert(chunk)) {
          final t = line.trim();
          if (!t.startsWith('import ') && !t.startsWith('export ')) continue;
          for (final entry in _forbiddenPureImports.entries) {
            if (t.contains(entry.key)) {
              violations.add(
                '순수 패키지에 ${entry.value} import — CLAUDE.md §5 위반\n    $t',
              );
            }
          }
        }
      }
    }

    final isTest = _isTest(path);
    final nowExempt = _nowExemptFiles.any((f) => _norm(path).contains(f));
    final checkRandom = !isTest && _inPackage(path, _noBareRandomPackages);
    final checkNow =
        !isTest && !nowExempt && _inPackage(path, _noBareNowPackages);

    if (checkRandom || checkNow) {
      final randomRe = RegExp(r'(?<![\w.])Random\s*\(\s*\)');
      final nowRe = RegExp(r'DateTime\s*\.\s*now\s*\(\s*\)');
      for (final chunk in added) {
        for (final line in const LineSplitter().convert(chunk)) {
          if (line.trimLeft().startsWith('//')) continue;
          if (checkRandom && randomRe.hasMatch(line)) {
            violations.add(
              '시드 없는 전역 Random() — 결정론이 깨진다. 주입된 Random(seed) 를 쓸 것\n'
              '    ${line.trim()}',
            );
          }
          if (checkNow && nowRe.hasMatch(line)) {
            violations.add(
              'DateTime.now() 직접 호출 — 주입된 clock 인터페이스를 쓸 것\n'
              '    ${line.trim()}',
            );
          }
        }
      }
    }

    if (violations.isEmpty) exit(0);

    stderr.writeln('[아키텍처 가드] $path 편집을 막았습니다.');
    for (final v in violations) {
      stderr.writeln('  - $v');
    }
    stderr.writeln(
      '\n의도한 예외라면 사용자에게 먼저 확인받고, '
      'tool/hook_arch_guard.dart 의 예외 목록을 고치세요.',
    );
    exit(2);
  });
}
