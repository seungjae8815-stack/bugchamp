import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import '../../ui/art.dart';
import '../../ui/skins.dart';

/// 개발자용 — **스킨이 걸린 종을 기본/스킨 나란히** 본다.
///
/// 스킨은 IAP 로만 얻는데 사이드로드 빌드에서는 결제가 안 돼서, 실기에서
/// 확인할 길이 없었다. 색·빛이 종마다 어떻게 나오는지는 반드시 실기로 봐야
/// 한다(2026-08-18 알비노가 회색이던 사고, 2026-08-19 누끼 구멍).
///
/// 세 자세를 한 줄에 늘어놓으므로 **어느 프레임이 아직 폴백인지**(= 파일이
/// 없거나 이름이 틀렸는지)가 한눈에 보인다. 칸을 누르면 크게 본다.
class SkinGalleryScreen extends ConsumerStatefulWidget {
  const SkinGalleryScreen({super.key});

  @override
  ConsumerState<SkinGalleryScreen> createState() => _SkinGalleryScreenState();
}

class _SkinGalleryScreenState extends ConsumerState<SkinGalleryScreen> {
  /// 배경. 아레나(어두움)와 채집함(밝음)에서 다르게 보이므로 둘 다 본다.
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gameDataProvider).value;
    final iap = data?.iapConfig;
    if (data == null || iap == null) return const Scaffold();

    // 스킨이 걸리는 종 = speciesPrefix 가 있는 스킨의 대상 종.
    final groups = <(SkinDef, List<Species>)>[];
    for (final sk in iap.skins) {
      final p = sk.speciesPrefix;
      if (p == null) continue;
      final list = data.allSpecies.where((s) => s.id.startsWith(p)).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      if (list.isNotEmpty) groups.add((sk, list));
    }

    final bg = _dark ? const Color(0xFF161A20) : const Color(0xFFE8E2D2);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('🛠 스킨 그림 확인'),
        actions: [
          IconButton(
            tooltip: '배경 밝기',
            onPressed: () => setState(() => _dark = !_dark),
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          for (final (sk, list) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
              child: Text(
                '${sk.id}  ·  ${sk.effect}  ·  전용그림 ${sk.artSpecies.length}종',
                style: TextStyle(
                  color: _dark
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFF7A5B12),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            for (final sp in list) _speciesRow(sp, sk),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _speciesRow(Species sp, SkinDef sk) {
    final hasArt = sk.artSpecies.contains(sp.id);
    final view = SkinView(sk.effect, hasArt: hasArt);
    final label = _dark ? Colors.white : const Color(0xFF2A2A2A);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sp.id,
                style: TextStyle(
                  color: label,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 6),
              // 전용 그림이 없으면 색 필터로 떨어진다 — 그 사실이 보여야 한다.
              Text(
                hasArt ? '전용그림' : '색필터 폴백',
                style: TextStyle(
                  color: hasArt
                      ? const Color(0xFF6FC96F)
                      : const Color(0xFFEF8A5A),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final pose in BugPose.values) ...[
                _cell(sp, pose, null),
                const SizedBox(width: 4),
              ],
              Container(
                width: 1,
                height: 74,
                color: const Color(0x33888888),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              for (final pose in BugPose.values) ...[
                _cell(sp, pose, view),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(Species sp, BugPose pose, SkinView? skin) => Expanded(
    child: GestureDetector(
      onTap: () => _zoom(sp, pose, skin),
      child: SizedBox(
        height: 74,
        child: bugPoseImage(
          sp.id,
          pose,
          size: 74,
          fallback: const Icon(Icons.bug_report, size: 40),
          skin: skin,
        ),
      ),
    ),
  );

  /// 크게 보기. 자세를 좌우로 넘겨 세 장을 비교한다.
  void _zoom(Species sp, BugPose pose, SkinView? skin) {
    var p = pose;
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xE6000000),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sp.id} · ${p.name}${skin == null ? '' : ' · ${skin.effect}'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              // 확대는 화면 폭에 맞춘다 — 누끼 구멍은 크게 봐야 보인다.
              LayoutBuilder(
                builder: (_, c) => bugPoseImage(
                  sp.id,
                  p,
                  size: c.maxWidth,
                  fallback: const Icon(Icons.bug_report, size: 80),
                  skin: skin,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final x in BugPose.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton(
                        onPressed: () => setLocal(() => p = x),
                        style: FilledButton.styleFrom(
                          backgroundColor: x == p
                              ? const Color(0xFF2E6DA4)
                              : const Color(0x33FFFFFF),
                        ),
                        child: Text(x.name),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
