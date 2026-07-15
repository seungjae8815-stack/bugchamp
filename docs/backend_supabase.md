# Phase 4 백엔드 — Supabase 연동 가이드

> 목표: 비동기 PvP(다른 유저의 **방어팀**과 대전) + **리더보드**.
> 현재는 `LocalPvpBackend`(로컬 사다리)로 랭킹 화면이 동작한다. Supabase 구현을
> 만들어 `pvpBackendProvider` 를 오버라이드하면 실데이터로 바뀐다.
> 아키텍처 원칙: `Clock` 처럼 **인터페이스 + 구현 교체**(§CLAUDE.md 3·9).

---

## 1. 현재 코드 상태 (Increment 1·2 코드 완료)

- `domain/pvp_backend.dart` — `PvpBackend` 인터페이스 + `PvpProfile`/`LeaderboardEntry` +
  `LocalPvpBackend`(폴백) + `pvpBackendProvider`.
- `domain/supabase_pvp_backend.dart` — **`SupabasePvpBackend` 구현 완료**(upsert 프로필 + RPC 조회,
  실패 시 로컬 폴백).
- `main.dart` — `--dart-define` 로 URL/anon key 주입 시 `Supabase.initialize` + 익명 로그인 후
  `pvpBackendProvider` 를 Supabase 구현으로 오버라이드. 키 없으면 로컬.
- `features/leaderboard/leaderboard_screen.dart` — 랭킹 화면(홈 상단 랭킹 아이콘 → 진입).
- **남은 것**: 실기에서 §2 셋업 후 `--dart-define` 로 실행해 검증, 이후 방어팀 등록·스카우트 실데이터(Inc.2 후속).

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
create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nickname   text not null,
  trophies   int  not null default 0,
  updated_at timestamptz not null default now()
);

create table defenders (
  id         uuid primary key references auth.users(id) on delete cascade,
  team       jsonb not null,           -- 성충3 스냅샷(종·오행·스탯·기질·사이즈)
  trophies   int  not null default 0,  -- 매칭 대역폭용(비정규화)
  updated_at timestamptz not null default now()
);

-- 리더보드 상위 조회 인덱스
create index profiles_trophies_idx on profiles (trophies desc);
create index defenders_trophies_idx on defenders (trophies desc);

-- RLS: 누구나 읽기, 본인만 자기 행 upsert.
alter table profiles  enable row level security;
alter table defenders enable row level security;
create policy read_all_profiles  on profiles  for select using (true);
create policy read_all_defenders on defenders for select using (true);
create policy upsert_own_profile  on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
create policy upsert_own_defender on defenders
  for all using (auth.uid() = id) with check (auth.uid() = id);
```

리더보드 상위 + 내 순위는 RPC(SQL 함수)로 한 번에 받는 게 효율적:

```sql
create or replace function leaderboard_top(lim int)
returns table(rank bigint, id uuid, nickname text, trophies int)
language sql stable as $$
  select row_number() over (order by trophies desc) as rank,
         id, nickname, trophies
  from profiles order by trophies desc limit lim;
$$;
```

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

1. **방어팀 등록**: 전투 탭에서 방어팀 선택 → `defenders` upsert(save v16 로 로컬 캐시).
2. **스카우트 보드 실데이터**: 로컬 생성 대신 내 트로피 근처 defenders N개 fetch → 3택1.
3. **결과 반영**: 승패 시 내 트로피 갱신 → 프로필/디펜더 갱신.
4. **오프라인/에러 폴백**: 네트워크 실패 시 `LocalPvpBackend` 로 자동 폴백.
