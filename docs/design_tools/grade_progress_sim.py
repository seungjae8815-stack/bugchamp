"""개체 등급 · 정수 · 부화기 — '전설까지 며칠' 시뮬(설계 검토용, docs/design_individual_grade.md).

실데이터(species.json · pets.json · run_config.json)를 읽고, 1분 단위로 120일을 돌린다.
유저 모델: 한 종(목표 종)을 전설로 만드는 데 집중. 다른 종 알은 칸을 비우려고 바로 놓아준다.

가정(바꿔 볼 수 있는 것은 위쪽 상수):
- 하루 드롭 ≈ 198알(§2.4: 6,600처치 × 3%) — 활동 2시간 90알, 나머지 22시간 108알.
- 채집함 50칸(부화 중인 알 포함). 차면 새 알은 버려진다(획득 차단).
- 부화기·짝짓기 모두 **수동 수령**: 활동 2시간 동안 10분마다 + 하루 4번(08·12·18·23시) 들여다본다.
- 야생 개체 등급: 일반 80 · 고급 15 · 희귀 4 · 영웅 1 · 전설 0.
- 정수: 애벌레 이상만(알 불가). 1마리 = 등급 누적 비용 × 종 희귀도 가치.
- 짝짓기: 키우는 개체 + 같은 종 반대 성별 1마리. 자식 = 높은 부모 등급에서 유지 60 · 상승 10 · 하락 30. 부화 뒤 성충까지 1시간(가정).
사용: python -I grade_progress_sim.py
"""
import json
import os
import random
import sys

sys.stdout.reconfigure(encoding="utf-8")
DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../packages/app/assets/data")
species = json.load(open(f"{DATA}/species.json", encoding="utf-8"))
species = species if isinstance(species, list) else species["species"]
pets = json.load(open(f"{DATA}/pets.json", encoding="utf-8"))
run = json.load(open(f"{DATA}/run_config.json", encoding="utf-8"))

GRADES = ["common", "uncommon", "rare", "epic", "legendary"]
KO_G = ["일반", "고급", "희귀", "영웅", "전설"]
WILD = [0.80, 0.15, 0.04, 0.01, 0.0]
COSTS = [6, 6, 6, 10]                                   # 등급 올리기 배수(일반→고급 … 영웅→전설)
VAL = [1, 6, 36, 216, 2160]                              # 그 등급 1마리 = 정수(누적)
RARITY_MULT = {"common": 1, "uncommon": 1.6, "rare": 3, "epic": 5.5, "legendary": 26}
HATCH = {g: s // 60 for g, s in pets["incubateDurationsSec"].items()}
BREED = {g: s // 60 for g, s in pets["breedingDurationsSec"].items()}
DROP_W = run["dropGradeWeights"]
by_grade = {g: [s["id"] for s in species if s["grade"] == g] for g in GRADES}
rarity_of = {s["id"]: s["grade"] for s in species}
STORAGE = 50
DAY = 1440
ACTIVE = (20 * 60, 22 * 60)                              # 20~22시 활동
CHECKS = {8 * 60, 12 * 60, 18 * 60, 23 * 60 + 30}
ADULT_AFTER = 60


def roll_species(rng):
    g = rng.choices(GRADES, weights=[DROP_W[x] for x in GRADES])[0]
    return rng.choice(by_grade[g])


def child_grade(rng, g):
    # 2026-10-11 사장님 확정: 짝짓기 자식 등급은 주운 알과 같은 확률(부모 등급을 물려받지 않는다).
    return rng.choices(range(5), weights=WILD)[0]


GACHA_SP_W = pets["gachaWeights"]                     # 종 희귀도별
GACHA_G = [0, 0, 0.70, 0.27, 0.03]                    # 개체 등급: 희귀 70 · 영웅 27 · 전설 3(A안)
NO_GACHA_MULT = '--gacha-mult' not in sys.argv   # 뽑기 알은 종 희귀도 정수 보정을 받지 않는다
GACHA_PITY = 10                                       # 10회마다 영웅 이상 확정


def gacha_pull(rng, state):
    g_sp = rng.choices(list(GACHA_SP_W), weights=list(GACHA_SP_W.values()))[0]
    sp = rng.choice(by_grade[g_sp])
    g = rng.choices(range(5), weights=GACHA_G)[0]
    state[0] += 1
    if g >= 3:
        state[0] = 0
    elif state[0] >= GACHA_PITY:
        g = 3
        state[0] = 0
    return sp, g


def sim(target, hatch_slots=1, breed_slots=1, days=120, seed=1, pulls=0):
    rng = random.Random(seed)
    rar = rarity_of[target]
    storage = []              # 알: (species, grade)
    hatching = []             # (끝나는 분, grade)
    breeding = []             # (끝나는 분, grade)
    keeper = None             # (grade, sex, adult_at)
    mate = None
    essence = 0.0
    pair_ready = [0]
    pity = [0]
    legends = 0
    lost = 0
    hatched = 0
    for t in range(days * DAY):
        m = t % DAY
        active = ACTIVE[0] <= m < ACTIVE[1]
        # 드롭(활동 90알/2시간, 그 밖 108알/22시간)
        rate = 90 / 120 if active else 108 / (DAY - 120)
        if rng.random() < rate:
            if len(storage) + len(hatching) >= STORAGE:
                lost += 1
            else:
                sp = roll_species(rng)
                g = rng.choices(range(5), weights=WILD)[0]
                if sp == target:
                    storage.append((g, False))
                # 다른 종은 들여다볼 때 놓아준다 — 그 사이엔 칸을 차지한다
                else:
                    storage.append(None)
        if pulls and m == 8 * 60:
            for _ in range(pulls):
                sp, g = gacha_pull(rng, pity)
                legends += g == 4
                if len(storage) + len(hatching) >= STORAGE:
                    lost += 1
                else:
                    storage.append((g, True) if sp == target else None)
        look = (active and m % 10 == 0) or m in CHECKS
        if not look:
            continue
        # 1) 부화 수령 → 키울 개체 갱신 · 나머지 정수
        done = [h for h in hatching if h[0] <= t]
        hatching = [h for h in hatching if h[0] > t]
        for _, g, from_gacha in done:
            hatched += 1
            mult = 1 if (from_gacha and NO_GACHA_MULT) else RARITY_MULT[rar]
            sex = rng.choice("MF")
            if keeper is None or g > keeper[0]:
                if keeper is not None:
                    # 태어난 몫만 희귀도 가치, 올린 몫은 들인 만큼(앱 essenceOf 와 같은 규칙)
                    essence += VAL[keeper[3]] * mult + VAL[keeper[0]] - VAL[keeper[3]]
                keeper = (g, sex, t + ADULT_AFTER, g)
            elif (mate is None or g > mate[0]) and sex != keeper[1]:
                if mate is not None:
                    essence += VAL[mate[0]] * mult
                mate = (g, sex, t + ADULT_AFTER)
            else:
                essence += VAL[g] * mult
        # 2) 짝짓기 수령
        done = [b for b in breeding if b[0] <= t]
        breeding = [b for b in breeding if b[0] > t]
        for _, g in done:
            if len(storage) + len(hatching) < STORAGE:
                storage.append((g, False))
            else:
                lost += 1
        # 3) 다른 종 알 놓아주기
        storage = [x for x in storage if x is not None]
        # 4) 부화기 채우기(높은 등급 먼저)
        storage.sort(reverse=True)
        while len(hatching) < hatch_slots and storage:
            g, from_gacha = storage.pop(0)
            hatching.append((t + HATCH[rar], g, from_gacha))
        # 5) 짝짓기
        # 부모 쌍은 산란 시작부터 산란 시간 × breedingCooldownMult 동안 다시 못 한다(실제 규칙).
        if keeper and mate and keeper[2] <= t and mate[2] <= t and t >= pair_ready[0] and len(breeding) < breed_slots:
            breeding.append((t + BREED[rar], child_grade(rng, max(keeper[0], mate[0]))))
            pair_ready[0] = t + int(BREED[rar] * pets.get("breedingCooldownMult", 0))
        # 6) 등급 올리기
        while keeper and keeper[0] < 4 and essence >= VAL[keeper[0] + 1] - VAL[keeper[0]]:
            essence -= VAL[keeper[0] + 1] - VAL[keeper[0]]
            keeper = (keeper[0] + 1, keeper[1], keeper[2], keeper[3])
        if keeper and keeper[0] == 4:
            return t / DAY, hatched, legends
    return None, hatched, legends


KO_R = {"common": "흔한 종", "uncommon": "고급 종", "rare": "희귀 종", "epic": "영웅 종", "legendary": "전설 종"}
PROFILES = [("무료", 1, 1, 0), ("중간(3·3)", 3, 3, 0), ("과금(5·5 + 뽑기 10회/일)", 5, 5, 10)]
print(f"정수 배수 {COSTS} · 전설 = 정수 {VAL[4]} · 야생 등급 {WILD} · 종 가치 {RARITY_MULT}")
for g in GRADES:
    sp = by_grade[g][0]
    row = []
    for name, hs, bs, pl in PROFILES:
        res = [sim(sp, hs, bs, seed=s, pulls=pl) for s in range(5)]
        ds = [r[0] for r in res if r[0] is not None]
        avg = sum(ds) / len(ds) if ds else None
        row.append(f"{name} {avg:5.1f}일" if avg else f"{name} 120일+")
        if pl and avg:
            leg = sum(r[2] for r in res) / len(res)
            row[-1] += f"(그동안 뽑기 전설 {leg:.1f}마리)"
    print(f"  {KO_R[g]:5}({sp}) " + " · ".join(row))


# ── 짝짓기 눈덩이 점검 ─────────────────────────────────────
def variant(label, child_fn, breed_slots_free=1):
    global child_grade
    old = child_grade
    child_grade = child_fn
    print(f"\n[{label}]")
    for g in GRADES:
        sp = by_grade[g][0]
        row = []
        for name, hs, bs in [("무료", 1, breed_slots_free), ("과금", 5, 5 if breed_slots_free else 0)]:
            ds = [r[0] for r in (sim(sp, hs, bs, seed=s) for s in range(5)) if r[0] is not None]
            row.append(f"{name} {sum(ds)/len(ds):5.1f}일" if ds else f"{name} 120일+")
        print(f"  {KO_R[g]:5} " + " · ".join(row))
    child_grade = old

if __name__ == "__main__" and "--breeding" in sys.argv:
    variant("짝짓기 없음", lambda rng, g: 0, breed_slots_free=0)
    variant("짝짓기 자식 = 야생 분포(등급 안 물려줌)", lambda rng, g: rng.choices(range(5), weights=WILD)[0])
    variant("자식 = 부모 등급 −2(최소 일반), 유지·상승 없음", lambda rng, g: max(0, g - 2))
