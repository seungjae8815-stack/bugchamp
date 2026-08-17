import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

const _honey = Color(0xFFEBA52F);

/// 이벤트 설명 — **첫 진입 때 한 번** 보여준다(이후엔 화면의 ⓘ 로 다시 볼 수 있다).
///
/// 왜 필요한가: 이 대회는 평소 게임과 규칙이 두 군데 다르다 — **스탯이 평준화**되고
/// **출전한 곤충이 하루 쉰다**. 설명 없이 들어오면 "강화한 곤충이 약해졌다",
/// "왜 얘를 못 고르냐"가 된다. 규칙을 먼저 보여주는 게 문의보다 싸다.
class EventIntroScreen extends StatefulWidget {
  const EventIntroScreen({super.key});

  @override
  State<EventIntroScreen> createState() => _EventIntroScreenState();
}

class _EventIntroScreenState extends State<EventIntroScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // 그림 대신 큰 글리프를 쓴다 — 아트가 준비되면 이 자리만 이미지로 바꾸면 된다.
    final pages = <({String glyph, String title, String body})>[
      (glyph: '🌊', title: l.eventIntro1Title, body: l.eventIntro1Body),
      (glyph: '⚖️', title: l.eventIntro2Title, body: l.eventIntro2Body),
      (glyph: '🔀', title: l.eventIntro3Title, body: l.eventIntro3Body),
      (glyph: '🎟️', title: l.eventIntro4Title, body: l.eventIntro4Body),
    ];
    final last = _index >= pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF10190A),
      appBar: AppBar(
        title: Text(l.eventIntroTitle),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: pages.length,
                itemBuilder: (c, i) {
                  final p = pages[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.glyph, style: const TextStyle(fontSize: 72)),
                        const SizedBox(height: 22),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _honey,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? _honey : const Color(0x44FFFFFF),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      Navigator.of(context).pop();
                    } else {
                      _page.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _honey,
                    foregroundColor: const Color(0xFF3A2600),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    last ? l.eventIntroStart : l.actionNext,
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
}
