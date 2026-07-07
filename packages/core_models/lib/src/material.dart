import 'package:meta/meta.dart';

import 'enums.dart';

/// 재료 묶음: 종류 + 수량 (§2.2). 채집 보상·인벤토리·강화 비용 표현에 쓴다.
///
/// 재료의 다국어 이름/아이콘 등 표시 정보는 [MaterialKind] 에 대응하는
/// JSON(assets/data)에서 앱 레이어가 해석한다. 여기서는 순수 수량 데이터만 다룬다.
@immutable
class MaterialStack {
  const MaterialStack({required this.kind, required this.amount});

  final MaterialKind kind;
  final int amount;

  MaterialStack copyWith({MaterialKind? kind, int? amount}) =>
      MaterialStack(kind: kind ?? this.kind, amount: amount ?? this.amount);

  /// 같은 종류끼리 수량 합산.
  MaterialStack operator +(MaterialStack other) {
    assert(other.kind == kind, 'cannot add different MaterialKind');
    return MaterialStack(kind: kind, amount: amount + other.amount);
  }

  factory MaterialStack.fromJson(Map<String, dynamic> json) => MaterialStack(
    kind: MaterialKind.fromKey(json['kind'] as String),
    amount: (json['amount'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {'kind': kind.key, 'amount': amount};

  @override
  bool operator ==(Object other) =>
      other is MaterialStack && other.kind == kind && other.amount == amount;

  @override
  int get hashCode => Object.hash(kind, amount);

  @override
  String toString() => 'MaterialStack(${kind.key} x$amount)';
}
