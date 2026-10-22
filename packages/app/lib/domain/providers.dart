import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/game_data.dart';
import '../data/save_repository.dart';
import 'gather_service.dart';

/// 정적 게임 데이터(JSON 테이블). 앱 시작 시 1회 로드.
final gameDataProvider = FutureProvider<GameData>((ref) async {
  return GameData.loadFromBundle();
});

/// 세이브 저장소. main() 에서 Hive 박스를 연 뒤 override 로 주입한다.
final saveRepositoryProvider = Provider<SaveRepository>((ref) {
  throw UnimplementedError('main() 에서 saveRepositoryProvider 를 override 하세요');
});

/// 시간 공급. 기본 로컬, 추후 서버시간 보정으로 교체.
final clockProvider = Provider<Clock>((ref) => const LocalClock());

/// 하단 네비게이션 선택 탭 — 번호는 IndexedStack 순서([kNavPages]).
///
/// 고르는 탭이 지금 보이지 않는 쪽에 있으면 그 쪽으로 탭 줄을 바꾼다(2026-10-22 하단 탭 2쪽) —
/// 2쪽에서 "젤리 사러 가기"로 상점에 가면 탭 줄도 1쪽이 된다. 홈은 양쪽에 있어 쪽을 바꾸지 않는다.
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) {
    state = index;
    if (index == 0) return;
    final page = navPageOf(index);
    if (ref.read(navPageProvider) != page) {
      ref.read(navPageProvider.notifier).set(page);
    }
  }
}

/// 하단 탭 번호(IndexedStack 순서). 1쪽 = 홈·채집함·결투·길드·상점 · 2쪽 = 홈·장비·스킬·요정·연구소.
const int kStorageTabIndex = 1;
const int kBattleTabIndex = 2;

/// 하단 메뉴의 길드 탭 번호. 길드 화면은 이 탭이 골라졌을 때만 서버를 부른다.
const int kGuildTabIndex = 3;

/// 하단 메뉴의 상점 탭 번호.
const int kShopTabIndex = 4;

/// 2쪽 — 옛 캐릭터 탭의 세 패널(능력치·장비 / 스킬 / 요정)이 각각 탭이 됐다 + 연구소.
const int kEquipTabIndex = 5;
const int kSkillTabIndex = 6;
const int kFairyTabIndex = 7;
const int kResearchTabIndex = 8;

/// 쪽마다 보이는 탭(왼쪽부터). 맨 끝엔 ⇄ 전환 버튼이 붙는다.
const List<List<int>> kNavPages = [
  [0, kStorageTabIndex, kBattleTabIndex, kGuildTabIndex, kShopTabIndex],
  [0, kEquipTabIndex, kSkillTabIndex, kFairyTabIndex, kResearchTabIndex],
];

/// 탭 번호가 들어 있는 쪽. 홈(양쪽)은 0.
int navPageOf(int index) => kNavPages[1].contains(index) && index != 0 ? 1 : 0;

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);

const _kNavPageKey = 'nav.page';

/// 하단 탭 줄이 보여 주는 쪽(0/1). 마지막으로 본 쪽을 기기에 기억한다(`nav.page`).
class NavPageNotifier extends Notifier<int> {
  /// 읽기가 끝나기 전에 유저가 쪽을 바꿨으면 늦게 온 저장값으로 덮지 않는다.
  bool _touched = false;

  @override
  int build() {
    SharedPreferences.getInstance()
        .then((p) {
          final v = p.getInt(_kNavPageKey);
          if (!_touched && v != null && v >= 0 && v < kNavPages.length) {
            state = v;
          }
        })
        .catchError((_) {});
    return 0;
  }

  void set(int page) {
    _touched = true;
    if (page < 0 || page >= kNavPages.length) return;
    state = page;
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_kNavPageKey, page))
        .catchError((_) => false);
  }

  void toggle() => set(1 - state);
}

final navPageProvider = NotifierProvider<NavPageNotifier, int>(
  NavPageNotifier.new,
);

const _uuid = Uuid();

/// 채집 서비스 (gameData 로드 완료 후 사용 가능).
final gatherServiceProvider = Provider<GatherService>((ref) {
  final data = ref.watch(gameDataProvider).requireValue;
  return GatherService(
    data: data,
    clock: ref.watch(clockProvider),
    idFactory: _uuid.v4,
  );
});
