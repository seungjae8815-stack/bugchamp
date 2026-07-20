/// Bug Champ 세이브 모델·마이그레이션 (순수 Dart).
///
/// 앱(Flutter)과 권위 서버가 **같은 모델·같은 마이그레이션**을 쓰기 위해
/// app 레이어에서 분리했다. 두 벌이 되면 서버가 저장한 세이브를 앱이 못 읽거나
/// 그 반대가 생긴다.
///
/// Flutter / Hive / Riverpod 에 의존하지 않는다 — 영속화는 상위 레이어의 일.
library;

export 'src/gift_mail.dart';
export 'src/save_game.dart';
export 'src/save_migrations.dart';
