import 'dart:convert';
import 'dart:io';

import 'package:app/ui/skins.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// 결투 상대 곤충의 외형 — 서버가 실어 준 이색·스킨 키를 내 곤충([bugView])과
/// 같은 규칙으로 그리는지(이색이 스킨보다 우선, 이색은 색 처리만).
void main() {
  final cfg = IapConfig.fromJson(
    jsonDecode(File('assets/data/iap.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  // 전용 스킨 그림이 있는 종(있으면) — hasArt 가 iap.json 을 따르는지 본다.
  final artSkin = cfg.skins.where((s) => s.artSpecies.isNotEmpty).firstOrNull;

  test('이색이면 스킨이 있어도 이색으로 그린다(전용 그림 없음)', () {
    final v = foeBugView(cfg, 'beetle', variant: 'rainbow', skin: 'gold');
    expect(v, const SkinView('rainbow'));
  });

  test('이색이 아니면 스킨 — 전용 그림 유무는 iap.json 이 정한다', () {
    final sp = artSkin?.artSpecies.first ?? 'beetle';
    final effect = artSkin?.effect ?? 'gold';
    final v = foeBugView(cfg, sp, skin: effect);
    expect(v, SkinView(effect, hasArt: cfg.skinHasArt(effect, sp)));
  });

  test('둘 다 없으면(구서버·야생) 기본 외형', () {
    expect(foeBugView(cfg, 'beetle'), isNull);
    expect(foeBugView(null, 'beetle', variant: 'none'), isNull);
  });

  test('모르는 이색 키는 이색이 아니다 — 스킨으로 떨어진다', () {
    expect(
      foeBugView(null, 'beetle', variant: 'cosmic', skin: 'gold'),
      const SkinView('gold'),
    );
    expect(isVariantKey('cosmic'), isFalse);
    expect(isVariantKey('albino'), isTrue);
    expect(isVariantKey(null), isFalse);
  });
}
