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

---

## 7. 계정·데이터 삭제 RPC (Play 필수)

구글은 계정 생성이 가능한 앱에 **계정·데이터 삭제 수단**을 요구한다.
클라이언트 권한(anon/authenticated)으로는 `auth.users` 를 지울 수 없으므로
**SECURITY DEFINER** 함수로 처리한다.

`profiles`·`defenders`·`saves` 는 전부 `auth.users(id)` 에 `on delete cascade`
로 걸려 있어 인증 계정만 지우면 함께 사라지지만, 의도를 분명히 하고 cascade 가
바뀌어도 안전하도록 **명시적으로 먼저 지운다**.

> ⚠️ 아래 SQL 을 Supabase **SQL Editor** 에 붙여 실행할 것.
> 실행하지 않으면 앱의 "계정 삭제" 버튼이 실패한다(로컬 데이터는 보존됨).

```sql
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  delete from public.defenders where id = uid;
  delete from public.saves     where id = uid;
  delete from public.profiles  where id = uid;

  -- 인증 계정 자체를 삭제(위 테이블은 cascade 로도 정리된다)
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
```

**앱 쪽**: `AuthService.deleteAccount()` 가 이 RPC 를 호출한다.
성공하면 세션을 정리하고 새 익명 계정으로 복귀하며, **그 다음에** 호출부가
`SaveController.resetGame()` 으로 로컬을 초기화한다.
순서를 반대로 하면 서버 삭제 실패 시 진행도만 날아가므로 바꾸지 말 것.

**안내 페이지**: `https://dkc260701.github.io/bugchamp-policy/delete.html`

---

## 8. 전체 채팅 (UGC — 신고·차단·도배방지 필수)

> ⚠️ 채팅은 **사용자 제작 콘텐츠**다. 구글 플레이 정책상 신고·차단 수단이 없으면
> 심사에서 거부되거나 출시 후 앱이 내려간다. 아래 SQL 을 **전부** 실행할 것.

### 8-1. 테이블 + RLS

```sql
-- 메시지
create table if not exists chat_messages (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  nickname   text not null check (char_length(nickname) between 1 and 20),
  body       text not null check (char_length(body) between 1 and 100),
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_created_idx
  on chat_messages (created_at desc);

alter table chat_messages enable row level security;

-- 읽기: 로그인한 사용자 누구나
create policy chat_read on chat_messages
  for select to authenticated using (true);

-- 쓰기: 본인 명의로만
create policy chat_insert on chat_messages
  for insert to authenticated with check (auth.uid() = user_id);

-- 수정/삭제는 아무도 못 한다(정책 미생성 = 거부).
```

### 8-2. 서버 도배 방지 (클라이언트 검사만으론 부족)

앱을 조작하면 클라이언트 간격 제한은 우회된다. 서버에서도 막는다.

```sql
create or replace function public.chat_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  last_at timestamptz;
begin
  select max(created_at) into last_at
    from chat_messages where user_id = new.user_id;

  if last_at is not null and now() - last_at < interval '3 seconds' then
    raise exception 'rate_limited';
  end if;
  return new;
end;
$$;

drop trigger if exists chat_rate_limit_trg on chat_messages;
create trigger chat_rate_limit_trg
  before insert on chat_messages
  for each row execute function public.chat_rate_limit();
```

> 간격(3초)은 `assets/data/chat.json` 의 `minIntervalSeconds` 와 맞춘다.
> 한쪽만 바꾸면 앱은 보내는데 서버가 거부하는 상태가 된다.

### 8-3. 신고

```sql
create table if not exists chat_reports (
  id          bigint generated always as identity primary key,
  message_id  bigint not null references chat_messages(id) on delete cascade,
  reporter_id uuid   not null references auth.users(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  unique (message_id, reporter_id)   -- 같은 사람이 같은 메시지를 중복 신고 못 함
);

alter table chat_reports enable row level security;

-- 신고는 본인 명의로만 등록. 조회는 운영자(대시보드)에서만 한다.
create policy chat_report_insert on chat_reports
  for insert to authenticated with check (auth.uid() = reporter_id);
```

### 8-4. Realtime 켜기

Supabase 대시보드 → **Database → Replication** → `supabase_realtime` 게시에
**`chat_messages` 테이블을 추가**한다. 안 하면 새 메시지가 실시간으로 안 온다
(앱은 최근 목록만 보여주고 조용히 멈춘 것처럼 보인다).

### 8-5. 운영 — 신고 확인하는 법

```sql
-- 신고 많이 받은 메시지 순
select m.id, m.nickname, m.body, count(r.id) as reports, m.created_at
  from chat_messages m
  join chat_reports r on r.message_id = m.id
 group by m.id
 order by reports desc, m.created_at desc
 limit 50;

-- 문제 메시지 삭제
delete from chat_messages where id = <id>;
```

> 지금은 **수동 운영**이다. 신고가 쌓이면 위 쿼리로 확인하고 지운다.
> 자동 차단·계정 정지는 후속 과제.

### 8-6. 클라이언트 쪽 방어(참고)

- 금칙어 필터: `assets/data/chat.json` 의 `bannedWords` — **보낼 때와 보여줄 때 양쪽**에서 검사.
  목록 갱신 전에 서버에 들어간 과거 메시지도 화면에서 가려진다.
- 차단: `SaveGame.blockedUserIds` (기기 로컬). 차단당한 쪽은 알 수 없다(보복 방지).
- 닉네임: 채팅과 **같은 금칙어 목록**을 쓴다. 설정할 때 막고(`nicknameAllowed`),
  **이미 서버에 등록된 이름은 표시할 때 대체**한다(`maskNickname` → "이용자").
  적용 위치: 채팅 말풍선 · 랭킹 · 스카우트 보드.
  별표가 아니라 중립 이름을 쓰는 이유 — 별표는 오히려 눈에 띄어 관심을 끈다.

---

## 9. 영수증 서버 검증 (결제 위조 방지)

> 클라이언트만으로 구매를 인정하면 결제 후킹 앱이 만든 **가짜 영수증**으로
> 상품이 그냥 나간다. 진짜 구글이 발급한 영수증인지는 **서버만** 판단할 수 있다.

### 9-1. 재사용 방지 테이블

```sql
create table if not exists verified_purchases (
  purchase_token text primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  product_id     text not null,
  order_id       text,
  verified_at    timestamptz not null default now()
);

alter table verified_purchases enable row level security;
-- 정책 없음 = 클라이언트는 접근 불가. Edge Function 이 service_role 로만 쓴다.
```

`purchase_token` 이 기본키라 **같은 영수증을 두 계정이 쓸 수 없다**.
앱 로컬 원장(`redeemedPurchases`)은 기기별이라 계정 간 재사용을 막지 못한다.

### 9-2. 구글 서비스 계정 만들기 (사장님 작업)

1. **Google Cloud Console → IAM → 서비스 계정 → 만들기**
   - 이름 예: `play-verify`. 역할은 부여하지 않아도 된다.
2. 만든 계정 → **키 → 새 키 만들기 → JSON** → 파일 다운로드
3. **Play Console → 설정 → API 액세스**
   - 해당 Google Cloud 프로젝트를 연결
   - 위 서비스 계정에 **"재무 데이터 보기"** + **"주문 및 구독 관리"** 권한 부여
4. 권한 반영에 **최대 24시간**이 걸릴 수 있다(구글 안내). 바로 안 되면 기다린다.

> 🔴 이 JSON 키는 **비밀**이다. 앱·저장소에 절대 넣지 않는다.
> 유출되면 남이 내 결제 데이터를 조회할 수 있다.

### 9-3. Edge Function 배포

시크릿 등록(대시보드 → Edge Functions → Secrets, 또는 CLI):

```bash
supabase secrets set PLAY_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/play-verify-xxxx.json)"
supabase functions deploy verify-purchase
```

`SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` 는
Supabase 가 자동 주입하므로 따로 넣지 않아도 된다.

함수 소스: `supabase/functions/verify-purchase/index.ts`

### 9-4. 앱 동작

| 서버 판정 | 앱 동작 |
|---|---|
| `ok: true` | 지급 + 스토어에 완료 통보 |
| `invalid` / `owned_by_other` | **지급 안 함** + 완료 통보(재시도 무의미하므로 큐에서 제거) |
| 그 외(네트워크·점검·미배포) | **지급도 완료통보도 안 함** → 다음 실행에 재시도 |

마지막 줄이 중요하다. 서버에 못 닿았다고 정상 구매를 거부해버리면
**비행기모드나 서버 점검 중에 돈 낸 사용자가 상품을 못 받는다.**
판정이 안 될 때는 보류하고 나중에 다시 확인한다.

> ⚠️ 함수를 배포하지 않으면 모든 구매가 **보류** 상태가 된다(지급 안 됨).
> 결제를 켜기 전에 반드시 배포할 것.

### 9-5. ⚠️ 이걸로도 못 막는 것

영수증 검증은 **가짜 영수증**을 막는다. 하지만 이 게임은 진행도가
**기기(Hive)** 에 있고 클라이언트가 자기 세이브를 직접 쓴다. 따라서
앱을 뜯어고친 사용자가 결제 흐름 자체를 건너뛰고 재화를 넣는 것은
여전히 가능하다.

- ✅ 막아지는 것: 결제 후킹 앱(Lucky Patcher 류)으로 만든 위조 영수증 — **현실의 주된 위협**
- ✅ 막아지는 것: 한 영수증을 여러 계정이 돌려쓰기
- ❌ 안 막아지는 것: 앱 자체를 개조해 로컬 세이브를 조작

완전히 막으려면 재화·구매 상태를 **서버 권威**로 옮겨야 하는데, 그건
게임 구조 전체를 바꾸는 일이다. 지금 단계에서는 과하다 — 매출 규모가
커지면 그때 검토한다.
