// 표시용 포맷 헬퍼 (로케일 독립적인 수치 포맷).

/// Duration → "2h 30m" / "45m" 형태.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Duration → "m:ss" (1시간 이상은 "h:mm:ss"). 남은 타이머(카운트다운) 표시용.
String formatClock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// 남은 시간 → **두 단위까지만** 축약(`11d12h` · `1h22m` · `22m23s` · `12s`).
///
/// ⚠️ `formatClock` 을 HUD 에 쓰면 안 된다. 버프 시간이 길어지면
/// `43193:14` 같은 문자열이 되어 옆 칸(젤리·재화·전투력)을 밀어낸다
/// (2026-09-01 실기 지적). 여기서는 **길이가 자라지 않는 표기**가 필요하다.
///
/// 두 단위인 이유: `11d`만 쓰면 하루 안쪽에서 정보가 사라지고, 세 단위를 쓰면
/// 다시 길어진다.
String formatShortDuration(Duration d) {
  final s = d.inSeconds <= 0 ? 0 : d.inSeconds;
  final days = s ~/ 86400;
  if (days > 0) return '${days}d${(s % 86400) ~/ 3600}h';
  final h = s ~/ 3600;
  if (h > 0) return '${h}h${(s % 3600) ~/ 60}m';
  final m = s ~/ 60;
  if (m > 0) return '${m}m${s % 60}s';
  return '${s}s';
}

/// 사이즈(mm) → 소수 1자리.
String formatSizeMm(double mm) => mm.toStringAsFixed(1);

/// 천 단위 구분(가격 표기: 5500 → "5,500"). 축약하지 않는다.
String formatThousands(int value) {
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return value < 0 ? '-$b' : b.toString();
}

const _shortSuffixes = ['', 'K', 'M', 'B', 'T'];

/// 단계 [tier] 의 접미사. 5단계(10^15)부터는 `aa ab ac … az ba …` 로 **만들어 쓴다**.
///
/// ⚠️ 예전엔 `ac`(10^21)까지만 표에 적어 두고 거기서 멈췄다. 그 위의 값은
/// 나누기를 멈춘 채 `1000000ac` 처럼 **길이가 계속 자랐다**(2026-09-09 지적).
/// 재화는 9e18 에서 잘리지만 **능력치·전투력은 상한이 없어** 그 위로 간다.
/// 두 글자면 10^2040 까지 덮으므로 double 이 무한대가 되기 전엔 안 떨어진다.
String _suffixFor(int tier) {
  if (tier < _shortSuffixes.length) return _shortSuffixes[tier];
  final n = tier - _shortSuffixes.length;
  final first = n ~/ 26;
  final second = n % 26;
  if (first >= 26) return 'e$tier'; // 여기까지 오면 표기보다 사고를 알리는 게 낫다
  return String.fromCharCode(97 + first) + String.fromCharCode(97 + second);
}

/// 큰 수를 방치형 표기(1.2K, 3.4M, 2.4B…)로. 1000 미만은 그대로.
///
/// **길이가 자라지 않는다** — 어떤 값이 와도 `숫자 3~4자 + 접미사 2자` 안이다.
String formatCompact(num value) {
  if (value.isNaN) return '0';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  if (value < 1000) return value.round().toString();
  var v = value.toDouble();
  var tier = 0;
  while (v >= 1000 && tier < 700) {
    v /= 1000;
    tier++;
  }
  final s = v >= 100
      ? v.toStringAsFixed(0)
      : (v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2));
  return '$s${_suffixFor(tier)}';
}
