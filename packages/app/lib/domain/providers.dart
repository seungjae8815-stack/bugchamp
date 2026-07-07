import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// 하단 네비게이션 선택 탭 (0=홈, 1=채집, 2=보관함).
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
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
