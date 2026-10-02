import 'package:meta/meta.dart';

/// 요정 등급 5단계(docs/design_fairy.md §1.2).
///
/// 곤충 [Grade] 를 쓰지 않는 이유: 요정에는 **신화**가 있고(합성으로만 닿는다)
/// 곤충의 고급(uncommon)은 없다. 한 enum 에 섞으면 곤충 쪽 분기가 전부 신화를 알아야 한다.
enum FairyGrade {
  common('common'),
  rare('rare'),
  epic('epic'),
  legendary('legendary'),
  mythic('mythic');

  const FairyGrade(this.key);
  final String key;

  /// 한 등급 위. 신화면 null.
  FairyGrade? get next => index + 1 < values.length ? values[index + 1] : null;

  static FairyGrade fromKey(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw ArgumentError('Unknown FairyGrade key: $key'),
  );

  /// 모르는 키면 null — **세이브에서 온 키**용(구버전 앱이 새 등급에서 죽지 않게).
  static FairyGrade? fromKeyOrNull(String? key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// 개체값 상한. 0~1 실수 대신 천분율 정수로 저장한다(세이브 크기 · 비교가 정확하다).
const int kFairyRollMax = 1000;

/// 세이브의 숫자 칸 — 숫자가 아니면(깨진·조작 세이브) [fallback]. 던지지 않는다.
int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

int _roll(Object? v) => _int(v, 0).clamp(0, kFairyRollMax);

/// 요정 한 마리. 종류([kind])는 데이터(fairies.json) id 라 문자열이다 — 스킬과 같다.
///
/// [sub] = **부가 능력치**(능력치 키 하나). 종류마다 정해진 기본 능력치에 하나가 더 붙는다.
/// 같은 불꽃 요정이라도 부가가 치명 피해인지 보스 피해인지가 달라 **수집할 이유**가 된다
/// (design_fairy.md §1.2). 부가가 기본 능력치와 같으면 그 능력치가 두 겹이다.
///
/// [baseRoll]·[subRoll] = **개체값**(0~[kFairyRollMax]). 등급마다 능력치 범위(최소~최대)가 있고
/// 개체값이 그 안의 자리를 정한다 — 같은 등급·같은 종류라도 개체마다 세기가 다르다(뽑는 재미).
@immutable
class Fairy {
  const Fairy({
    required this.id,
    required this.kind,
    required this.grade,
    required this.sub,
    this.baseRoll = 0,
    this.subRoll = 0,
    this.level = 1,
  });

  final String id;
  final String kind;
  final FairyGrade grade;
  final String sub;
  final int baseRoll;
  final int subRoll;
  final int level;

  /// 개체값 두 개의 평균(0~1) — 화면의 "품질" 표시·정렬용.
  double get quality => (baseRoll + subRoll) / (2 * kFairyRollMax);

  Fairy copyWith({int? level}) => Fairy(
    id: id,
    kind: kind,
    grade: grade,
    sub: sub,
    baseRoll: baseRoll,
    subRoll: subRoll,
    level: level ?? this.level,
  );

  /// 세이브 크기 방어선(§2.1) — 키를 한 글자로 둔다.
  Map<String, dynamic> toJson() => {
    'i': id,
    'k': kind,
    'g': grade.key,
    'b': sub,
    'r': baseRoll,
    'u': subRoll,
    'l': level,
  };

  /// 모르는 등급·깨진 칸이면 null(건너뛴다 — 던지지 않는다).
  static Fairy? fromJson(Map<String, dynamic> json) {
    final g = FairyGrade.fromKeyOrNull(json['g'] as String?);
    final id = json['i'];
    final kind = json['k'];
    final sub = json['b'];
    if (g == null || id is! String || kind is! String || sub is! String) {
      return null;
    }
    return Fairy(
      id: id,
      kind: kind,
      grade: g,
      sub: sub,
      baseRoll: _roll(json['r']),
      subRoll: _roll(json['u']),
      level: _int(json['l'], 1).clamp(1, 999),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Fairy &&
      other.id == id &&
      other.kind == kind &&
      other.grade == grade &&
      other.sub == sub &&
      other.baseRoll == baseRoll &&
      other.subRoll == subRoll &&
      other.level == level;

  @override
  int get hashCode =>
      Object.hash(id, kind, grade, sub, baseRoll, subRoll, level);
}

/// 요정 알. **등급은 얻을 때 정해져 있고, 종류·부가 능력치는 둥지에 넣을 때** 정해진다
/// (속성석으로 원하는 부가 능력치의 확률을 올린다 — design_fairy.md §1.5).
@immutable
class FairyEgg {
  const FairyEgg({required this.id, required this.grade});

  final String id;
  final FairyGrade grade;

  Map<String, dynamic> toJson() => {'i': id, 'g': grade.key};

  static FairyEgg? fromJson(Map<String, dynamic> json) {
    final g = FairyGrade.fromKeyOrNull(json['g'] as String?);
    final id = json['i'];
    if (g == null || id is! String) return null;
    return FairyEgg(id: id, grade: g);
  }

  @override
  bool operator ==(Object other) =>
      other is FairyEgg && other.id == id && other.grade == grade;

  @override
  int get hashCode => Object.hash(id, grade);
}

/// 둥지에서 부화 중인 알 한 개(둥지는 1칸).
///
/// 종류·부가 능력치는 **넣는 순간 굴려서 적어 둔다**. 꺼낼 때 굴리면 앱을 껐다 켜며
/// 원하는 결과가 나올 때까지 다시 굴릴 수 있다.
@immutable
class FairyNest {
  const FairyNest({
    required this.eggId,
    required this.grade,
    required this.kind,
    required this.sub,
    required this.baseRoll,
    required this.subRoll,
    required this.endsAt,
  });

  final String eggId;
  final FairyGrade grade;
  final String kind;
  final String sub;
  final int baseRoll;
  final int subRoll;
  final DateTime endsAt;

  FairyNest copyWith({DateTime? endsAt}) => FairyNest(
    eggId: eggId,
    grade: grade,
    kind: kind,
    sub: sub,
    baseRoll: baseRoll,
    subRoll: subRoll,
    endsAt: endsAt ?? this.endsAt,
  );

  Map<String, dynamic> toJson() => {
    'i': eggId,
    'g': grade.key,
    'k': kind,
    'b': sub,
    'r': baseRoll,
    'u': subRoll,
    't': endsAt.toUtc().millisecondsSinceEpoch,
  };

  static FairyNest? fromJson(Map<String, dynamic> json) {
    final g = FairyGrade.fromKeyOrNull(json['g'] as String?);
    final id = json['i'];
    final kind = json['k'];
    final sub = json['b'];
    final t = json['t'];
    if (g == null ||
        id is! String ||
        kind is! String ||
        sub is! String ||
        t is! num) {
      return null;
    }
    return FairyNest(
      eggId: id,
      grade: g,
      kind: kind,
      sub: sub,
      baseRoll: _roll(json['r']),
      subRoll: _roll(json['u']),
      endsAt: DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FairyNest &&
      other.eggId == eggId &&
      other.grade == grade &&
      other.kind == kind &&
      other.sub == sub &&
      other.baseRoll == baseRoll &&
      other.subRoll == subRoll &&
      other.endsAt == endsAt;

  @override
  int get hashCode =>
      Object.hash(eggId, grade, kind, sub, baseRoll, subRoll, endsAt);
}

/// 요정 시스템 전체 상태. 세이브에는 **이 객체 하나**로 들어간다 —
/// 필드를 SaveGame 에 흩어 놓으면 구버전 호환 목록(`_fieldsSinceFeat`)이 여러 줄이 된다.
@immutable
class FairyState {
  const FairyState({
    this.fairies = const [],
    this.eggs = const [],
    this.nest,
    this.companionId,
    this.dust = 0,
    this.stones = const {},
    this.accelerators = const {},
    this.dex = const {},
    this.gachaPity = 0,
    this.seq = 0,
    this.dexClaimed = 0,
    this.exchangeDay = '',
    this.exchangedDust = 0,
  });

  static const FairyState empty = FairyState();

  final List<Fairy> fairies;
  final List<FairyEgg> eggs;

  /// 둥지(1칸). 비었으면 null.
  final FairyNest? nest;

  /// 캐릭터 옆을 나는 동행 요정 id.
  final String? companionId;

  /// 요정 가루 — 레벨업 재료. `MaterialKind` 가 아니다(구버전 앱이 모르는 재료 키에서 죽었다).
  final int dust;

  /// 속성석 — 부가 능력치 키 → 개수.
  final Map<String, int> stones;

  /// 가속기 — 가속기 id → 개수.
  final Map<String, int> accelerators;

  /// 도감 — [dexKey](`종류:등급`)와 [dexSubKey](`종류+부가`) 두 모양의 키.
  final Set<String> dex;

  /// 뽑기 천장 카운터.
  final int gachaPity;

  /// 받은 도감 마일스톤 수(앞에서부터 차례로 받는다 — `FairyConfig.dexMilestones`).
  final int dexClaimed;

  /// 상점 교환소(젤리 → 가루) 하루 상한용 — 마지막으로 교환한 날(기기 날짜 키)과 그날 받은 가루.
  /// 알 뽑기·스킬 소탕과 같은 수준의 기기 날짜다(시계 조작에 약하다 — 서버는 업로드당 상한으로 덮는다).
  final String exchangeDay;
  final int exchangedDust;

  /// 새 요정·알 id 를 만드는 순번. 무작위 id 는 결정론(§5)을 깨고, 시각은 겹친다.
  final int seq;

  /// 요정함 사용 칸 = 요정 + 알 + 둥지 속 알.
  int get boxUsed => fairies.length + eggs.length + (nest == null ? 0 : 1);

  Fairy? fairyById(String id) {
    for (final f in fairies) {
      if (f.id == id) return f;
    }
    return null;
  }

  Fairy? get companion => companionId == null ? null : fairyById(companionId!);

  static String dexKey(String kind, FairyGrade grade) => '$kind:${grade.key}';

  /// 도감의 **부가 능력치 축** — 종류마다 어떤 부가를 모아 봤나.
  static String dexSubKey(String kind, String sub) => '$kind+$sub';

  FairyState copyWith({
    List<Fairy>? fairies,
    List<FairyEgg>? eggs,
    FairyNest? nest,
    bool clearNest = false,
    String? companionId,
    bool clearCompanion = false,
    int? dust,
    Map<String, int>? stones,
    Map<String, int>? accelerators,
    Set<String>? dex,
    int? gachaPity,
    int? seq,
    int? dexClaimed,
    String? exchangeDay,
    int? exchangedDust,
  }) => FairyState(
    fairies: fairies ?? this.fairies,
    eggs: eggs ?? this.eggs,
    nest: clearNest ? null : (nest ?? this.nest),
    companionId: clearCompanion ? null : (companionId ?? this.companionId),
    dust: dust ?? this.dust,
    stones: stones ?? this.stones,
    accelerators: accelerators ?? this.accelerators,
    dex: dex ?? this.dex,
    gachaPity: gachaPity ?? this.gachaPity,
    seq: seq ?? this.seq,
    dexClaimed: dexClaimed ?? this.dexClaimed,
    exchangeDay: exchangeDay ?? this.exchangeDay,
    exchangedDust: exchangedDust ?? this.exchangedDust,
  );

  /// 기본값인 칸은 적지 않는다(세이브 크기).
  Map<String, dynamic> toJson() => {
    if (fairies.isNotEmpty) 'f': [for (final f in fairies) f.toJson()],
    if (eggs.isNotEmpty) 'e': [for (final e in eggs) e.toJson()],
    if (nest != null) 'n': nest!.toJson(),
    if (companionId != null) 'c': companionId,
    if (dust != 0) 'd': dust,
    if (stones.isNotEmpty) 's': stones,
    if (accelerators.isNotEmpty) 'a': accelerators,
    if (dex.isNotEmpty) 'x': dex.toList()..sort(),
    if (gachaPity != 0) 'p': gachaPity,
    if (seq != 0) 'q': seq,
    if (dexClaimed != 0) 'm': dexClaimed,
    if (exchangeDay.isNotEmpty) 'xd': exchangeDay,
    if (exchangedDust != 0) 'xn': exchangedDust,
  };

  /// 깨진 칸은 건너뛴다 — 세이브 파서는 던지지 않는다(구버전·조작 세이브 방어).
  factory FairyState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    List<T> list<T>(Object? raw, T? Function(Map<String, dynamic>) parse) => [
      if (raw is List)
        for (final e in raw)
          if (e is Map) ?parse(Map<String, dynamic>.from(e)),
    ];
    Map<String, int> counts(Object? raw) => {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.key is String && e.value is num && (e.value as num) > 0)
            e.key as String: (e.value as num).toInt(),
    };
    final fairies = list(json['f'], Fairy.fromJson);
    final nestRaw = json['n'];
    final companion = json['c'] is String ? json['c'] as String : null;
    return FairyState(
      fairies: fairies,
      eggs: list(json['e'], FairyEgg.fromJson),
      nest: nestRaw is Map
          ? FairyNest.fromJson(Map<String, dynamic>.from(nestRaw))
          : null,
      // 없는 요정을 가리키는 동행은 버린다.
      companionId: fairies.any((f) => f.id == companion) ? companion : null,
      dust: _int(json['d'], 0).clamp(0, 1 << 52),
      stones: counts(json['s']),
      accelerators: counts(json['a']),
      dex: {
        if (json['x'] is List)
          for (final k in json['x'] as List)
            if (k is String) k,
      },
      gachaPity: _int(json['p'], 0).clamp(0, 1 << 20),
      seq: _int(json['q'], 0).clamp(0, 1 << 52),
      dexClaimed: _int(json['m'], 0).clamp(0, 1000),
      exchangeDay: json['xd'] is String ? json['xd'] as String : '',
      exchangedDust: _int(json['xn'], 0).clamp(0, 1 << 30),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FairyState &&
      _listEq(other.fairies, fairies) &&
      _listEq(other.eggs, eggs) &&
      other.nest == nest &&
      other.companionId == companionId &&
      other.dust == dust &&
      _mapEq(other.stones, stones) &&
      _mapEq(other.accelerators, accelerators) &&
      other.dex.length == dex.length &&
      other.dex.containsAll(dex) &&
      other.gachaPity == gachaPity &&
      other.seq == seq &&
      other.dexClaimed == dexClaimed &&
      other.exchangeDay == exchangeDay &&
      other.exchangedDust == exchangedDust;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(fairies),
    Object.hashAll(eggs),
    nest,
    companionId,
    dust,
    gachaPity,
    seq,
    dexClaimed,
    exchangeDay,
    exchangedDust,
  );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
