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

-- 수정은 아무도 못 한다(정책 미생성 = 거부).
-- 삭제: 본인이 쓴 메시지만(Apple 1.2 — UGC 는 본인 콘텐츠 삭제 수단 필요).
create policy chat_delete on chat_messages
  for delete to authenticated using (auth.uid() = user_id);
```

> ⚠️ **`chat_delete` 정책을 SQL Editor 에 실행할 것.** 없으면 앱의 "내 메시지 삭제"가
> RLS 로 막혀 조용히 실패한다(0행 삭제). 앱은 `deleteOwn()` 으로 이 정책에 의존한다.

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

**iOS(App Store) 도 지원한다.** 같은 함수가 iOS 영수증(긴 base64)을 감지해
Apple `verifyReceipt` 로 검증한다(프로덕션→샌드박스 자동 재시도). 이를 위해
`APPLE_SHARED_SECRET`(App-Specific Shared Secret) 시크릿을 추가로 넣는다:
```bash
supabase secrets set APPLE_SHARED_SECRET="<App Store Connect 공유 암호>"
```
자세한 iOS 등록·검증 절차는 `docs/appstore_iap.md`.

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

---

## 10. 수동 전투 세션 (서버 권위)

수동 전투는 **상대의 수를 미리 알 수 없어야** 성립한다. 시드를 클라이언트에
주면 매 라운드 상대 수를 계산해 최적해를 고를 수 있으므로, 시드는 서버에만 둔다.

Cloud Run 은 인스턴스가 바뀔 수 있어 메모리에 세션을 둘 수 없다. DB 에 저장하고
매 스텝마다 시드+수 목록으로 **처음부터 재생**한다(최대 20라운드라 비용은 무시할 수준).

```sql
create table if not exists battle_sessions (
  id         text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);
create index if not exists battle_sessions_user_idx
  on battle_sessions (user_id);

alter table battle_sessions enable row level security;
-- 정책 없음 = 클라이언트 직접 접근 불가. 서버가 service_role 로만 읽고 쓴다.
-- (세션 data 에 시드가 들어 있으므로 클라가 읽으면 안 된다.)
```

### 오래된 세션 정리 (선택)

```sql
delete from battle_sessions where updated_at < now() - interval '1 day';
```

> 세션 id 는 `Random.secure()` 16바이트라 추측할 수 없고, 스텝 요청 시
> **소유자(user_id)를 확인**하므로 남의 세션을 진행시킬 수 없다.
> 끝난 세션은 `finished` 로 잠가 보상 중복 수령을 막는다.

## 11. 닉네임 중복 확인 RPC (2026-08)

닉네임 설정/변경 시 "이미 사용 중" 안내용. profiles 는 RLS 로 본인 행만 보이므로
클라이언트가 직접 select 할 수 없다 → SECURITY DEFINER 함수로 존재 여부만 알려준다.
앱은 `SupabasePvpBackend.isNicknameTaken` 이 이 RPC 를 호출한다(미배포/실패 시
false 폴백 — 이름 짓기를 막지 않음).

```sql
create or replace function public.nickname_taken(p_name text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where lower(nickname) = lower(trim(p_name))
      and id <> auth.uid()
  );
$$;

grant execute on function public.nickname_taken(text) to authenticated;
```

경쟁 조건(둘이 동시에 같은 이름 저장)까지 완전히 막으려면 unique 인덱스가 필요하다.
단, **기존 중복(기본 닉네임 '채집가' 등)을 먼저 정리해야** 생성이 성공한다:

```sql
-- 중복 확인: select lower(nickname), count(*) from profiles group by 1 having count(*)>1;
-- 정리 후:
-- create unique index profiles_nickname_uniq on public.profiles (lower(nickname));
```

---

## 12. 공지 · 운영 우편 · 선물코드 (2026-08-07)

셋 다 **"서버가 유저에게 보낸다"는 같은 일**이라 한 벌로 만들었다.
점검·업데이트 보상은 별도 기능이 아니라 **전체 발송 우편 한 통**이다.

### 왜 지급을 서버가 하나
재화는 기기 권위지만, 이 보상만은 **서버가 세이브에 더하고 앱이 그 세이브를
채택**한다(`/purchase` 와 같은 방식). 앱이 스스로 더하면 다음 업로드에서
골드 급증 상한(`_goldSanityFloor` = 20만)에 걸려 **정당한 보상이 잘린다.**

### SQL (Supabase SQL Editor 에서 1회 실행 — 재실행 안전)

```sql
-- 공지: 전체 공개 읽기지만 서버(service_role)를 통해서만 나간다.
create table if not exists notices (
  id         bigserial primary key,
  title      text not null,
  body       text not null default '',
  starts_at  timestamptz,          -- null = 즉시
  ends_at    timestamptz,          -- null = 무기한
  pinned     boolean not null default false,
  created_at timestamptz not null default now()
);

-- 운영 우편: user_id 가 null 이면 **전체 유저 대상**(점검 보상 등).
create table if not exists user_mail (
  id         bigserial primary key,
  user_id    uuid references auth.users(id) on delete cascade,
  title      text not null,
  body       text not null default '',
  gold int not null default 0,
  jelly int not null default 0,
  chitin int not null default 0,
  mineral int not null default 0,
  sap int not null default 0,
  starts_at  timestamptz,
  ends_at    timestamptz,          -- 만료(수령 기한)
  created_at timestamptz not null default now()
);
create index if not exists user_mail_user_idx on user_mail (user_id);

-- 수령 이력: **기본키가 중복 지급을 막는다**(앱 연타·재시도 안전).
create table if not exists mail_claims (
  mail_id    bigint not null references user_mail(id) on delete cascade,
  user_id    uuid   not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (mail_id, user_id)
);

-- 선물코드: 코드는 대문자로 저장한다(앱이 대문자로 조회).
create table if not exists gift_codes (
  code       text primary key,
  gold int not null default 0,
  jelly int not null default 0,
  chitin int not null default 0,
  mineral int not null default 0,
  sap int not null default 0,
  max_uses   int,                  -- null = 무제한
  used_count int not null default 0,
  ends_at    timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists code_redemptions (
  code        text not null references gift_codes(code) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  primary key (code, user_id)
);

-- RLS: 클라이언트 직접 접근 전면 차단. 접근은 서버(service_role)뿐이다.
-- 정책을 하나도 만들지 않으면 anon/authenticated 는 아무 것도 못 읽는다.
alter table notices          enable row level security;
alter table user_mail        enable row level security;
alter table mail_claims      enable row level security;
alter table gift_codes       enable row level security;
alter table code_redemptions enable row level security;

-- 코드 사용 횟수 +1 (동시 사용 경합에서도 정확하게).
create or replace function bump_gift_code(c text)
returns void language sql security definer set search_path = public as $$
  update gift_codes set used_count = used_count + 1 where code = upper(c);
$$;
```

### 운영 사용법 (SQL Editor 에서 한 줄)

```sql
-- 점검 보상: 전체 유저에게 젤리 100 (7일 안에 받기)
insert into user_mail (user_id, title, body, jelly, ends_at)
values (null, '점검 보상', '점검으로 불편을 드려 죄송합니다.', 100, now() + interval '7 days');

-- 공지 띄우기
insert into notices (title, body, pinned)
values ('v1.0.4 업데이트', '결투 티켓이 생겼어요. 하루 판수가 제한됩니다.', true);

-- 선물코드 만들기 (선착순 1000명, 계정당 1회)
insert into gift_codes (code, jelly, gold, max_uses, ends_at)
values ('BUGCHAMP100', 100, 50000, 1000, now() + interval '30 days');
```

### 엔드포인트

| 엔드포인트 | 설명 |
|---|---|
| `GET /notices` | 진행 중인 공지(고정 먼저, 최신순) |
| `GET /mail` | 내가 **아직 안 받은** 우편(개인 + 전체 발송) |
| `POST /mail/claim {id}` | 우편 수령 → 지급된 세이브 반환 |
| `POST /code/redeem {code}` | 코드 사용 → 지급된 세이브 반환 |

거절 사유: `mail_not_found`(남의 것/기간 지남/이미 받음) · `already_claimed` ·
`bad_code` · `code_expired` · `code_exhausted` · `code_already_used`.

---

## 13. 운영 관리 패널 `/admin` (2026-08-07)

공지·전체발송 우편·선물코드를 **웹에서** 관리한다. SQL 을 직접 칠 필요가 없다.

주소: `https://bugchamp-server-867649520275.asia-northeast3.run.app/admin`

### 왜 서버가 직접 서빙하나 (Vercel·GitHub Pages 가 아니라)

이 테이블들은 RLS 로 클라이언트 직접 접근이 막혀 있고, 쓰려면 `service_role`
키가 필요하다. 그 키는 **DB 전체 권한**이라 정적 호스팅(브라우저)에 두면
모든 유저의 세이브가 노출된다. 서버는 이미 그 키를 Secret Manager 로 안전하게
쥐고 있으므로, 여기서 서빙하면 **키가 브라우저로 나갈 일이 없다.**
별도 호스팅·CORS 설정도 필요 없다.

### 설정 (1회) — 사장님 작업

```powershell
# 40자 랜덤 키 생성 → Secret Manager 에 저장
$key = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 40 | % {[char]$_})
$key | gcloud secrets create bugchamp-admin-key --data-file=-

# 서버에 주입
gcloud run services update bugchamp-server --region asia-northeast3 `
  --update-secrets ADMIN_KEY=bugchamp-admin-key:latest

$key   # ← 이 값을 패널 로그인에 입력(비밀번호 관리자에 보관)
```

키를 잊었으면: `gcloud secrets versions access latest --secret=bugchamp-admin-key`
키를 바꾸려면 새 버전을 추가하고 서비스를 다시 update 한다.

⚠️ **`ADMIN_KEY` 가 없으면 `/admin/*` 은 전부 401 이다.** 기본값을 두지 않았다 —
환경변수를 깜빡한 배포가 재화를 뿌릴 수 있는 문을 연 채로 뜨는 것을 막는다.

### 사고 방지 장치 (UI 가 아니라 **서버**가 강제)

| 장치 | 값 |
|---|---|
| 1건당 골드 상한 | 10,000,000 |
| 1건당 젤리 상한 | 10,000 |
| 1건당 재료 상한 | 100,000 |
| 음수 지급 | 0 으로 처리(운영 실수로 재화를 뺏지 않는다) |
| 코드 형식 | 영문 대문자·숫자 4~32자만 |
| 상한 초과 | **잘라서 보내지 않고 거절** — 조용히 자르면 100만 보낸 줄 알고 1만이 나간다 |

전체 발송은 되돌릴 수 없다(이미 받은 유저의 재화는 회수되지 않는다). 패널이
한 번 더 확인을 묻는다.

### 엔드포인트

| 엔드포인트 | 인증 | 설명 |
|---|---|---|
| `GET /admin` | 불필요 | 패널 HTML(로그인 폼) |
| `GET /admin/data` | `x-admin-key` | 공지·우편·코드 전체 목록(만료분 포함) |
| `POST /admin/notice` | 〃 | 공지 등록 |
| `POST /admin/mail` | 〃 | 우편 발송(`userId` 없으면 전체) |
| `POST /admin/code` | 〃 | 선물코드 생성 |
| `POST /admin/delete` | 〃 | `{kind: notice\|mail\|code, id}` 삭제 |

---

## 14. 운영자 채팅 · 채팅 모더레이션 (2026-08-08)

`/admin` 패널의 **채팅 탭**에서 운영자 이름으로 전체 채팅에 글을 쓰고,
부적절한 메시지를 지운다.

### 왜 DB 표시가 필요한가

닉네임은 유저가 자유롭게 바꾼다 → 누구나 "운영자"로 사칭할 수 있다.
그래서 `is_admin` 컬럼을 두고, **클라이언트는 이 값을 true 로 넣지 못하게** RLS 로
막는다(서버의 service_role 만 가능).

### SQL (1회 실행 — 재실행 안전)

```sql
alter table chat_messages
  add column if not exists is_admin boolean not null default false;

-- 클라이언트 삽입은 본인 명의 + is_admin=false 만 허용.
-- 기존 앱은 is_admin 을 보내지 않으므로 기본값 false 로 통과한다(호환).
drop policy if exists chat_insert on chat_messages;
create policy chat_insert on chat_messages
  for insert to authenticated
  with check (auth.uid() = user_id and is_admin = false);
```

### 운영자 계정 (필수)

`chat_messages.user_id` 는 NOT NULL + `auth.users` 참조다. 그리고 무엇보다
**앱의 `recent()` 는 한 줄만 파싱에 실패해도 목록 전체를 빈 배열로 돌려준다**
— 잘못된 값 하나가 모든 유저의 채팅창을 비운다. 그래서 실재하는 uuid 가 필요하다.

1. Supabase → Authentication → Users → **Add user** (이메일·비밀번호 아무거나)
2. 생성된 **uuid** 복사
3. Cloud Run 에 주입

```powershell
gcloud run services update bugchamp-server --region asia-northeast3 `
  --update-env-vars ADMIN_CHAT_USER_ID=<복사한-uuid>
```

설정하지 않으면 `/admin/chat` 이 503 `admin_chat_user_id_missing` 을 돌려주고,
패널이 "ADMIN_CHAT_USER_ID 가 설정되지 않았습니다" 라고 알린다.

### 엔드포인트

| 엔드포인트 | 설명 |
|---|---|
| `POST /admin/chat` | `{nickname?, body}` — 운영자 이름으로 전체 채팅 전송(기본 "운영자") |
| `POST /admin/delete` | `{kind:"chat", id}` — 메시지 삭제(유저는 RLS 로 본인 것만 지운다) |
| `GET /admin/data` | 응답의 `chat` 에 최근 40건 |

### 앱 쪽 (1.0.5 예정)

지금은 운영자 메시지가 **일반 메시지처럼** 보인다(닉네임만 "운영자").
1.0.5 에서 `ChatMessage.isAdmin` 을 읽어 배지·색을 주고, 차단·신고 대상에서
제외하고, "운영자" 계열 닉네임을 예약어로 막는다.
