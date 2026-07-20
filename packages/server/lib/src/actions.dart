import 'dart:math';

import 'package:core_battle/core_battle.dart';
import 'package:core_models/core_models.dart';
import 'package:core_run/core_run.dart';
import 'package:core_save/core_save.dart';
import 'package:uuid/uuid.dart';

/// 액션 처리 결과.
class ActionResult {
  const ActionResult.ok(this.save, {this.extra = const {}})
    : error = null,
      status = 200;
  const ActionResult.fail(this.error, {this.status = 400})
    : save = null,
      extra = const {};

  final SaveGame? save;
  final String? error;
  final int status;
  final Map<String, dynamic> extra;

  bool get isOk => save != null;
}

/// 서버 권위 액션들.
///
/// **여기 있는 함수만이 세이브를 바꾼다.** 클라이언트는 "무엇을 하고 싶다"만
/// 보내고, 얼마를 벌었는지·이겼는지는 전부 서버가 정한다.
///
/// 앱과 **같은 `core_*` 코드**로 계산하므로 결과가 어긋나지 않는다.
class GameActions {
  GameActions({required this.config, required this.now, this.rngFactory});

  final GameConfigLike config;

  /// 서버 시각(주입 가능 — 테스트 결정론).
  final DateTime Function() now;

  /// 드롭 롤용 난수. **서버가 소유한다** — 클라이언트가 굴리면 5성 전설을
  /// 마음대로 만들 수 있다(골드 조작보다 훨씬 치명적이다).
  /// 테스트에서 결정론을 위해 주입할 수 있다.
  final Random Function()? rngFactory;

  /// 한 번의 sync 에서 굴릴 드롭 롤 상한.
  /// 오래 비운 뒤 접속하면 처치 수가 수천이 될 수 있어 계산량을 묶는다.
  static const maxRollsPerSync = 300;

  static const _uuid = Uuid();

  /// 구매 지급. **영수증 검증은 호출 전에 끝나 있어야 한다.**
  ///
  /// [purchaseId] 로 중복 지급을 막는다 — 스토어는 같은 구매를 여러 번
  /// 전달할 수 있고, 클라이언트가 재요청할 수도 있다.
  ActionResult grantPurchase(
    SaveGame save, {
    required String productId,
    required String purchaseId,
  }) {
    final product = config.iap.byId(productId);
    if (product == null) {
      return const ActionResult.fail('unknown_product');
    }
    if (save.redeemedPurchases.contains(purchaseId)) {
      // 이미 지급됨 — 오류가 아니라 현재 상태를 그대로 돌려준다(멱등).
      return ActionResult.ok(save, extra: {'alreadyGranted': true});
    }
    if (product.type == IapType.starter && save.starterBought) {
      return const ActionResult.fail('already_owned');
    }

    final t = now().toUtc();
    final g = product.grant;
    final mats = Map<MaterialKind, int>.from(save.materials);
    void add(MaterialKind k, int n) {
      if (n > 0) mats[k] = (mats[k] ?? 0) + n;
    }

    add(MaterialKind.jelly, g.jelly);
    add(MaterialKind.chitin, g.chitin);
    add(MaterialKind.mineral, g.mineral);
    add(MaterialKind.sap, g.sap);

    DateTime? passExpiry = save.passExpiresAt;
    if (product.type == IapType.pass) {
      final base = (passExpiry != null && passExpiry.isAfter(t))
          ? passExpiry
          : t;
      passExpiry = base.add(Duration(days: config.iap.passDurationDays));
    }

    return ActionResult.ok(
      save.copyWith(
        gold: save.gold + g.gold,
        materials: mats,
        incubatorCapacity: save.incubatorCapacity + g.incubatorSlots,
        adsRemoved: save.adsRemoved || product.type == IapType.removeAds,
        starterBought: save.starterBought || product.type == IapType.starter,
        ownedSkins: product.skinId == null
            ? save.ownedSkins
            : {...save.ownedSkins, product.skinId!},
        passExpiresAt: passExpiry,
        redeemedPurchases: {...save.redeemedPurchases, purchaseId},
      ),
    );
  }

  /// PvP 전투를 **서버에서 시뮬레이션**하고 결과를 확정한다.
  ///
  /// 클라이언트는 "누구와 싸우겠다"만 보낸다. 승패·보상·트로피는 전부
  /// 여기서 정해진다 — 앱과 **같은 `core_battle` 코드**를 쓰므로 결과가
  /// 어긋나지 않는다(그래서 서버를 Dart 로 만들었다).
  ///
  /// [myTeamBugIds] 는 편성 순서다. 실제 스탯은 **서버 세이브의 개체**에서
  /// 가져온다 — 클라이언트가 보낸 스탯을 쓰면 조작이 가능해진다.
  ActionResult runBattle(
    SaveGame save, {
    required List<String> myTeamBugIds,
    required List<BattleBug> foeTeam,
    required Element location,
    required int seed,
    required double rewardMult,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
  }) {
    final t = now().toUtc();

    // 1) 편성 검증 — 내 세이브에 실제로 있는, 부상 아닌 성충만.
    final byId = {for (final b in save.bugs) b.id: b};
    final mine = <BattleBug>[];
    final mineIds = <String>[];
    for (final id in myTeamBugIds) {
      final bug = byId[id];
      if (bug == null) return const ActionResult.fail('bug_not_owned');
      if (save.isInjured(bug.id, t))
        return const ActionResult.fail('bug_injured');
      final species = speciesById[bug.speciesId];
      if (species == null) return const ActionResult.fail('unknown_species');
      final stage = effectiveStage(bug.stage, bug.stageSince, t, petConfig);
      if (stage != LifeStage.adult) return const ActionResult.fail('not_adult');

      double per(BugPart p, double d) => enhance?.spec(p).effectPerLevel ?? d;
      mine.add(
        buildBattleBug(
          bug: bug,
          species: species,
          locale: 'ko',
          hornJawPerLevel: per(BugPart.hornJaw, 0.04),
          cuticlePerLevel: per(BugPart.cuticle, 0.04),
          wingPerLevel: per(BugPart.wing, 0.03),
          buildPerLevel: per(BugPart.build, 0.05),
        ),
      );
      mineIds.add(bug.id);
    }
    if (mine.isEmpty) return const ActionResult.fail('empty_team');
    if (foeTeam.isEmpty) return const ActionResult.fail('empty_foe');

    // 2) 시뮬레이션 — 시드는 서버가 정한다(클라가 유리한 시드를 고르지 못하게).
    final cfg = config.battle;
    final result = simulate(
      seed,
      mine,
      foeTeam,
      location: location,
      locationBonus: cfg.locationAffinityBonus,
    );

    // 3) 보상 — 앱과 **같은 규칙**(pvpReward)으로 계산한다.
    final rw = pvpReward(
      won: result.outcome == BattleOutcome.teamA,
      draw: result.outcome == BattleOutcome.draw,
      trophies: save.pvpTrophies,
      cfg: cfg,
      rewardMult: rewardMult,
    );

    // 4) KO 된 내 곤충 부상 처리 — 판정도 앱과 같은 함수를 쓴다.
    final injured = Map<String, DateTime>.from(save.injured);
    for (final koedId in koedTeamAIds(mine, result.events)) {
      final bug = byId[koedId];
      if (bug == null) continue;
      final species = speciesById[bug.speciesId];
      if (species == null) continue;
      final until = t.add(
        Duration(seconds: petConfig.injuryDuration(species.grade)),
      );
      final prev = injured[koedId];
      injured[koedId] = (prev != null && prev.isAfter(until)) ? prev : until;
    }

    final newTrophies = (save.pvpTrophies + rw.trophyDelta).clamp(0, 1 << 30);
    return ActionResult.ok(
      save.copyWith(
        gold: save.gold + rw.gold,
        pvpTrophies: newTrophies,
        seasonPeakTrophies: newTrophies > save.seasonPeakTrophies
            ? newTrophies
            : save.seasonPeakTrophies,
        injured: injured,
      ),
      extra: {
        'outcome': result.outcome.name,
        'gold': rw.gold,
        'trophyDelta': rw.trophyDelta,
        'rounds': result.rounds,
        'teamAHpPct': result.teamAHpPct,
        'teamBHpPct': result.teamBHpPct,
        // 클라이언트가 아레나 연출을 재생하도록 시드를 돌려준다
        // (같은 시드 + 같은 팀 = 같은 전개 — 결정론).
        'seed': seed,
      },
    );
  }

  /// 경과시간만큼 방치 수입을 정산한다.
  ///
  /// **클라이언트가 "얼마 벌었다"고 보고하지 않는다.** 서버가 `lastSeen` 부터
  /// 지금까지를 직접 계산한다. 방치 수입은 (스탯, 스테이지, 경과시간)의
  /// 결정론적 함수이므로 서버가 정확히 재현할 수 있다.
  ///
  /// 이 게임엔 **수동 탭 공격이 없다**(자동 전투만). 그래서 클라이언트가
  /// 보고할 것이 아예 없고, 탭 상한 같은 방어도 필요 없다.
  ActionResult sync(SaveGame save) {
    final t = now().toUtc();
    final elapsed = t.difference(save.lastSeen);
    if (elapsed.isNegative) {
      // 기기 시계가 과거로 조작된 경우 — 수입 없이 시각만 맞춘다.
      return ActionResult.ok(save.copyWith(lastSeen: t));
    }

    final run = config.run;
    final stats = deriveStats(
      run,
      upgradeLevels: save.upgradeLevels,
      characterLevel: save.level,
      bugsCollected: save.bugs.length,
    );

    // 접속 중 수입도 같은 함수로 계산한다 — 앱과 서버가 어긋나지 않게.
    // 오프라인 효율(offlineEfficiency)은 앱이 쓰던 값을 그대로 따른다.
    final report = computeOfflineReward(
      config: run,
      stageNumber: save.stageNumber,
      stats: stats,
      elapsed: elapsed,
      efficiency: run.offlineEfficiency,
    );

    var xp = save.xp + report.xp;
    var level = save.level;
    while (xp >= xpForNextLevel(level)) {
      xp -= xpForNextLevel(level);
      level++;
    }

    // 처치 수 → 곤충·재료 드롭. **서버가 굴린다.**
    final clears = estimateClears(
      config: run,
      stageNumber: save.stageNumber,
      stats: stats,
      elapsed: elapsed,
      efficiency: run.offlineEfficiency,
    );
    final rolls = clears.floor().clamp(0, maxRollsPerSync);
    final rng = (rngFactory ?? Random.new)();
    final newBugs = <IndividualBug>[];
    final mats = Map<MaterialKind, int>.from(save.materials);
    final species = config.speciesList;

    for (var i = 0; i < rolls; i++) {
      if (species.isNotEmpty &&
          rng.nextDouble() < run.bugDropChance * stats.bugFind) {
        final sp = species[rng.nextInt(species.length)];
        // 앱과 같은 분포: rng*rng 라 고포텐셜이 드물다.
        final potential = 1 + (rng.nextDouble() * rng.nextDouble() * 4).floor();
        newBugs.add(
          IndividualBug.roll(
            id: _uuid.v4(),
            species: sp,
            rng: rng,
            potential: potential.clamp(1, 5),
          ).copyWith(stage: LifeStage.egg, stageSince: t),
        );
      }
      if (rng.nextDouble() < run.materialDropChance * stats.materialFind) {
        final kind = _regularMaterials[rng.nextInt(_regularMaterials.length)];
        mats[kind] = (mats[kind] ?? 0) + 1 + rng.nextInt(2);
      }
    }

    return ActionResult.ok(
      save.copyWith(
        gold: save.gold + report.gold,
        xp: xp,
        level: level,
        lastSeen: t,
        bugs: newBugs.isEmpty ? null : [...save.bugs, ...newBugs],
        materials: mats,
      ),
      extra: {
        'gold': report.gold,
        'xp': report.xp,
        'elapsedSeconds': elapsed.inSeconds,
        'bugsGained': newBugs.length,
        'clears': rolls,
      },
    );
  }

  /// 업그레이드 1단계. **비용은 서버가 계산하고 잔액도 서버가 확인한다.**
  ActionResult upgrade(SaveGame save, UpgradeKind kind) {
    final spec = config.run.upgrades[kind];
    if (spec == null) return const ActionResult.fail('unknown_upgrade');
    final level = save.upgradeLevel(kind);
    final cost = upgradeCost(spec, level);
    if (save.gold < cost) return const ActionResult.fail('insufficient_gold');
    return ActionResult.ok(
      save.copyWith(
        gold: save.gold - cost,
        upgradeLevels: {...save.upgradeLevels, kind: level + 1},
      ),
      extra: {'cost': cost, 'newLevel': level + 1},
    );
  }

  /// 야생(합성) 상대 팀을 **서버가** 만든다.
  ///
  /// 클라이언트가 상대를 만들어 보내면 약한 팀으로 트로피를 쓸어담을 수 있다.
  /// 내 로스터 상위 3마리 평균 × 티어 배율로 만드는 규칙은 앱과 같지만,
  /// **난수와 배율 선택을 서버가 쥔다** — 클라는 티어 id 만 고른다.
  ({List<BattleBug> team, ScoutTier tier})? buildWildTeam(
    SaveGame save, {
    required String tierId,
    required Map<String, Species> speciesById,
    required PetConfig petConfig,
    EnhanceConfig? enhance,
    Random? rng,
  }) {
    final tier = config.battle.scoutTiers
        .where((t) => t.id == tierId)
        .firstOrNull;
    if (tier == null) return null; // 클라가 임의 배율을 못 넣게 id 로만 받는다

    final t = now().toUtc();
    double per(BugPart p, double d) => enhance?.spec(p).effectPerLevel ?? d;

    // 내 성충 로스터 → 전투 유닛 → 파워 상위 3마리 평균.
    final mine = <BattleBug>[];
    for (final bug in save.bugs) {
      final sp = speciesById[bug.speciesId];
      if (sp == null) continue;
      if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
          LifeStage.adult) {
        continue;
      }
      mine.add(
        buildBattleBug(
          bug: bug,
          species: sp,
          locale: 'ko',
          hornJawPerLevel: per(BugPart.hornJaw, 0.04),
          cuticlePerLevel: per(BugPart.cuticle, 0.04),
          wingPerLevel: per(BugPart.wing, 0.03),
          buildPerLevel: per(BugPart.build, 0.05),
        ),
      );
    }
    if (mine.isEmpty) return null;

    double power(BattleBug b) => b.maxHp + b.atk * 10 + b.def * 5 + b.spd * 2;
    mine.sort((a, b) => power(b).compareTo(power(a)));
    final top = mine.take(3).toList();
    final n = top.length;
    final avgHp = top.fold(0.0, (s, b) => s + b.maxHp) / n;
    final avgAtk = top.fold(0.0, (s, b) => s + b.atk) / n;
    final avgDef = top.fold(0.0, (s, b) => s + b.def) / n;
    final avgSpd = top.fold(0.0, (s, b) => s + b.spd) / n;

    final r = rng ?? (rngFactory ?? Random.new)();
    final species = config.speciesList;
    final team = List.generate(3, (i) {
      final sp = species[r.nextInt(species.length)];
      final f = (0.9 + r.nextDouble() * 0.2) * tier.powerMult;
      return BattleBug(
        id: 'wild_$i',
        name: sp.name.resolve('ko'),
        element: Element.values[r.nextInt(Element.values.length)],
        temperament: Temperament.values[r.nextInt(Temperament.values.length)],
        preferredStance: preferredStanceOf(sp.specialty),
        maxHp: avgHp * f,
        atk: avgAtk * f,
        def: avgDef * f,
        spd: avgSpd * f,
      );
    });
    return (team: team, tier: tier);
  }

  /// 부위 강화 1단계. 재료 비용·상한을 서버가 판정한다.
  ///
  /// 강화는 전투 스탯을 직접 올리므로 PvP 에 바로 영향을 준다.
  /// 클라이언트가 처리하면 재료 없이 만렙 강화가 가능해진다.
  ActionResult enhancePart(
    SaveGame save,
    String bugId,
    BugPart part, {
    required EnhanceConfig enhance,
  }) {
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    final bug = save.bugs[idx];
    if (bug.enhancement.total >= bug.maxLevel) {
      return const ActionResult.fail('at_cap');
    }
    final spec = enhance.spec(part);
    final cost = spec.costAt(bug.enhancement.levelOf(part));
    final have = save.materialCount(spec.material);
    if (have < cost) return const ActionResult.fail('insufficient_material');

    final mats = Map<MaterialKind, int>.from(save.materials)
      ..[spec.material] = have - cost;
    final bugs = List<IndividualBug>.from(save.bugs);
    bugs[idx] = bug.copyWith(enhancement: bug.enhancement.incremented(part));
    return ActionResult.ok(
      save.copyWith(bugs: bugs, materials: mats),
      extra: {'cost': cost, 'part': part.key},
    );
  }

  /// 수련(성충 레벨업). 골드 비용·티어 상한·돌파중 여부를 서버가 확인한다.
  ActionResult trainBug(
    SaveGame save,
    String bugId, {
    required PetConfig petConfig,
  }) {
    final t = now().toUtc();
    final idx = save.bugs.indexWhere((b) => b.id == bugId);
    if (idx < 0) return const ActionResult.fail('bug_not_owned');
    final bug = save.bugs[idx];
    if (effectiveStage(bug.stage, bug.stageSince, t, petConfig) !=
        LifeStage.adult) {
      return const ActionResult.fail('not_adult');
    }
    if (bug.breakthroughEndsAt != null) {
      return const ActionResult.fail('breakthrough_in_progress');
    }
    if (bug.level >= petConfig.levelCap(bug.breakthroughTier)) {
      return const ActionResult.fail('at_cap');
    }
    final cost = petConfig.trainCost(bug.level);
    if (save.gold < cost) return const ActionResult.fail('insufficient_gold');

    final bugs = List<IndividualBug>.from(save.bugs);
    bugs[idx] = bug.copyWith(level: bug.level + 1);
    return ActionResult.ok(
      save.copyWith(gold: save.gold - cost, bugs: bugs),
      extra: {'cost': cost, 'newLevel': bug.level + 1},
    );
  }

  /// 젤리 소비. 잔액이 모자라면 거부한다 — **클라이언트 말을 믿지 않는다.**
  ActionResult spendJelly(SaveGame save, int amount, {String? reason}) {
    if (amount <= 0) return const ActionResult.fail('bad_amount');
    final have = save.materialCount(MaterialKind.jelly);
    if (have < amount) return const ActionResult.fail('insufficient');
    final mats = Map<MaterialKind, int>.from(save.materials)
      ..[MaterialKind.jelly] = have - amount;
    return ActionResult.ok(save.copyWith(materials: mats));
  }
}

/// [GameActions] 가 필요로 하는 설정만 추린 인터페이스 —
/// 테스트에서 가짜 설정을 넣기 쉽게 한다.
abstract interface class GameConfigLike {
  IapConfig get iap;
  BattleConfig get battle;
  RunConfig get run;
  PetConfig get pet;
  EnhanceConfig? get enhance;

  /// 드롭 롤 대상 종 목록.
  List<Species> get speciesList;
}

/// 일반 채집으로 나오는 재료(젤리는 프리미엄이라 제외 — 앱과 동일).
const _regularMaterials = [
  MaterialKind.chitin,
  MaterialKind.mineral,
  MaterialKind.sap,
];
