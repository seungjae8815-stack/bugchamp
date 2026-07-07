// 표시용 포맷 헬퍼 (로케일 독립적인 수치 포맷).

/// Duration → "2h 30m" / "45m" 형태.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// 사이즈(mm) → 소수 1자리.
String formatSizeMm(double mm) => mm.toStringAsFixed(1);

const _suffixes = ['', 'K', 'M', 'B', 'T', 'aa', 'ab', 'ac'];

/// 큰 수를 방치형 표기(1.2K, 3.4M, 2.4B…)로. 1000 미만은 그대로.
String formatCompact(num value) {
  if (value < 1000) return value.round().toString();
  var v = value.toDouble();
  var tier = 0;
  while (v >= 1000 && tier < _suffixes.length - 1) {
    v /= 1000;
    tier++;
  }
  final s = v >= 100
      ? v.toStringAsFixed(0)
      : (v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2));
  return '$s${_suffixes[tier]}';
}
