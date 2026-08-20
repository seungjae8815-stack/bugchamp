import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/art.dart';

const _honey = Color(0xFFEBA52F);
const _paper = Color(0xFF1B2A11);

/// 이벤트 **전단지** — 한 장으로 대회를 설명한다.
///
/// 페이지를 넘기는 방식이었는데, 대회 안내는 **한눈에 훑고 싶은 정보**다
/// (상품이 뭔지, 어떻게 참가하는지, 뭘 조심해야 하는지). 넘겨야 보이면
/// 마지막 장의 주의사항을 아무도 안 읽는다 — 이 대회는 규칙이 평소와 두 군데
/// 다르므로(스탯 평준화·출전 피로) 그게 곧 문의가 된다.
///
/// 배경 그림(`ui/event/flyer_bg.webp`)이 들어오면 자동으로 깔린다.
class EventIntroScreen extends ConsumerWidget {
  const EventIntroScreen({super.key});

  /// 'M월 d일' — 회차 기간 표시용. 연도는 넣지 않는다(같은 해 안에서 도는 대회다).
  static String _kstDate(AppLocalizations l, DateTime utc, String locale) {
    final k = utc.toUtc().add(const Duration(hours: 9));
    return switch (locale) {
      'ko' => '${k.month}월 ${k.day}일',
      'ja' => '${k.month}月${k.day}日',
      _ => '${k.month}/${k.day}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C1408),
      appBar: AppBar(
        title: Text(l.eventIntroTitle),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: _flyer(
                  context,
                  l,
                  ref.watch(gameDataProvider).asData?.value.eventConfig,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _honey,
                    foregroundColor: const Color(0xFF3A2600),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    l.eventIntroStart,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flyer(
    BuildContext context,
    AppLocalizations l,
    EventConfig? cfg,
  ) => Container(
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _honey.withValues(alpha: 0.55), width: 1.6),
      boxShadow: const [
        BoxShadow(color: Color(0x66000000), blurRadius: 16, spreadRadius: -4),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 머리: 대회 이름 + 한 줄 카피 ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_honey.withValues(alpha: 0.22), Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              gameImage(
                'assets/images/ui/event/flyer_bg.webp',
                width: 220,
                height: 110,
                fallback: const Text('🏆', style: TextStyle(fontSize: 54)),
              ),
              const SizedBox(height: 10),
              Text(
                l.eventTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              if (cfg?.startsAt != null && cfg?.endsAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _honey.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _honey.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    // 종료는 **자정 직전**까지다. endsAt 은 다음 날 00:00 이므로
                    // 하루를 빼서 보여줘야 "30일까지"로 읽힌다.
                    l.eventFlyerPeriod(
                      _kstDate(
                        l,
                        cfg!.startsAt!,
                        Localizations.localeOf(context).languageCode,
                      ),
                      _kstDate(
                        l,
                        cfg.endsAt!.subtract(const Duration(minutes: 1)),
                        Localizations.localeOf(context).languageCode,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                l.eventFlyerHeadline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xDDFFFFFF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        _rule(),
        // ── 상품 ──
        //
        // **전단지에서 제일 큰 글씨여야 한다.** 사람들이 이 대회를 도는 이유가
        // 실물 곤충이라, 다른 안내와 같은 톤이면 "그래서 뭘 주는데"가 안 남는다
        // (실기 지적: "상품이 명확하게 잘 안 보여").
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _honey.withValues(alpha: 0.26),
                  _honey.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _honey, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: _honey.withValues(alpha: 0.28),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              children: [
                // 상품이라는 걸 글자 없이도 알리는 머리표.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _honey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 13,
                        color: Color(0xFF3A2600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.eventFlyerPrizeTag,
                        style: const TextStyle(
                          color: Color(0xFF3A2600),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.eventFlyerPrize,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    height: 1.3,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.eventFlyerPrizeNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD08A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        _rule(),
        _section(l.eventFlyerHow, [
          (n: '1', text: l.eventFlyerHow1),
          (n: '2', text: l.eventFlyerHow2),
          (n: '3', text: l.eventFlyerHow3),
        ]),
        _rule(),
        // ── 주의: 평소와 다른 규칙 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.eventFlyerRules,
                style: const TextStyle(
                  color: _honey,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 8),
              for (final t in [
                l.eventFlyerRule1,
                l.eventFlyerRule2,
                l.eventFlyerRule3,
                l.eventFlyerRule4,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '· ',
                        style: TextStyle(color: _honey, fontSize: 13),
                      ),
                      Expanded(
                        child: Text(
                          // ARB 의 ** 강조는 그대로 두면 별표가 보인다 — 걷어낸다.
                          t.replaceAll('**', ''),
                          style: const TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22FF8A65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x55FF8A65)),
                ),
                child: Text(
                  l.eventFlyerLogin,
                  style: const TextStyle(
                    color: Color(0xFFFFB0A0),
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // ── 공식 규정·고지 ────────────────────────────────
              // 실물 경품 이벤트는 심사 요건이다(Apple 5.3 / Play 콘테스트
              // 정책): 주최자 명시 + "스토어 무관" 고지 + 규정. 빠지면
              // 심사에서 걸리고, 있으면 분쟁 때 운영팀을 지켜준다.
              const SizedBox(height: 12),
              Text(
                l.eventLegalTitle,
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 6),
              for (final t in [
                l.eventLegalHost,
                l.eventLegalStores,
                l.eventLegalPrize,
                l.eventLegalFair,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '· ',
                        style: TextStyle(
                          color: Color(0x77FFFFFF),
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 10.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _rule() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: const Color(0x33EBA52F),
  );

  Widget _section(String title, List<({String n, String text})> items) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _honey,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _honey.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _honey.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Text(
                        it.n,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          it.text,
                          style: const TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
