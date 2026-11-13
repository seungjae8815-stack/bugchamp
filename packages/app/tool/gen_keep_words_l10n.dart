// 한국어 번역 문구를 낱말 단위로만 줄바꿈하게 감싸는 클래스를 만든다(2026-11-12).
//
//   cd packages/app ; flutter gen-l10n ; dart run tool/gen_keep_words_l10n.dart
//
// `AppLocalizationsKo` 를 물려받아 **줄이 넘어갈 만한 문구만**(한글 [_minLen]자 이상 또는 자리표시자가 있는 문구)
// `keepWords` 를 거치게 재정의해 `lib/ui/keep_words_l10n.g.dart` 에 쓴다. 짧은 문구(버튼·제목)는 물려받은 그대로다 —
// 2,516개를 모두 감쌌더니 앱 코드가 ABI 마다 3.0MB 커졌다(arm64 17.1 → 20.1MB).
// ARB 에 문구를 더하고 이 도구를 안 돌리면 그 문구만 예전처럼 글자 단위로 끊긴다(깨지지는 않는다).
import 'dart:convert';
import 'dart:io';

const _minLen = 14;

void main() {
  final src = File('lib/l10n/app_localizations.dart').readAsStringSync();
  final start = src.indexOf('abstract class AppLocalizations');
  final end = src.indexOf('\nclass _AppLocalizationsDelegate');
  if (start < 0 || end < 0) {
    stderr.writeln('app_localizations.dart 모양이 예상과 다름');
    exit(1);
  }
  final ko =
      jsonDecode(File('lib/l10n/app_ko.arb').readAsStringSync())
          as Map<String, dynamic>;
  final hangul = RegExp(r'[가-힣]');
  bool long(String key) {
    final v = ko[key];
    if (v is! String || !hangul.hasMatch(v)) return false;
    return v.runes.length >= _minLen || v.contains('{');
  }

  final body = src.substring(start, end);
  // `String get x;` 또는 `String x(int a, String b);`(여러 줄일 수 있다).
  final re = RegExp(
    r'^\s*String\s+(get\s+)?(\w+)\s*(\(([^)]*)\))?\s*;',
    multiLine: true,
  );
  final out = StringBuffer()
    ..writeln('// 자동 생성 — tool/gen_keep_words_l10n.dart. 손으로 고치지 않는다.')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln("import '../l10n/app_localizations_ko.dart';")
    ..writeln("import 'format.dart';")
    ..writeln()
    ..writeln('/// 긴 한국어 문구를 [keepWords] 로 감싼 번역(`KeepWordsDelegate`).')
    ..writeln('class KeepWordsKo extends AppLocalizationsKo {');
  var n = 0, all = 0;
  for (final m in re.allMatches(body)) {
    all++;
    final name = m.group(2)!;
    if (!long(name)) continue;
    out.writeln();
    out.writeln('  @override');
    if (m.group(1) != null) {
      out.writeln('  String get $name => keepWords(super.$name);');
    } else {
      final params = m.group(4)!.trim().replaceAll(RegExp(r',\s*$'), '');
      final args = params.isEmpty
          ? ''
          : params
                .split(',')
                .map((p) => p.trim().split(RegExp(r'\s+')).last)
                .join(', ');
      out.writeln('  String $name($params) => keepWords(super.$name($args));');
    }
    n++;
  }
  out.writeln('}');
  File('lib/ui/keep_words_l10n.g.dart').writeAsStringSync(out.toString());
  // CI 포맷 검사(--set-exit-if-changed)에 걸리지 않게 바로 맞춘다.
  Process.runSync('dart', [
    'format',
    'lib/ui/keep_words_l10n.g.dart',
  ], runInShell: true);
  stdout.writeln('문구 $all개 중 $n개 감쌈 → lib/ui/keep_words_l10n.g.dart');
}
