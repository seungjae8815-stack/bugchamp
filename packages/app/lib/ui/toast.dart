import 'dart:async';

import 'package:flutter/material.dart';

/// 화면 **가운데**에 잠깐 떠 있다 사라지는 안내.
///
/// SnackBar 를 쓰지 않는 이유: 하단에 뜨면 탭바·부화기 버튼처럼 손가락이 있는
/// 자리에 겹쳐 잘 안 보인다. 게임 화면은 시선이 가운데 있으므로 거기에 띄운다.
///
/// 같은 시점에 여러 번 불려도 **마지막 하나만** 남는다(겹쳐 쌓이지 않는다).
OverlayEntry? _current;
Timer? _timer;

void showCenterToast(BuildContext context, String text) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || text.isEmpty) return;

  _timer?.cancel();
  _current?.remove();
  _current = null;

  final entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xD9000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  _current = entry;
  _timer = Timer(const Duration(milliseconds: 1600), () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}
