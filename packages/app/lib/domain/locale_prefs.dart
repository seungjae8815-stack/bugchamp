import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 표시 언어. `null` = **기기 설정을 따른다**(기본값).
///
/// 기기 언어를 그대로 따르는 게 원칙이지만 선택지가 필요하다:
///  - 기기가 한국어인데 영어로 하고 싶은 사람이 있다(용어를 영어로 익힌 경우).
///  - 지원하지 않는 언어(예: 프랑스어) 기기는 `supportedLocales` 의 첫 항목인
///    **영어**로 떨어진다. 한국어를 원해도 방법이 없었다.
///
/// 기기 단위 설정이다 — 세이브에 넣지 않는다. 표시 언어는 진행도가 아니고,
/// 폰마다 다르게 두고 싶을 수 있다.
/// `main()` 이 앱을 띄우기 **전에** 읽어 넣는 초기값(override).
///
/// 앱이 뜬 뒤에 읽으면 첫 프레임이 기기 언어로 그려졌다가 바뀌어 눈에 띄게
/// 깜빡인다. 그래서 prefs 를 먼저 읽고 이 provider 로 주입한다.
final initialLocaleProvider = Provider<Locale?>((_) => null);

/// 저장된 언어 코드를 읽는다(`main()` 전용).
Future<Locale?> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(LocalePrefs.key);
  return (code == null || code.isEmpty) ? null : Locale(code);
}

class LocalePrefs extends Notifier<Locale?> {
  static const key = 'app_locale_v1';

  @override
  Locale? build() => ref.read(initialLocaleProvider);

  /// [locale] 이 null 이면 기기 설정을 따른다.
  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, locale.languageCode);
    }
  }
}

final localePrefsProvider = NotifierProvider<LocalePrefs, Locale?>(
  LocalePrefs.new,
);
