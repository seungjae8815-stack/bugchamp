import 'package:flutter/material.dart';

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
class EventIntroScreen extends StatelessWidget {
  const EventIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                child: _flyer(context, l),
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

  Widget _flyer(BuildContext context, AppLocalizations l) => Container(
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: [
              Text(
                l.eventFlyerPrize,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.eventFlyerPrizeNote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD08A),
                  fontSize: 11.5,
                ),
              ),
            ],
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
