import 'package:meta/meta.dart';

/// 게임 데이터(종 이름 등)의 다국어 문자열. UI 문자열은 ARB 를 쓰고,
/// 이 타입은 **JSON 데이터에 담긴 다국어 필드**({ "ko":..., "en":..., "ja":... })에 쓴다.
@immutable
class LocalizedText {
  const LocalizedText({required this.ko, required this.en, required this.ja});

  final String ko;
  final String en;
  final String ja;

  /// 로케일 코드('ko'/'en'/'ja')로 해석. 미지원 코드는 en 으로 폴백.
  String resolve(String localeCode) => switch (localeCode) {
    'ko' => ko,
    'ja' => ja,
    _ => en,
  };

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText(
    ko: json['ko'] as String,
    en: json['en'] as String,
    ja: json['ja'] as String,
  );

  Map<String, dynamic> toJson() => {'ko': ko, 'en': en, 'ja': ja};

  @override
  bool operator ==(Object other) =>
      other is LocalizedText &&
      other.ko == ko &&
      other.en == en &&
      other.ja == ja;

  @override
  int get hashCode => Object.hash(ko, en, ja);

  @override
  String toString() => 'LocalizedText(ko: $ko, en: $en, ja: $ja)';
}
