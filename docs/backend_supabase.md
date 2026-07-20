# Phase 4 백엔드 — Supabase 연동 가이드

> 목표: 비동기 PvP(다른 유저의 **방어팀**과 대전) + **리더보드**.
> 현재는 `LocalPvpBackend`(로컬 사다리)로 랭킹 화면이 동작한다. Supabase 구현을
> 만들어 `pvpBackendProvider` 를 오버라이드하면 실데이터로 바뀐다.
> 아키텍처 원칙: `Clock` 처럼 **인터페이스 + 구현 교체**(§CLAUDE.md 3·9).

---

## 1. 현재 코드 상태 (Increment 1·2 코드 완료)

- `domain/pvp_backend.dart` — `PvpBackend` 인터페이스 + `PvpProfile`/`LeaderboardEntry` +
  `LocalPvpBackend`(폴백) + `pvpBackendProvider`.
- `domain/supabase_pvp_backend.dart` — **`SupabasePvpBackend` 구현 완료**(리더보드 upsert+RPC,
  **방어팀 등록 `registerDefender`**, **실 유저 방어팀 fetch `fetchOpponents`(RPC `nearby_defenders`)**,
  실패 시 로컬 폴백). `PvpBackend.isRemote` 로 UI 가 온라인/로컬 안내를 구분.
- `main.dart` — `--dart-define` 로 URL/anon key 주입 시 `Supabase.initialize` + 익명 로그인 후
  `pvpBackendProvider` 를 Supabase 구현으로 오버라이드. 키 없으면 로컬.
- `features/leaderboard/leaderboard_screen.dart` — 랭킹 화면(홈 상단 랭킹 아이콘 → 진입).
- `features/battle/battle_screen.dart` — 진입 시 편성을 방어팀으로 등록, 스카우트 보드에 실 유저 방어팀 병합.
- **남은 것**: §4 SQL 에 **`nearby_defenders` RPC 추가 실행** 후 실기 2계정으로 비동기 대전 검증(§6 ⏳ 항목).

### 실행(실 Supabase로 테스트)
```powershell
cd packages\app
flutter run -d <device> ^
  --dart-define=SUPABASE_URL=https://rvmpwyycivmtrbbynjyy.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<anon public key(eyJ...)>
```
> 키를 안 주면(그냥 `flutter run`) 로컬 랭킹으로 동작. 키는 저장소에 커밋되지 않음.

---

## 2. 사장님이 할 일 (1회)

1. ✅ 프로젝트 생성됨: `https://rvmpwyycivmtrbbynjyy.supabase.co`.
2. **anon public key** 확보(Settings → API → Project API keys → `anon`/`public`, `eyJ...`).
3. 아래 §4 SQL 을 **SQL Editor** 에 실행(테이블 + RLS + RPC).
4. **Auth → Providers → Anonymous sign-ins** 켜기(내 프로필 upsert에 필요).
5. §1 실행 명령의 `--dart-define` 에 URL/anon key 넣어 실기 실행 → 랭킹이 실데이터로.

---

## 3. 데이터 모델(계획)

- **profiles**: 유저 1명 = 닉네임 + 트로피 + 등급(파생). 리더보드 소스.
- **defenders**: 유저의 **방어팀 스냅샷**(성충3의 종·오행·스탯·기질). 다른 유저가 이걸 상대함.
- 매칭: 내 트로피 근처의 defenders 를 N개 뽑아 스카우트 보드에 노출(현재 로컬 생성 → 교체).

---

## 4. SQL 스키마 (초안)

```sql
-- 익명 인증 사용 가정(supabase auth anonymous). auth.uid() = 유저 식별.
-- 재실행해도 안전(idempotent).
create table if not exists profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nickname   text not null,
  trophies   int  not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists defenders (
  id         uuid primary key references auth.users(id) on delete cascade,
  team       jsonb not null,           -- 성충3 스냅샷(종·오행·스탯·기질·사이즈)
  trophies   int  not null default 0,  -- 매칭 대역폭용(비정규화)
  updated_at timestamptz not null default now()
);

create index if not exists profiles_trophies_idx on profiles (trophies desc);
create index if not exists defenders_trophies_idx on defenders (trophies desc);

-- RLS: **본인 행만** 접근(테이블 전체는 비공개). 랭킹은 아래 SECURITY DEFINER 함수로만 노출.
alter table profiles  enable row level security;
alter table defenders enable row level security;

drop policy if exists read_all_profiles   on profiles;   -- (구버전 정리)
drop policy if exists read_all_defenders  on defenders;
drop policy if exists own_profile  on profiles;
drop policy if exists own_defender on defenders;

create policy own_profile  on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
create policy own_defender on defenders
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- 리더보드 상위 N(순위 포함): SECURITY DEFINER 로 RLS 우회 → 전체 랭킹 반환.
-- 민감정보 없이 rank/nickname/trophies 만 노출. search_path 고정(보안).
create or replace function leaderboard_top(lim int)
returns table(rank bigint, id uuid, nickname text, trophies int)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by trophies desc) as rank,
         id, nickname, trophies
  from profiles order by trophies desc limit lim;
$$;

-- 비동기 매칭(Inc.2): 내 트로피 근처의 **다른 유저** 방어팀 N개.
-- defenders 는 RLS 로 본인 행만 보이므로, 남의 방어팀은 이 SECURITY DEFINER 로만 노출.
-- 나(auth.uid()) 는 제외. 방어팀·닉네임·트로피만 반환(민감정보 없음).
create or replace function nearby_defenders(my_trophies int, lim int)
returns table(id uuid, nickname text, trophies int, team jsonb)
language sql stable security definer set search_path = public as $$
  select d.id, coalesce(p.nickname, '') as nickname, d.trophies, d.team
  from defenders d
  left join profiles p on p.id = d.id
  where d.id <> auth.uid()
  order by abs(d.trophies - my_trophies) asc, d.updated_at desc
  limit lim;
$$;

-- 클라우드 세이브: 유저 1명 = 행 1개. 본인 행만 접근(RLS).
create table if not exists saves (
  id         uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);
alter table saves enable row level security;
drop policy if exists own_save on saves;
create policy own_save on saves
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- PostgREST 스키마 캐시 갱신(테이블/함수가 즉시 API에 노출되도록).
notify pgrst, 'reload schema';
```

> ⚠️ **Inc.2 추가 시 재실행 필요**: `nearby_defenders` 함수를 SQL Editor 에 실행(위 블록 전체를
> 다시 실행해도 idempotent). 이 함수가 없으면 스카우트 보드는 로컬 합성 상대로만 채워진다.

---

## 5. Supabase 구현 스케치 (연결 시 추가)

```dart
// pubspec: supabase_flutter 추가.
class SupabasePvpBackend implements PvpBackend {
  SupabasePvpBackend(this._client);
  final SupabaseClient _client;

  @override
  Future<List<LeaderboardEntry>> leaderboard({required PvpProfile me, int limit = 50}) async {
    // 1) 내 프로필 upsert(닉네임·트로피)
    await _client.from('profiles').upsert({
      'id': me.id, 'nickname': me.nickname, 'trophies': me.trophies,
    });
    // 2) 상위 N 조회(RPC) → 엔트리 매핑 + 나 표시(+ 필요 시 내 순위 별도 조회)
    final rows = await _client.rpc('leaderboard_top', params: {'lim': limit});
    return [ for (final r in rows) LeaderboardEntry(
      rank: r['rank'], isMe: r['id'] == me.id,
      profile: PvpProfile(id: r['id'], nickname: r['nickname'], trophies: r['trophies'])) ];
  }
}
```

`main.dart` 부트스트랩에서 `Supabase.initialize(url, anonKey)` + 익명 로그인 후
`pvpBackendProvider.overrideWithValue(SupabasePvpBackend(Supabase.instance.client))`.

---

## 6. 다음 인크리먼트 (연결 후)

- ✅ **방어팀 등록**(Inc.2, 2026-07-18): 전투 탭 진입 시 현재 편성을 `defenders` 로 upsert(`registerDefender`).
  시그니처(곤충 id·트로피) 변화 시에만 재등록. 별도 방어팀 피커/세이브 캐시는 미도입(파생 상태라 불필요).
- ✅ **스카우트 보드 실데이터**(Inc.2, 2026-07-18): `nearby_defenders` RPC 로 내 트로피 근처 defenders fetch →
  내 로스터 대비 파워비율로 난이도 티어(약/대등/강)에 배치, 남는 슬롯은 로컬 합성으로 채움. 실 유저면 카드에 닉네임 표시.
- ✅ **오프라인/에러 폴백**(Inc.2): fetch 실패/실데이터 없음 → 로컬 합성 상대 유지(스카우트 보드 항상 동작).
- ✅ **결과 반영(트로피 라이브)**(2026-07-18): 승패 직후 `pushTrophies` 로 `profiles`(리더보드) upsert + `defenders.trophies`(매칭 브래킷) 즉시 갱신(fire-and-forget). 화면 재진입 없이 랭킹/브래킷 반영.
- ⏳ **정확한 매칭 폭·재대결 제한·복수전·방어팀 팀 스냅샷 라이브 갱신** 등은 후속 폴리시.
