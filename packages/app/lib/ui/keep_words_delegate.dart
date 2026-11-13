import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'keep_words_l10n.g.dart';

/// 한국어 번역 문구가 **낱말 가운데서 끊기지 않게** 하는 번역 대리자(2026-11-12 사장님 지적 — 앱 전체).
/// `AppLocalizations.delegate` 자리에 넣는다. 한국어만 바꾸고(일본어는 글자마다 끊는 것이 정상, 영어는 원래 낱말 단위)
/// 긴 문구만 감싼다(`KeepWordsKo` — tool/gen_keep_words_l10n.dart 로 만든다).
class KeepWordsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const KeepWordsDelegate();

  /// `MaterialApp.localizationsDelegates` 에 그대로 넣는 목록.
  static final List<LocalizationsDelegate<dynamic>> delegates = [
    const KeepWordsDelegate(),
    for (final d in AppLocalizations.localizationsDelegates)
      if (d != AppLocalizations.delegate) d,
  ];

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      locale.languageCode == 'ko'
      ? KeepWordsKo()
      : AppLocalizations.delegate.load(locale);

  @override
  bool shouldReload(KeepWordsDelegate old) => false;
}
